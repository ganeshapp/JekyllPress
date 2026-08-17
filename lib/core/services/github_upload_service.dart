import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/app_config.dart';
import 'dio_client.dart';

/// Classifies a publish/upload failure so the UI can offer targeted
/// recovery (conflict dialog, offline queue) without string matching.
/// Threaded verbatim through UploadFailure -> PublishFailure ->
/// PublishFailed.
enum PublishErrorKind {
  /// Anything without a dedicated recovery flow
  generic,

  /// The file changed on GitHub since it was loaded (stale sha that the
  /// automatic refetch-retry could not resolve)
  conflict,

  /// Connectivity-class failure (no connection / timeout) - the
  /// operation can be queued and retried when back online
  offline,
}

/// Kind classification for a raw error thrown outside the upload
/// helpers (e.g. postExists rethrows DioExceptions)
PublishErrorKind publishErrorKindOf(Object error) {
  if (error is DioException && !ApiClient.isRateLimit(error)) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return PublishErrorKind.offline;
      default:
        return PublishErrorKind.generic;
    }
  }
  return PublishErrorKind.generic;
}

/// Result of an upload operation
sealed class UploadResult {
  const UploadResult();
}

class UploadSuccess extends UploadResult {
  final String sha;
  final String htmlUrl;
  const UploadSuccess({required this.sha, required this.htmlUrl});
}

class UploadFailure extends UploadResult {
  final String message;
  final PublishErrorKind kind;
  const UploadFailure(this.message, {this.kind = PublishErrorKind.generic});
}

/// Result of a delete operation
sealed class DeleteResult {
  const DeleteResult();
}

class DeleteSuccess extends DeleteResult {
  const DeleteSuccess();
}

class DeleteFailure extends DeleteResult {
  final String message;
  const DeleteFailure(this.message);
}

/// Service for uploading files to GitHub repository.
/// Auth is handled by the shared [ApiClient] Dio.
class GitHubUploadService {
  final Dio _dio;

  GitHubUploadService({required Dio dio}) : _dio = dio;

  /// Upload an image file to the repository's assets folder
  Future<UploadResult> uploadImage({
    required AppConfig config,
    required File file,
    required String filename,
    String? commitMessage,
  }) async {
    try {
      // Read file and encode as base64
      final bytes = await file.readAsBytes();
      final base64Content = base64Encode(bytes);

      // Clean assets path (remove leading/trailing slashes)
      final assetsPath = config.assetsPath
          .replaceAll(RegExp(r'^/+'), '')
          .replaceAll(RegExp(r'/+$'), '');

      final filePath = '$assetsPath/$filename';

      // Check if file already exists (to get SHA for update)
      String? existingSha;
      try {
        final checkResponse = await _dio.get(
          '/repos/${config.repoOwner}/${config.repoName}/contents/$filePath',
          queryParameters: {'ref': config.branch},
        );
        if (checkResponse.statusCode == 200) {
          existingSha = checkResponse.data['sha'] as String?;
        }
      } on DioException catch (e) {
        // 404 is expected for new files
        if (e.response?.statusCode != 404) {
          rethrow;
        }
      }

      // Prepare request body
      final body = <String, dynamic>{
        'message': commitMessage ?? 'Add image: $filename',
        'content': base64Content,
        'branch': config.branch,
      };

      // Include SHA if updating existing file
      if (existingSha != null) {
        body['sha'] = existingSha;
      }

      // Upload file
      final response = await _dio.put(
        '/repos/${config.repoOwner}/${config.repoName}/contents/$filePath',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final content = response.data['content'];
        return UploadSuccess(
          sha: content['sha'] as String,
          htmlUrl: content['html_url'] as String,
        );
      }

      return const UploadFailure('Unexpected response from GitHub');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return UploadFailure('Upload failed: $e');
    }
  }

  /// Check whether a post file already exists at [path] (full
  /// repo-relative path) on the configured branch. Returns true when
  /// taken, false when free (404). Throws on auth/network errors.
  Future<bool> postExists({
    required AppConfig config,
    required String path,
  }) async {
    try {
      final response = await _dio.get(
        '/repos/${config.repoOwner}/${config.repoName}/contents/$path',
        queryParameters: {'ref': config.branch},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }

  /// Upload a markdown post file to [path] (full repo-relative path,
  /// e.g. _posts/2024-01-01-foo.md or _wiki/foo.md).
  /// On a stale-sha conflict for an update (409, or 422 sha mismatch),
  /// re-fetches the file's current sha once and retries the PUT once.
  /// The residual conflict failure carries [PublishErrorKind.conflict].
  ///
  /// [force] deliberately overwrites the remote version: the file's
  /// CURRENT sha is fetched up front and used for the PUT, so the write
  /// wins regardless of edits made on GitHub since [existingSha].
  Future<UploadResult> uploadPost({
    required AppConfig config,
    required String path,
    required String content,
    String? existingSha,
    String? commitMessage,
    bool force = false,
  }) async {
    final base64Content = base64Encode(utf8.encode(content));
    final filename = path.split('/').last;

    Map<String, dynamic> buildBody(String? sha) {
      final body = <String, dynamic>{
        'message': commitMessage ?? (existingSha != null ? 'Update: $filename' : 'Create: $filename'),
        'content': base64Content,
        'branch': config.branch,
      };
      if (sha != null) {
        body['sha'] = sha;
      }
      return body;
    }

    var sha = existingSha;
    if (force) {
      // Overwrite-with-my-version: swap in the current sha (kept stale
      // when it cannot be read - the PUT then surfaces the real error)
      sha = await _fetchCurrentSha(config: config, filePath: path) ??
          existingSha;
    }

    try {
      return await _putFile(
        config: config,
        filePath: path,
        body: buildBody(sha),
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final ghMessage = _extractGitHubMessage(e);
      final isShaConflict = sha != null &&
          (statusCode == 409 ||
              (statusCode == 422 && ghMessage.toLowerCase().contains('sha')));

      if (!isShaConflict) {
        return _handleDioError(e);
      }

      // Stale sha: re-fetch the current sha once and retry the PUT once
      const staleFailure = UploadFailure(
        'This post changed on GitHub since it was loaded. Pull to refresh and retry.',
        kind: PublishErrorKind.conflict,
      );
      final freshSha = await _fetchCurrentSha(
        config: config,
        filePath: path,
      );
      if (freshSha == null) {
        return staleFailure;
      }
      try {
        return await _putFile(
          config: config,
          filePath: path,
          body: buildBody(freshSha),
        );
      } on DioException catch (retryError) {
        // Went offline mid-retry reads as offline, not conflict
        final retried = _handleDioError(retryError);
        return retried.kind == PublishErrorKind.offline
            ? retried
            : staleFailure;
      }
    } catch (e) {
      return UploadFailure('Upload failed: $e');
    }
  }

  /// Delete the file at [path] (full repo-relative path) on the
  /// configured branch. Mirrors [uploadPost]'s conflict handling: on a
  /// stale-sha conflict (409, or 422 sha mismatch) the current sha is
  /// re-fetched once and the DELETE retried once. A 404 means the file
  /// is already gone and counts as success.
  Future<DeleteResult> deleteFile({
    required AppConfig config,
    required String path,
    required String sha,
    String? commitMessage,
  }) async {
    Future<DeleteResult> doDelete(String currentSha) async {
      final response = await _dio.delete(
        '/repos/${config.repoOwner}/${config.repoName}/contents/$path',
        data: {
          'message': commitMessage ?? 'Delete: ${path.split('/').last}',
          'sha': currentSha,
          'branch': config.branch,
        },
      );
      if (response.statusCode == 200) {
        return const DeleteSuccess();
      }
      return const DeleteFailure('Unexpected response from GitHub');
    }

    try {
      return await doDelete(sha);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        // Already deleted on GitHub - the desired end state
        return const DeleteSuccess();
      }
      final ghMessage = _extractGitHubMessage(e);
      final isShaConflict = statusCode == 409 ||
          (statusCode == 422 && ghMessage.toLowerCase().contains('sha'));
      if (!isShaConflict) {
        return DeleteFailure(_handleDioError(e).message);
      }

      // Stale sha: re-fetch the current sha once and retry the DELETE once
      const staleMessage =
          'This post changed on GitHub since it was loaded. Pull to refresh and retry.';
      final freshSha = await _fetchCurrentSha(config: config, filePath: path);
      if (freshSha == null) {
        return const DeleteFailure(staleMessage);
      }
      try {
        return await doDelete(freshSha);
      } on DioException {
        return const DeleteFailure(staleMessage);
      }
    } catch (e) {
      return DeleteFailure('Delete failed: $e');
    }
  }

  /// Current sha of [path] on the configured branch, or null when it
  /// cannot be read (deleted, offline). Used by the conflict-resolution
  /// 'Keep both' flow to reload the remote version.
  Future<String?> fetchCurrentSha({
    required AppConfig config,
    required String path,
  }) {
    return _fetchCurrentSha(config: config, filePath: path);
  }

  /// PUT a file to the contents API. Throws DioException on HTTP errors.
  Future<UploadResult> _putFile({
    required AppConfig config,
    required String filePath,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.put(
      '/repos/${config.repoOwner}/${config.repoName}/contents/$filePath',
      data: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseContent = response.data['content'];
      return UploadSuccess(
        sha: responseContent['sha'] as String,
        htmlUrl: responseContent['html_url'] as String,
      );
    }

    return const UploadFailure('Unexpected response from GitHub');
  }

  /// Fetch the current sha of a file, or null if it cannot be read
  Future<String?> _fetchCurrentSha({
    required AppConfig config,
    required String filePath,
  }) async {
    try {
      final response = await _dio.get(
        '/repos/${config.repoOwner}/${config.repoName}/contents/$filePath',
        queryParameters: {'ref': config.branch},
      );
      if (response.statusCode == 200) {
        return response.data['sha'] as String?;
      }
    } on DioException {
      return null;
    }
    return null;
  }

  /// Safely extract GitHub's error message from a Dio error response
  String _extractGitHubMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return '';
  }

  UploadFailure _handleDioError(DioException e) {
    // Rate limiting must never read as "permission denied"
    if (ApiClient.isRateLimit(e)) {
      return UploadFailure(ApiClient.friendlyError(e));
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const UploadFailure('Upload timed out. Please try again.',
            kind: PublishErrorKind.offline);
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final ghMessage = _extractGitHubMessage(e);
        final message = ghMessage.isNotEmpty ? ghMessage : 'Unknown error';
        if (statusCode == 401) {
          return const UploadFailure('Authentication failed');
        } else if (statusCode == 403) {
          // Include GitHub's message so permission errors are actionable
          return UploadFailure('Permission denied: $message');
        } else if (statusCode == 409) {
          return UploadFailure(
              'Conflict: $message. Pull to refresh and retry.');
        } else if (statusCode == 422) {
          return UploadFailure('Invalid request: $message');
        }
        return UploadFailure('GitHub error ($statusCode): $message');
      case DioExceptionType.connectionError:
        return const UploadFailure('No internet connection',
            kind: PublishErrorKind.offline);
      default:
        return UploadFailure('Network error: ${e.message}');
    }
  }
}

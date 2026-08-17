import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/app_config.dart';
import 'secure_storage_service.dart';

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
  const UploadFailure(this.message);
}

/// Service for uploading files to GitHub repository
class GitHubUploadService {
  final SecureStorageService _secureStorage;
  final Dio _dio;

  GitHubUploadService({
    required SecureStorageService secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.github.com',
              connectTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            ));

  /// Upload an image file to the repository's assets folder
  Future<UploadResult> uploadImage({
    required AppConfig config,
    required File file,
    required String filename,
    String? commitMessage,
  }) async {
    final token = await _secureStorage.getToken();
    if (token == null) {
      return const UploadFailure('Not authenticated');
    }

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
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
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
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
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

  /// Check whether a post file already exists in _posts on the configured
  /// branch. Returns true when taken, false when free (404).
  /// Throws on auth/network errors.
  Future<bool> postExists({
    required AppConfig config,
    required String filename,
  }) async {
    final token = await _secureStorage.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await _dio.get(
        '/repos/${config.repoOwner}/${config.repoName}/contents/_posts/$filename',
        queryParameters: {'ref': config.branch},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }

  /// Upload a markdown post file.
  /// On a stale-sha conflict for an update (409, or 422 sha mismatch),
  /// re-fetches the file's current sha once and retries the PUT once.
  Future<UploadResult> uploadPost({
    required AppConfig config,
    required String filename,
    required String content,
    String? existingSha,
    String? commitMessage,
  }) async {
    final token = await _secureStorage.getToken();
    if (token == null) {
      return const UploadFailure('Not authenticated');
    }

    final base64Content = base64Encode(utf8.encode(content));
    final filePath = '_posts/$filename';

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

    try {
      return await _putFile(
        token: token,
        config: config,
        filePath: filePath,
        body: buildBody(existingSha),
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final ghMessage = _extractGitHubMessage(e);
      final isShaConflict = existingSha != null &&
          (statusCode == 409 ||
              (statusCode == 422 && ghMessage.toLowerCase().contains('sha')));

      if (!isShaConflict) {
        return _handleDioError(e);
      }

      // Stale sha: re-fetch the current sha once and retry the PUT once
      const staleMessage =
          'This post changed on GitHub since it was loaded. Pull to refresh and retry.';
      final freshSha = await _fetchCurrentSha(
        token: token,
        config: config,
        filePath: filePath,
      );
      if (freshSha == null) {
        return const UploadFailure(staleMessage);
      }
      try {
        return await _putFile(
          token: token,
          config: config,
          filePath: filePath,
          body: buildBody(freshSha),
        );
      } on DioException {
        return const UploadFailure(staleMessage);
      }
    } catch (e) {
      return UploadFailure('Upload failed: $e');
    }
  }

  /// PUT a file to the contents API. Throws DioException on HTTP errors.
  Future<UploadResult> _putFile({
    required String token,
    required AppConfig config,
    required String filePath,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.put(
      '/repos/${config.repoOwner}/${config.repoName}/contents/$filePath',
      data: body,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
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
    required String token,
    required AppConfig config,
    required String filePath,
  }) async {
    try {
      final response = await _dio.get(
        '/repos/${config.repoOwner}/${config.repoName}/contents/$filePath',
        queryParameters: {'ref': config.branch},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
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
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const UploadFailure('Upload timed out. Please try again.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final ghMessage = _extractGitHubMessage(e);
        final message = ghMessage.isNotEmpty ? ghMessage : 'Unknown error';
        if (statusCode == 401) {
          return const UploadFailure('Authentication failed');
        } else if (statusCode == 403) {
          // Include GitHub's message so rate-limit errors are distinguishable
          return UploadFailure('Permission denied: $message');
        } else if (statusCode == 409) {
          return UploadFailure(
              'Conflict: $message. Pull to refresh and retry.');
        } else if (statusCode == 422) {
          return UploadFailure('Invalid request: $message');
        }
        return UploadFailure('GitHub error ($statusCode): $message');
      case DioExceptionType.connectionError:
        return const UploadFailure('No internet connection');
      default:
        return UploadFailure('Network error: ${e.message}');
    }
  }
}

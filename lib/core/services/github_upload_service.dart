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

  /// Upload a markdown post file
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

    try {
      final base64Content = base64Encode(utf8.encode(content));
      final filePath = '_posts/$filename';

      final body = <String, dynamic>{
        'message': commitMessage ?? (existingSha != null ? 'Update: $filename' : 'Create: $filename'),
        'content': base64Content,
        'branch': config.branch,
      };

      if (existingSha != null) {
        body['sha'] = existingSha;
      }

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
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return UploadFailure('Upload failed: $e');
    }
  }

  UploadFailure _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const UploadFailure('Upload timed out. Please try again.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] ?? 'Unknown error';
        if (statusCode == 401) {
          return const UploadFailure('Authentication failed');
        } else if (statusCode == 403) {
          return const UploadFailure('Permission denied');
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

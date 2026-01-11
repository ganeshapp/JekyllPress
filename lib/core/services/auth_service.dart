import 'package:dio/dio.dart';
import '../models/github_user.dart';
import 'secure_storage_service.dart';

/// Result of a token validation attempt
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  final GitHubUser user;
  const AuthSuccess(this.user);
}

class AuthFailure extends AuthResult {
  final String message;
  const AuthFailure(this.message);
}

/// Service for handling GitHub authentication
class AuthService {
  final SecureStorageService _secureStorage;
  final Dio _dio;

  AuthService({
    required SecureStorageService secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _dio = dio ?? Dio(BaseOptions(
          baseUrl: 'https://api.github.com',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ));

  /// Validate a GitHub Personal Access Token
  /// Returns AuthSuccess with user info if valid, AuthFailure otherwise
  Future<AuthResult> validateToken(String token) async {
    if (token.trim().isEmpty) {
      return const AuthFailure('Token cannot be empty');
    }

    try {
      final response = await _dio.get(
        '/user',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${token.trim()}',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final user = GitHubUser.fromJson(response.data);
        // Save token on successful validation
        await _secureStorage.saveToken(token.trim());
        return AuthSuccess(user);
      } else {
        return const AuthFailure('Invalid response from GitHub');
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return AuthFailure('Unexpected error: ${e.toString()}');
    }
  }

  /// Check if user is already authenticated
  Future<AuthResult> checkExistingAuth() async {
    final token = await _secureStorage.getToken();
    if (token == null || token.isEmpty) {
      return const AuthFailure('No token stored');
    }
    return validateToken(token);
  }

  /// Logout - clear stored token
  Future<void> logout() async {
    await _secureStorage.deleteToken();
  }

  AuthFailure _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AuthFailure('Connection timed out. Please check your internet.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return const AuthFailure('Invalid or expired token');
        } else if (statusCode == 403) {
          return const AuthFailure('Token lacks required permissions');
        } else if (statusCode == 404) {
          return const AuthFailure('GitHub API not reachable');
        }
        return AuthFailure('GitHub error: $statusCode');
      case DioExceptionType.connectionError:
        return const AuthFailure('No internet connection');
      case DioExceptionType.cancel:
        return const AuthFailure('Request cancelled');
      default:
        return AuthFailure('Network error: ${e.message}');
    }
  }
}

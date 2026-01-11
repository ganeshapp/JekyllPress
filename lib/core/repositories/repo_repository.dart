import 'package:dio/dio.dart';
import '../models/github_repo.dart';
import '../services/secure_storage_service.dart';

/// Repository for fetching GitHub repositories
class RepoRepository {
  final SecureStorageService _secureStorage;
  final Dio _dio;

  RepoRepository({
    required SecureStorageService secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.github.com',
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            ));

  /// Fetch all repositories for the authenticated user
  /// Returns repositories sorted by most recently pushed
  Future<List<GitHubRepo>> getUserRepos() async {
    final token = await _secureStorage.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final List<GitHubRepo> allRepos = [];
    int page = 1;
    const perPage = 100;

    while (true) {
      final response = await _dio.get(
        '/user/repos',
        queryParameters: {
          'sort': 'pushed',
          'direction': 'desc',
          'per_page': perPage,
          'page': page,
          'type': 'owner', // Only repos owned by user
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> reposJson = response.data;
        if (reposJson.isEmpty) break;

        allRepos.addAll(
          reposJson.map((json) => GitHubRepo.fromJson(json)).toList(),
        );

        if (reposJson.length < perPage) break;
        page++;
      } else {
        throw Exception('Failed to fetch repositories');
      }
    }

    return allRepos;
  }

  /// Check if a repository likely contains a Jekyll site
  /// by looking for _posts or _config.yml
  Future<bool> isJekyllRepo(GitHubRepo repo) async {
    final token = await _secureStorage.getToken();
    if (token == null) return false;

    try {
      // Try to get the _posts directory
      await _dio.get(
        '/repos/${repo.ownerLogin}/${repo.name}/contents/_posts',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // No _posts folder, try _config.yml
        try {
          await _dio.get(
            '/repos/${repo.ownerLogin}/${repo.name}/contents/_config.yml',
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
              },
            ),
          );
          return true;
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }
}

import 'package:dio/dio.dart';
import '../models/github_repo.dart';
import '../services/dio_client.dart';

/// Repository for fetching GitHub repositories.
/// Auth is handled by the shared [ApiClient] Dio.
class RepoRepository {
  final Dio _dio;

  RepoRepository({required Dio dio}) : _dio = dio;

  /// Fetch all repositories for the authenticated user
  /// Returns repositories sorted by most recently pushed
  Future<List<GitHubRepo>> getUserRepos() async {
    final List<GitHubRepo> allRepos = [];
    int page = 1;
    const perPage = 100;

    try {
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
    } on DioException catch (e) {
      // Callers show e.toString() to the user - make it a clean message
      // (rate-limit messages from ApiClient pass through verbatim)
      throw ApiException(ApiClient.friendlyError(e));
    }

    return allRepos;
  }

  /// Check if a repository likely contains a Jekyll site
  /// by looking for _posts or _config.yml
  Future<bool> isJekyllRepo(GitHubRepo repo) async {
    try {
      // Try to get the _posts directory
      await _dio.get(
        '/repos/${repo.ownerLogin}/${repo.name}/contents/_posts',
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // No _posts folder, try _config.yml
        try {
          await _dio.get(
            '/repos/${repo.ownerLogin}/${repo.name}/contents/_config.yml',
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

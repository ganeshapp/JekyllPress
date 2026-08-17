import 'package:dio/dio.dart';
import '../models/github_repo.dart';
import '../services/dio_client.dart';

/// Outcome of checking whether a repository looks like a Jekyll site.
/// A clean pair of 404s is [notJekyll]; anything that prevented the
/// check (network, 403/rate limit, ...) is [couldNotVerify] - never
/// silently reported as "not Jekyll".
enum JekyllRepoCheck {
  /// _config.yml or the posts dir exists on the selected branch
  jekyll,

  /// Both probes returned clean 404s - definitely not a Jekyll site
  notJekyll,

  /// A probe failed for a non-404 reason (offline, 403, rate limit, ...)
  couldNotVerify,
}

/// Extract the top-level 'permalink:' value from raw _config.yml text.
/// Returns '' when absent. Quotes are stripped; unquoted values lose a
/// trailing '# comment'.
String parsePermalinkSetting(String configYaml) {
  final entryRegex = RegExp(r'^permalink[^\S\n]*:(.*)$');
  for (final line in configYaml.replaceAll('\r\n', '\n').split('\n')) {
    final match = entryRegex.firstMatch(line);
    if (match == null) continue;
    var value = match.group(1)!.trim();
    if (value.startsWith('"') || value.startsWith("'")) {
      final quote = value[0];
      final end = value.indexOf(quote, 1);
      return end > 0 ? value.substring(1, end) : '';
    }
    final hash = value.indexOf('#');
    if (hash != -1) {
      value = value.substring(0, hash).trim();
    }
    return value;
  }
  return '';
}

/// Repository for fetching GitHub repositories.
/// Auth is handled by the shared [ApiClient] Dio.
class RepoRepository {
  /// Repos fetched per page / max pages (90 most recently pushed total)
  static const reposPerPage = 30;
  static const maxRepoPages = 3;

  /// Branches fetched per request (single page)
  static const branchesPerPage = 100;

  final Dio _dio;

  RepoRepository({required Dio dio}) : _dio = dio;

  /// Fetch repositories the authenticated user can push a blog to:
  /// owned, collaborator, and organization repos, sorted by most
  /// recently pushed. Fetches up to [maxRepoPages] pages of
  /// [reposPerPage].
  Future<List<GitHubRepo>> getUserRepos() async {
    final List<GitHubRepo> allRepos = [];

    try {
      for (int page = 1; page <= maxRepoPages; page++) {
        final response = await _dio.get(
          '/user/repos',
          queryParameters: {
            'sort': 'pushed',
            'direction': 'desc',
            'per_page': reposPerPage,
            'page': page,
            'affiliation': 'owner,collaborator,organization_member',
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final List<dynamic> reposJson = response.data;
          if (reposJson.isEmpty) break;

          allRepos.addAll(
            reposJson.map((json) => GitHubRepo.fromJson(json)).toList(),
          );

          if (reposJson.length < reposPerPage) break;
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

  /// Fetch a single repository by owner/name (manual repo entry for
  /// repos the paginated listing misses)
  Future<GitHubRepo> getRepo({
    required String repoOwner,
    required String repoName,
  }) async {
    try {
      final response = await _dio.get('/repos/$repoOwner/$repoName');
      if (response.statusCode == 200 && response.data != null) {
        return GitHubRepo.fromJson(response.data);
      }
      throw Exception('Failed to fetch repository');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw ApiException(
            'Repository $repoOwner/$repoName was not found - check the '
            'name, and that the app has access to it');
      }
      throw ApiException(ApiClient.friendlyError(e));
    }
  }

  /// Fetch branch names for a repository (first [branchesPerPage],
  /// which covers any realistic blog repo)
  Future<List<String>> getBranches({
    required String repoOwner,
    required String repoName,
  }) async {
    try {
      final response = await _dio.get(
        '/repos/$repoOwner/$repoName/branches',
        queryParameters: {'per_page': branchesPerPage},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> branchesJson = response.data;
        return branchesJson
            .map((json) => json['name'] as String)
            .toList();
      }
      throw Exception('Failed to fetch branches');
    } on DioException catch (e) {
      throw ApiException(ApiClient.friendlyError(e));
    }
  }

  /// Best-effort read of the site's top-level 'permalink:' setting from
  /// _config.yml on [branch]. Returns '' when the file or key is absent
  /// (a definitive "no pattern"); throws on network/auth errors so
  /// callers don't clobber a previously discovered pattern.
  Future<String> fetchPermalinkPattern({
    required String repoOwner,
    required String repoName,
    required String branch,
  }) async {
    try {
      final response = await _dio.get(
        '/repos/$repoOwner/$repoName/contents/_config.yml',
        queryParameters: {'ref': branch},
        options: Options(
          headers: {'Accept': 'application/vnd.github.raw+json'},
          responseType: ResponseType.plain,
        ),
      );
      final data = response.data;
      if (response.statusCode == 200 && data is String) {
        return parsePermalinkSetting(data);
      }
      return '';
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return '';
      }
      throw ApiException(ApiClient.friendlyError(e));
    }
  }

  /// Check if a repository likely contains a Jekyll site by looking for
  /// _config.yml OR [postsPath] on [branch] (defaults to the repo's
  /// default branch). Distinguishes 'definitely not' (clean 404s) from
  /// 'could not verify' (network/403/...).
  Future<JekyllRepoCheck> isJekyllRepo(
    GitHubRepo repo, {
    String postsPath = '_posts',
    String? branch,
  }) async {
    final ref = branch ?? repo.defaultBranch;

    final configResult = await _probePath(repo, '_config.yml', ref);
    if (configResult == JekyllRepoCheck.jekyll) return JekyllRepoCheck.jekyll;

    final postsResult = await _probePath(repo, postsPath, ref);
    if (postsResult == JekyllRepoCheck.jekyll) return JekyllRepoCheck.jekyll;

    // Only a pair of clean 404s means "definitely not Jekyll"
    if (configResult == JekyllRepoCheck.notJekyll &&
        postsResult == JekyllRepoCheck.notJekyll) {
      return JekyllRepoCheck.notJekyll;
    }
    return JekyllRepoCheck.couldNotVerify;
  }

  /// Probe a single path on [ref]: jekyll (200), notJekyll (404), or
  /// couldNotVerify (anything else)
  Future<JekyllRepoCheck> _probePath(
    GitHubRepo repo,
    String path,
    String ref,
  ) async {
    try {
      final response = await _dio.get(
        '/repos/${repo.ownerLogin}/${repo.name}/contents/$path',
        queryParameters: {'ref': ref},
      );
      return response.statusCode == 200
          ? JekyllRepoCheck.jekyll
          : JekyllRepoCheck.couldNotVerify;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return JekyllRepoCheck.notJekyll;
      }
      return JekyllRepoCheck.couldNotVerify;
    }
  }
}

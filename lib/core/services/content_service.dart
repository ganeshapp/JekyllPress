import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../utils/frontmatter_parser.dart';
import 'dio_client.dart';

/// Represents a markdown file entry discovered on GitHub
class GitHubFileEntry {
  final String name;
  final String path;
  final String sha;
  final String type;
  final int? size;

  const GitHubFileEntry({
    required this.name,
    required this.path,
    required this.sha,
    required this.type,
    this.size,
  });

  /// From a contents-API item (type: 'file' | 'dir')
  factory GitHubFileEntry.fromJson(Map<String, dynamic> json) {
    return GitHubFileEntry(
      name: json['name'] as String,
      path: json['path'] as String,
      sha: json['sha'] as String,
      type: json['type'] as String,
      size: json['size'] as int?,
    );
  }

  /// From a git-trees-API item (type: 'blob' | 'tree')
  factory GitHubFileEntry.fromTreeJson(Map<String, dynamic> json) {
    final path = json['path'] as String;
    return GitHubFileEntry(
      name: path.split('/').last,
      path: path,
      sha: json['sha'] as String,
      type: json['type'] as String,
      size: json['size'] as int?,
    );
  }

  bool get isMarkdown =>
      name.endsWith('.md') || name.endsWith('.markdown');
}

/// Service for fetching and managing blog content from GitHub.
/// Auth is handled by the shared [ApiClient] Dio.
class ContentService {
  /// How many changed file bodies are fetched concurrently during a sync
  static const syncBatchSize = 6;

  final Dio _dio;

  ContentService({required Dio dio}) : _dio = dio;

  /// Strip leading/trailing slashes from a configured directory
  static String cleanDir(String dir) => dir
      .replaceAll(RegExp(r'^/+'), '')
      .replaceAll(RegExp(r'/+$'), '');

  /// Dirs one sync covers: the active content dir plus the remote Jekyll
  /// drafts dir (so _drafts files ride along in the same git-trees call).
  /// The drafts dir is dropped when it duplicates the active dir.
  static List<String> contentDirsToSync(AppConfig config) {
    final active = cleanDir(config.activeContentDir);
    final drafts = cleanDir(config.draftsPath);
    if (drafts.isEmpty || drafts == active) return [active];
    return [active, drafts];
  }

  /// List markdown files in the ACTIVE content dir AND the remote drafts
  /// dir via the git trees API (recursive), which sees _posts subfolders
  /// (year/category) and is not subject to the contents API's 1000-entry
  /// cap. When GitHub truncates the tree, falls back to a per-directory
  /// contents listing.
  Future<List<GitHubFileEntry>> fetchPostsList(AppConfig config) async {
    final dirs = contentDirsToSync(config);
    try {
      final response = await _dio.get(
        '/repos/${config.repoOwner}/${config.repoName}'
        '/git/trees/${Uri.encodeComponent(config.branch)}',
        queryParameters: {'recursive': '1'},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        if (data['truncated'] == true) {
          // The tree is too large for one response - the flat list may be
          // missing files, so use the (slower) directory walk instead
          debugPrint(
              'ContentService: git tree for ${config.repoOwner}/'
              '${config.repoName}@${config.branch} is truncated - '
              'falling back to per-directory contents listing');
          // Dedupe by path in case the dirs overlap (nested configs)
          final byPath = <String, GitHubFileEntry>{};
          for (final dir in dirs) {
            for (final entry in await _fetchDirRecursive(config, dir)) {
              byPath[entry.path] = entry;
            }
          }
          return byPath.values.toList();
        }
        final tree = (data['tree'] as List?) ?? const [];
        return tree
            .map((t) => GitHubFileEntry.fromTreeJson(t as Map<String, dynamic>))
            .where((f) =>
                f.type == 'blob' &&
                f.isMarkdown &&
                dirs.any((dir) => f.path.startsWith('$dir/')))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      // 404: branch/repo not found; 409: empty repository
      if (statusCode == 404 || statusCode == 409) {
        return [];
      }
      // Callers show e.toString() to the user - make it a clean message
      // (rate-limit messages from ApiClient pass through verbatim)
      throw ApiException(ApiClient.friendlyError(e));
    }
  }

  /// Fallback for truncated trees: walk [dir] (and subdirectories) with
  /// the contents API on the configured branch
  Future<List<GitHubFileEntry>> _fetchDirRecursive(
    AppConfig config,
    String dir,
  ) async {
    final results = <GitHubFileEntry>[];
    try {
      final response = await _dio.get(
        '/repos/${config.repoOwner}/${config.repoName}/contents/$dir',
        queryParameters: {'ref': config.branch},
      );

      if (response.statusCode == 200 && response.data is List) {
        for (final item in response.data as List) {
          final entry = GitHubFileEntry.fromJson(item as Map<String, dynamic>);
          if (entry.type == 'dir') {
            results.addAll(await _fetchDirRecursive(config, entry.path));
          } else if (entry.type == 'file' && entry.isMarkdown) {
            results.add(entry);
          }
        }
      }
      return results;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Directory doesn't exist yet
        return results;
      }
      throw ApiException(ApiClient.friendlyError(e));
    }
  }

  /// Fetch content of a single file on the configured branch
  Future<String> fetchFileContent(AppConfig config, String path) async {
    final url = '/repos/${config.repoOwner}/${config.repoName}/contents/$path';
    final ref = {'ref': config.branch};
    final response = await _dio.get(url, queryParameters: ref);

    if (response.statusCode == 200 && response.data != null) {
      final encoding = response.data['encoding'] as String?;
      if (encoding == 'base64') {
        final content = response.data['content'] as String;
        // GitHub returns base64 encoded content
        final decoded = utf8.decode(base64.decode(content.replaceAll('\n', '')));
        return decoded;
      }

      // For 1-100MB files the contents API returns content: "" with
      // encoding: "none". Re-fetch the raw file content instead of
      // silently returning an empty post (which would enable data loss
      // if the truncated post were published back).
      final rawResponse = await _dio.get(
        url,
        queryParameters: ref,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.raw+json',
          },
          responseType: ResponseType.plain,
        ),
      );
      final rawData = rawResponse.data;
      if (rawResponse.statusCode == 200 &&
          rawData is String &&
          rawData.isNotEmpty) {
        return rawData;
      }
      throw Exception(
          'Failed to fetch "$path": content encoding is "$encoding" (file may be too large for the contents API) and the raw download also failed.');
    }
    throw Exception('Failed to fetch file content');
  }

  /// Sync posts - fetch only changed files. [existingPosts] is keyed by
  /// full repo-relative path. Changed bodies are fetched with bounded
  /// parallelism ([syncBatchSize] at a time); [onProgress] reports
  /// (done, total) over the changed files as each fetch completes.
  Future<List<BlogPost>> syncPosts({
    required AppConfig config,
    required Map<String, BlogPost> existingPosts,
    void Function(int done, int total)? onProgress,
  }) async {
    final remoteFiles = await fetchPostsList(config);
    final updatedPosts = <BlogPost>[];
    final changedFiles = <GitHubFileEntry>[];

    for (final file in remoteFiles) {
      final existing = existingPosts[file.path];

      // Skip if SHA matches (not changed)
      if (existing != null && existing.sha == file.sha) {
        updatedPosts.add(existing);
      } else {
        changedFiles.add(file);
      }
    }

    final total = changedFiles.length;
    var done = 0;
    if (total > 0) {
      onProgress?.call(0, total);
    }

    for (var i = 0; i < changedFiles.length; i += syncBatchSize) {
      final batch = changedFiles.sublist(
        i,
        i + syncBatchSize > changedFiles.length
            ? changedFiles.length
            : i + syncBatchSize,
      );
      await Future.wait(batch.map((file) async {
        try {
          final content = await fetchFileContent(config, file.path);
          final parsed = FrontmatterParser.parse(content);

          updatedPosts.add(BlogPost(
            sha: file.sha,
            fileName: file.name,
            filePath: file.path,
            title: parsed.title,
            date: parsed.date,
            rawFrontmatter: parsed.rawFrontmatter,
            bodyContent: parsed.bodyContent,
            isLocalDraft: false,
            lastSynced: DateTime.now(),
          ));
        } catch (e) {
          // Keep existing if fetch/parse fails
          final existing = existingPosts[file.path];
          if (existing != null) {
            updatedPosts.add(existing);
          }
        } finally {
          done++;
          onProgress?.call(done, total);
        }
      }));
    }

    // Sort by date, newest first
    updatedPosts.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return updatedPosts;
  }
}

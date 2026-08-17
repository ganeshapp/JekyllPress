import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../utils/frontmatter_parser.dart';
import 'dio_client.dart';

/// Represents a file entry from GitHub contents API
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

  factory GitHubFileEntry.fromJson(Map<String, dynamic> json) {
    return GitHubFileEntry(
      name: json['name'] as String,
      path: json['path'] as String,
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
  final Dio _dio;

  ContentService({required Dio dio}) : _dio = dio;

  /// Fetch list of files in _posts directory
  Future<List<GitHubFileEntry>> fetchPostsList(AppConfig config) async {
    try {
      final response = await _dio.get(
        '/repos/${config.repoOwner}/${config.repoName}/contents/_posts',
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> files = response.data;
        return files
            .map((f) => GitHubFileEntry.fromJson(f))
            .where((f) => f.isMarkdown)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // _posts folder doesn't exist yet
        return [];
      }
      // Callers show e.toString() to the user - make it a clean message
      // (rate-limit messages from ApiClient pass through verbatim)
      throw ApiException(ApiClient.friendlyError(e));
    }
  }

  /// Fetch content of a single file
  Future<String> fetchFileContent(AppConfig config, String path) async {
    final url = '/repos/${config.repoOwner}/${config.repoName}/contents/$path';
    final response = await _dio.get(url);

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

  /// Fetch all posts with their content
  Future<List<BlogPost>> fetchAllPosts(AppConfig config) async {
    final files = await fetchPostsList(config);
    final posts = <BlogPost>[];

    for (final file in files) {
      try {
        final content = await fetchFileContent(config, file.path);
        final parsed = FrontmatterParser.parse(content);

        posts.add(BlogPost(
          sha: file.sha,
          fileName: file.name,
          title: parsed.title,
          date: parsed.date,
          rawFrontmatter: parsed.rawFrontmatter,
          bodyContent: parsed.bodyContent,
          isLocalDraft: false,
          lastSynced: DateTime.now(),
        ));
      } catch (e) {
        // Skip files that fail to parse
        continue;
      }
    }

    // Sort by date, newest first
    posts.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return posts;
  }

  /// Fetch only file metadata (for comparing SHAs without downloading content)
  Future<Map<String, String>> fetchPostsShaMap(AppConfig config) async {
    final files = await fetchPostsList(config);
    return {for (var f in files) f.name: f.sha};
  }

  /// Sync posts - fetch only changed files
  Future<List<BlogPost>> syncPosts({
    required AppConfig config,
    required Map<String, BlogPost> existingPosts,
  }) async {
    final remoteFiles = await fetchPostsList(config);
    final updatedPosts = <BlogPost>[];

    for (final file in remoteFiles) {
      final existing = existingPosts[file.name];

      // Skip if SHA matches (not changed)
      if (existing != null && existing.sha == file.sha) {
        updatedPosts.add(existing);
        continue;
      }

      // Fetch updated content
      try {
        final content = await fetchFileContent(config, file.path);
        final parsed = FrontmatterParser.parse(content);

        updatedPosts.add(BlogPost(
          sha: file.sha,
          fileName: file.name,
          title: parsed.title,
          date: parsed.date,
          rawFrontmatter: parsed.rawFrontmatter,
          bodyContent: parsed.bodyContent,
          isLocalDraft: false,
          lastSynced: DateTime.now(),
        ));
      } catch (e) {
        // Keep existing if fetch fails
        if (existing != null) {
          updatedPosts.add(existing);
        }
      }
    }

    // Sort by date, newest first
    updatedPosts.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return updatedPosts;
  }
}

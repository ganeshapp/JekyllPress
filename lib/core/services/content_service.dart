import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../utils/frontmatter_parser.dart';
import 'secure_storage_service.dart';

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

/// Service for fetching and managing blog content from GitHub
class ContentService {
  final SecureStorageService _secureStorage;
  final Dio _dio;

  ContentService({
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

  /// Fetch list of files in _posts directory
  Future<List<GitHubFileEntry>> fetchPostsList(AppConfig config) async {
    final token = await _secureStorage.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await _dio.get(
        '/repos/${config.repoOwner}/${config.repoName}/contents/_posts',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
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
      rethrow;
    }
  }

  /// Fetch content of a single file
  Future<String> fetchFileContent(AppConfig config, String path) async {
    final token = await _secureStorage.getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await _dio.get(
      '/repos/${config.repoOwner}/${config.repoName}/contents/$path',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      final content = response.data['content'] as String;
      // GitHub returns base64 encoded content
      final decoded = utf8.decode(base64.decode(content.replaceAll('\n', '')));
      return decoded;
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

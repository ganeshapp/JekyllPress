import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../utils/frontmatter_parser.dart';
import 'github_upload_service.dart';

/// Result of a publish operation
sealed class PublishResult {
  const PublishResult();
}

class PublishSuccess extends PublishResult {
  final String sha;
  final String filename;
  final String htmlUrl;
  
  const PublishSuccess({
    required this.sha,
    required this.filename,
    required this.htmlUrl,
  });
}

class PublishFailure extends PublishResult {
  final String message;
  const PublishFailure(this.message);
}

/// Service for publishing posts to GitHub
class PublishService {
  final GitHubUploadService _uploadService;

  PublishService({required GitHubUploadService uploadService})
      : _uploadService = uploadService;

  /// Create a new post
  /// Generates filename, frontmatter, and uploads to GitHub
  Future<PublishResult> createPost({
    required AppConfig config,
    required String title,
    required String bodyContent,
  }) async {
    if (title.trim().isEmpty) {
      return const PublishFailure('Title cannot be empty');
    }

    // Generate date
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Generate filename: YYYY-MM-DD-kebab-case-title.md
    final kebabTitle = _toKebabCase(title);
    final filename = '$dateStr-$kebabTitle.md';

    // Generate frontmatter
    final frontmatter = FrontmatterParser.generateFrontmatter(
      title: title,
      date: dateStr,
      layout: 'single',
      categories: const ['blog'],
    );

    // Combine frontmatter and body
    final fullContent = FrontmatterParser.combineContent(frontmatter, bodyContent);

    // Upload to GitHub
    final result = await _uploadService.uploadPost(
      config: config,
      filename: filename,
      content: fullContent,
      existingSha: null, // New post
      commitMessage: 'Create post: $title',
    );

    return switch (result) {
      UploadSuccess(sha: final sha, htmlUrl: final url) => PublishSuccess(
          sha: sha,
          filename: filename,
          htmlUrl: url,
        ),
      UploadFailure(message: final msg) => PublishFailure(msg),
    };
  }

  /// Update an existing post
  /// Uses original filename and frontmatter, updates body only
  Future<PublishResult> updatePost({
    required AppConfig config,
    required BlogPost originalPost,
    required String newBodyContent,
  }) async {
    if (originalPost.fileName == null) {
      return const PublishFailure('Cannot update post without filename');
    }

    if (originalPost.sha == null) {
      return const PublishFailure('Cannot update post without SHA');
    }

    // Reconstruct frontmatter - preserve original
    String frontmatter;
    if (originalPost.rawFrontmatter != null && originalPost.rawFrontmatter!.isNotEmpty) {
      // Use original frontmatter wrapped in delimiters
      frontmatter = '---\n${originalPost.rawFrontmatter}\n---';
    } else {
      // Generate frontmatter from post data
      frontmatter = FrontmatterParser.generateFrontmatter(
        title: originalPost.title,
        date: originalPost.date,
        layout: 'single',
        categories: const ['blog'],
      );
    }

    // Combine frontmatter and new body
    final fullContent = FrontmatterParser.combineContent(frontmatter, newBodyContent);

    // Upload to GitHub with SHA for update
    final result = await _uploadService.uploadPost(
      config: config,
      filename: originalPost.fileName!,
      content: fullContent,
      existingSha: originalPost.sha,
      commitMessage: 'Update post: ${originalPost.title}',
    );

    return switch (result) {
      UploadSuccess(sha: final sha, htmlUrl: final url) => PublishSuccess(
          sha: sha,
          filename: originalPost.fileName!,
          htmlUrl: url,
        ),
      UploadFailure(message: final msg) => PublishFailure(msg),
    };
  }

  /// Convert title to kebab-case for filename
  String _toKebabCase(String title) {
    return title
        .toLowerCase()
        .trim()
        // Replace special chars with spaces
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        // Replace multiple spaces/hyphens with single hyphen
        .replaceAll(RegExp(r'[\s_]+'), '-')
        // Remove leading/trailing hyphens
        .replaceAll(RegExp(r'^-+|-+$'), '')
        // Limit length
        .substring(0, title.length > 50 ? 50 : title.length)
        .replaceAll(RegExp(r'-+$'), ''); // Clean trailing hyphen after truncation
  }
}

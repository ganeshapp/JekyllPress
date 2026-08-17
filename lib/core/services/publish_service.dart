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

    // Generate date (filename keeps the date-only prefix)
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Generate filename: YYYY-MM-DD-kebab-case-title.md
    // If the exact path is taken, suffix the slug -2..-9 until free
    final kebabTitle = toKebabCase(title, now: now);
    var filename = '$dateStr-$kebabTitle.md';
    try {
      var taken = await _uploadService.postExists(
        config: config,
        filename: filename,
      );
      var suffix = 2;
      while (taken && suffix <= 9) {
        filename = '$dateStr-$kebabTitle-$suffix.md';
        taken = await _uploadService.postExists(
          config: config,
          filename: filename,
        );
        suffix++;
      }
      if (taken) {
        return const PublishFailure(
            'Too many posts with this title already exist for today. Please choose a different title.');
      }
    } catch (e) {
      return PublishFailure('Could not check for existing posts: $e');
    }

    // Generate minimal frontmatter (title + date only; the blog's
    // _config.yml defaults supply layout)
    final frontmatter = FrontmatterParser.generateFrontmatter(
      title: title,
      date: formatJekyllDate(now),
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
      // Generate minimal frontmatter from post data (title + date only)
      frontmatter = FrontmatterParser.generateFrontmatter(
        title: originalPost.title,
        date: originalPost.date,
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

  /// Convert title to kebab-case for filename.
  /// Unicode-aware: Korean/Japanese/accented characters are kept.
  /// Public so it can be unit tested. [now] is used for the empty-slug
  /// fallback and defaults to the current time.
  static String toKebabCase(String title, {DateTime? now}) {
    var slug = title
        .toLowerCase()
        .trim()
        // Remove apostrophes (straight and curly) entirely
        .replaceAll(RegExp("['‘’]"), '')
        // Replace every run of non-letter/non-number chars with one hyphen
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
        // Remove leading/trailing hyphens
        .replaceAll(RegExp(r'^-+|-+$'), '');

    // Limit length: cut at 50, then back to the last hyphen if that
    // leaves more than 20 chars
    if (slug.length > 50) {
      var cut = slug.substring(0, 50);
      final lastHyphen = cut.lastIndexOf('-');
      if (lastHyphen > 20) {
        cut = cut.substring(0, lastHyphen);
      }
      slug = cut.replaceAll(RegExp(r'-+$'), '');
    }

    // Fallback for punctuation-only titles
    if (slug.isEmpty) {
      final t = now ?? DateTime.now();
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      final ss = t.second.toString().padLeft(2, '0');
      return 'post-$hh$mm$ss';
    }

    return slug;
  }

  /// Format a Jekyll front matter timestamp: 'YYYY-MM-DD HH:MM:SS +HHMM'
  /// using the device's local time and offset.
  /// Public so it can be unit tested.
  static String formatJekyllDate(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    final offset = dateTime.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final offsetStr =
        '$sign${two(absOffset.inHours)}${two(absOffset.inMinutes % 60)}';
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)} '
        '$offsetStr';
  }
}

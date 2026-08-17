import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../utils/frontmatter_parser.dart';
import 'content_service.dart';
import 'github_upload_service.dart';

/// Result of a publish operation
sealed class PublishResult {
  const PublishResult();
}

class PublishSuccess extends PublishResult {
  final String sha;
  final String filename;

  /// Full repo-relative path the post was written to
  final String filePath;
  final String htmlUrl;

  const PublishSuccess({
    required this.sha,
    required this.filename,
    required this.filePath,
    required this.htmlUrl,
  });
}

class PublishFailure extends PublishResult {
  final String message;

  /// Failure class for targeted recovery UX (see [PublishErrorKind])
  final PublishErrorKind kind;
  const PublishFailure(this.message, {this.kind = PublishErrorKind.generic});
}

/// Service for publishing posts to GitHub
class PublishService {
  final GitHubUploadService _uploadService;

  PublishService({required GitHubUploadService uploadService})
      : _uploadService = uploadService;

  /// Create a new post in the active content dir (or [config.draftsPath]
  /// when [asDraft]). Generates filename, frontmatter, and uploads to
  /// GitHub. Filename rule: date-prefixed 'YYYY-MM-DD-slug.md' only when
  /// the target dir's last segment is '_posts'; collection dirs and
  /// _drafts use plain 'slug.md'.
  ///
  /// Front matter fields: [publishDate] defaults to now; [layout],
  /// [categories], and [tags] fall back to the config defaults when null,
  /// while an explicit '' / empty list (user cleared the field in the
  /// Post settings sheet) omits the key.
  Future<PublishResult> createPost({
    required AppConfig config,
    required String title,
    required String bodyContent,
    bool asDraft = false,
    DateTime? publishDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
  }) async {
    if (title.trim().isEmpty) {
      return const PublishFailure('Title cannot be empty');
    }

    final targetDir = ContentService.cleanDir(
        asDraft ? config.draftsPath : config.activeContentDir);

    // Generate date (a date-prefixed filename keeps the date-only prefix).
    // The chosen publish date drives the filename too - Jekyll derives the
    // post URL from it.
    final now = publishDate ?? DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // If the exact path is taken, suffix the slug -2..-9 until free
    final kebabTitle = toKebabCase(title, now: now);
    final stem =
        usesDatePrefixedFilenames(targetDir) && !asDraft ? '$dateStr-$kebabTitle' : kebabTitle;
    var filename = '$stem.md';
    try {
      var taken = await _uploadService.postExists(
        config: config,
        path: '$targetDir/$filename',
      );
      var suffix = 2;
      while (taken && suffix <= 9) {
        filename = '$stem-$suffix.md';
        taken = await _uploadService.postExists(
          config: config,
          path: '$targetDir/$filename',
        );
        suffix++;
      }
      if (taken) {
        return const PublishFailure(
            'Too many posts with this title already exist for today. Please choose a different title.');
      }
    } catch (e) {
      return PublishFailure('Could not check for existing posts: $e',
          kind: publishErrorKindOf(e));
    }

    // Generate minimal frontmatter (title + date; layout/categories/tags
    // only when non-empty - the blog's _config.yml defaults supply the
    // layout otherwise)
    final frontmatter = FrontmatterParser.generateFrontmatterFields(
      title: title,
      date: formatJekyllDate(now),
      layout: layout ?? config.defaultLayout,
      categories: categories ?? config.defaultCategories,
      tags: tags ?? config.defaultTags,
    );

    // Combine frontmatter and body
    final fullContent = FrontmatterParser.combineContent(frontmatter, bodyContent);

    // Upload to GitHub
    final path = '$targetDir/$filename';
    final result = await _uploadService.uploadPost(
      config: config,
      path: path,
      content: fullContent,
      existingSha: null, // New post
      commitMessage:
          asDraft ? 'Create draft: $title' : 'Create post: $title',
    );

    return switch (result) {
      UploadSuccess(sha: final sha, htmlUrl: final url) => PublishSuccess(
          sha: sha,
          filename: filename,
          filePath: path,
          htmlUrl: url,
        ),
      UploadFailure(message: final msg, kind: final kind) =>
        PublishFailure(msg, kind: kind),
    };
  }

  /// Update an existing post. Uses the original filename; the body is
  /// replaced with [newBodyContent].
  ///
  /// Front matter merge: when every merge param ([publishDate], [layout],
  /// [categories], [tags]) is null the original front matter is re-emitted
  /// byte-exact. When any is set, the original front matter is parsed, the
  /// non-null params replace the modeled keys ('' / empty list removes the
  /// key), and every unmodeled entry passes through verbatim. A date edit
  /// changes the front matter date but NEVER the filename.
  ///
  /// [force] resolves a conflict by overwriting: the file's current sha
  /// is fetched and used so the write wins over remote edits (the user
  /// chose 'Overwrite with my version' in the conflict dialog).
  Future<PublishResult> updatePost({
    required AppConfig config,
    required BlogPost originalPost,
    required String newBodyContent,
    DateTime? publishDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
    bool force = false,
  }) async {
    if (originalPost.fileName == null) {
      return const PublishFailure('Cannot update post without filename');
    }

    if (originalPost.sha == null) {
      return const PublishFailure('Cannot update post without SHA');
    }

    final rawFrontmatter = originalPost.rawFrontmatter ?? '';
    final hasEdits = publishDate != null ||
        layout != null ||
        categories != null ||
        tags != null;

    // Reconstruct frontmatter - preserve original unless edited
    String frontmatter;
    if (hasEdits) {
      // Merge: sheet edits replace the modeled keys, everything the model
      // doesn't understand is re-emitted verbatim
      final parsed = FrontmatterParser.parseFields(rawFrontmatter);
      final hadFrontmatter = rawFrontmatter.trim().isNotEmpty;
      // An explicit sheet edit replaces its modeled key outright. When the
      // original held that key in a form the parser could not lift (so it
      // sits in passthrough verbatim), re-emitting the block alongside the
      // new value would produce duplicate YAML keys - and Jekyll's
      // last-key-wins would silently discard the user's edit. Drop the
      // superseded passthrough blocks; untouched (null) params keep every
      // passthrough entry byte-exact as before.
      final overriddenKeys = <String>{
        if (publishDate != null) 'date',
        if (layout != null) 'layout',
        if (categories != null) 'categories',
        if (tags != null) 'tags',
      };
      final passthrough = <String, String>{
        for (final entry in parsed.passthrough.entries)
          if (!overriddenKeys
              .contains(entry.key.split('#').first.toLowerCase()))
            entry.key: entry.value,
      };
      frontmatter = FrontmatterParser.generateFrontmatterFields(
        // Title is locked for existing posts. Only emit a title line when
        // the original had one (or had no front matter at all) so a post
        // relying on a heading-derived title doesn't gain a bogus field.
        title: parsed.title != null || !hadFrontmatter
            ? originalPost.title
            : null,
        // An untouched date keeps the original raw value verbatim
        date: publishDate != null
            ? formatJekyllDate(publishDate)
            : parsed.date ?? (hadFrontmatter ? null : originalPost.date),
        layout: layout ?? parsed.layout,
        categories: categories ?? parsed.categories,
        tags: tags ?? parsed.tags,
        passthrough: passthrough,
      );
      // generateFrontmatterFields ends with '---\n'; combineContent adds
      // the separating newline, so strip the trailing one
      frontmatter = frontmatter.trimRight();
    } else if (rawFrontmatter.isNotEmpty) {
      // Use original frontmatter wrapped in delimiters
      frontmatter = '---\n$rawFrontmatter\n---';
    } else {
      // Generate minimal frontmatter from post data (title + date only)
      frontmatter = FrontmatterParser.generateFrontmatter(
        title: originalPost.title,
        date: originalPost.date,
      );
    }

    // Combine frontmatter and new body
    final fullContent = FrontmatterParser.combineContent(frontmatter, newBodyContent);

    // Write back to the post's own path; v1 cache records have no
    // filePath, so fall back to '<postsPath>/<fileName>'
    final path = originalPost.filePath ??
        '${ContentService.cleanDir(config.postsPath)}/${originalPost.fileName!}';

    // Upload to GitHub with SHA for update
    final result = await _uploadService.uploadPost(
      config: config,
      path: path,
      content: fullContent,
      existingSha: originalPost.sha,
      commitMessage: 'Update post: ${originalPost.title}',
      force: force,
    );

    return switch (result) {
      UploadSuccess(sha: final sha, htmlUrl: final url) => PublishSuccess(
          sha: sha,
          filename: originalPost.fileName!,
          filePath: path,
          htmlUrl: url,
        ),
      UploadFailure(message: final msg, kind: final kind) =>
        PublishFailure(msg, kind: kind),
    };
  }

  /// True when posts in [dir] use Jekyll's date-prefixed
  /// 'YYYY-MM-DD-slug.md' filenames: only when the dir's last path
  /// segment is '_posts' (covers nested layouts like docs/_posts).
  /// Collection dirs (_wiki, _projects, ...) and _drafts use plain
  /// 'slug.md'. Public so it can be unit tested.
  static bool usesDatePrefixedFilenames(String dir) {
    final cleaned = ContentService.cleanDir(dir);
    if (cleaned.isEmpty) return false;
    return cleaned.split('/').last == '_posts';
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

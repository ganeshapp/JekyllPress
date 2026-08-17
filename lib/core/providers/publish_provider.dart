import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../services/content_service.dart';
import '../services/github_upload_service.dart';
import '../services/publish_service.dart';
import '../utils/frontmatter_parser.dart';
import '../utils/permalink.dart';
import 'config_provider.dart';
import 'image_provider.dart';
import 'posts_provider.dart';

part 'publish_provider.g.dart';

/// Provider for PublishService
@riverpod
PublishService publishService(Ref ref) {
  final uploadService = ref.watch(githubUploadServiceProvider);
  return PublishService(uploadService: uploadService);
}

/// Filename a promoted draft gets in the posts dir: today's date prefix
/// plus the draft's slug (any existing 'YYYY-MM-DD-' prefix is stripped,
/// the extension normalizes to .md). [datePrefixed] follows the target
/// dir's convention - collection dirs keep plain 'slug.md'.
String promotedFileName(
  String draftFileName,
  DateTime now, {
  bool datePrefixed = true,
}) {
  var slug = draftFileName
      .replaceFirst(RegExp(r'\.(md|markdown)$', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^\d{4}-\d{1,2}-\d{1,2}-'), '');
  if (slug.isEmpty) slug = 'post';
  if (!datePrefixed) return '$slug.md';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}-$slug.md';
}

/// Front matter block (with '---' delimiters, no trailing newline) for a
/// promoted draft: the draft's front matter is preserved VERBATIM, with
/// a 'date:' full timestamp of [now] appended only when it has no date
/// key. Drafts with no front matter at all get minimal title+date.
String promotedFrontmatter({
  required String rawFrontmatter,
  required String title,
  required DateTime now,
}) {
  final dateValue = PublishService.formatJekyllDate(now);
  if (rawFrontmatter.trim().isEmpty) {
    return FrontmatterParser.generateFrontmatter(title: title, date: dateValue)
        .trimRight();
  }
  final parsed = FrontmatterParser.parseFields(rawFrontmatter);
  // A date the parser could not lift (multiline/odd form) still counts -
  // its passthrough key starts with 'date'
  final hasDate = parsed.date != null ||
      parsed.passthrough.keys
          .any((k) => k.split('#').first.toLowerCase() == 'date');
  if (hasDate) {
    return '---\n$rawFrontmatter\n---';
  }
  return '---\n$rawFrontmatter\ndate: $dateValue\n---';
}

/// Date and categories that drive a just-updated post's public URL:
/// explicit Post-settings edits win, then the original front matter,
/// then the post's own date field. Top-level and pure for unit testing.
({DateTime date, List<String> categories}) urlFieldsForUpdate({
  required BlogPost originalPost,
  DateTime? publishDate,
  List<String>? categories,
}) {
  final raw = originalPost.rawFrontmatter;
  final parsed = raw == null ? null : FrontmatterParser.parseFields(raw);
  return (
    date: publishDate ?? parsed?.dateTime ?? originalPost.dateTime,
    categories: categories ?? parsed?.categories ?? const [],
  );
}

/// State for publish operation
sealed class PublishState {
  const PublishState();
}

class PublishIdle extends PublishState {
  const PublishIdle();
}

class Publishing extends PublishState {
  final String message;
  const Publishing([this.message = 'Publishing...']);
}

class PublishSucceeded extends PublishState {
  final String filename;
  final String htmlUrl;

  /// The post's public URL on the configured site (permalink-expanded).
  /// Null when no site URL is configured or the file has no public page
  /// (remote drafts).
  final String? publicUrl;

  const PublishSucceeded({
    required this.filename,
    required this.htmlUrl,
    this.publicUrl,
  });
}

class PublishFailed extends PublishState {
  final String error;

  /// Failure class so the editor can offer targeted recovery
  /// (conflict dialog / offline queue) without string matching
  final PublishErrorKind kind;
  const PublishFailed(this.error, {this.kind = PublishErrorKind.generic});
}

/// Notifier for managing publish operations
@riverpod
class PublishNotifier extends _$PublishNotifier {
  @override
  PublishState build() {
    return const PublishIdle();
  }

  /// Get current app config
  AppConfig? get _config {
    final configState = ref.read(configNotifierProvider);
    return configState is ConfigLoaded ? configState.config : null;
  }

  /// Publish a new post. [publishDate]/[layout]/[categories]/[tags] come
  /// from the editor's Post settings sheet; null falls back to the config
  /// defaults, '' / empty list omits the key (see PublishService.createPost).
  /// [asDraft] writes to the remote Jekyll drafts dir instead.
  Future<bool> publishNewPost({
    required String title,
    required String bodyContent,
    bool asDraft = false,
    DateTime? publishDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
  }) async {
    final config = _config;
    if (config == null) {
      state = const PublishFailed('No repository configured');
      return false;
    }

    state = Publishing(asDraft ? 'Saving draft...' : 'Creating post...');

    try {
      final publishService = ref.read(publishServiceProvider);
      final result = await publishService.createPost(
        config: config,
        title: title,
        bodyContent: bodyContent,
        asDraft: asDraft,
        publishDate: publishDate,
        layout: layout,
        categories: categories,
        tags: tags,
      );

      switch (result) {
        case PublishSuccess(filename: final f, htmlUrl: final url):
          state = PublishSucceeded(
            filename: f,
            htmlUrl: url,
            // Remote drafts have no public page until promoted
            publicUrl: asDraft
                ? null
                : buildPostUrl(
                    siteUrl: config.siteUrl,
                    baseurl: config.baseurl,
                    permalinkPattern: config.permalinkPattern,
                    fileName: f,
                    date: publishDate ?? DateTime.now(),
                    categories: categories ?? config.defaultCategories,
                  ),
          );
          return true;
        case PublishFailure(message: final msg, kind: final kind):
          state = PublishFailed(msg, kind: kind);
          return false;
      }
    } catch (e) {
      // Never let an exception escape to the async zone - surface it
      state = PublishFailed('Publish failed: $e', kind: publishErrorKindOf(e));
      return false;
    }
  }

  /// Update an existing post. When all merge params are null the original
  /// front matter is preserved byte-exact; otherwise the sheet edits are
  /// merged into the modeled keys and unmodeled entries pass through
  /// verbatim (see PublishService.updatePost). [force] overwrites the
  /// remote version after a conflict (the user's explicit choice).
  Future<bool> publishUpdate({
    required BlogPost originalPost,
    required String newBodyContent,
    DateTime? publishDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
    bool force = false,
  }) async {
    final config = _config;
    if (config == null) {
      state = const PublishFailed('No repository configured');
      return false;
    }

    state = const Publishing('Updating post...');

    try {
      final publishService = ref.read(publishServiceProvider);
      final result = await publishService.updatePost(
        config: config,
        originalPost: originalPost,
        newBodyContent: newBodyContent,
        publishDate: publishDate,
        layout: layout,
        categories: categories,
        tags: tags,
        force: force,
      );

      switch (result) {
        case PublishSuccess(filename: final f, htmlUrl: final url):
          final urlFields = urlFieldsForUpdate(
            originalPost: originalPost,
            publishDate: publishDate,
            categories: categories,
          );
          state = PublishSucceeded(
            filename: f,
            htmlUrl: url,
            // A remote draft edited in place has no public page
            publicUrl: isRemoteDraft(originalPost, config)
                ? null
                : buildPostUrl(
                    siteUrl: config.siteUrl,
                    baseurl: config.baseurl,
                    permalinkPattern: config.permalinkPattern,
                    fileName: f,
                    date: urlFields.date,
                    categories: urlFields.categories,
                  ),
          );
          return true;
        case PublishFailure(message: final msg, kind: final kind):
          state = PublishFailed(msg, kind: kind);
          return false;
      }
    } catch (e) {
      // Never let an exception escape to the async zone - surface it
      state = PublishFailed('Publish failed: $e', kind: publishErrorKindOf(e));
      return false;
    }
  }

  /// Promote a remote Jekyll draft: create it in the active content dir
  /// (date-prefixed filename when that dir uses Jekyll post naming, front
  /// matter kept verbatim with a date stamped in only when absent), then
  /// delete the old _drafts file. Returns null on success, otherwise a
  /// user-facing error message. Does not touch [state] - the dashboard
  /// drives this, not the editor.
  Future<String?> promoteRemoteDraft(BlogPost draft) async {
    final config = _config;
    if (config == null) return 'No repository configured';
    final fileName = draft.fileName;
    final filePath = draft.filePath;
    final sha = draft.sha;
    if (fileName == null || filePath == null || sha == null) {
      return 'This draft is missing its GitHub file info - '
          'pull to refresh and retry';
    }

    final uploadService = ref.read(githubUploadServiceProvider);
    final now = DateTime.now();
    final targetDir = ContentService.cleanDir(config.activeContentDir);
    final newFileName = promotedFileName(
      fileName,
      now,
      datePrefixed: PublishService.usesDatePrefixedFilenames(targetDir),
    );
    final newPath = '$targetDir/$newFileName';

    // A previous promote may have created the post but failed at the
    // delete-old-draft step. When the file at the target path already
    // holds this draft's body, the create is done - skip straight to
    // removing the old draft instead of erroring out.
    var alreadyPromoted = false;
    try {
      if (await uploadService.postExists(config: config, path: newPath)) {
        final existing = await ref
            .read(contentServiceProvider)
            .fetchFileContent(config, newPath);
        if (FrontmatterParser.parse(existing).bodyContent.trim() !=
            draft.bodyContent.trim()) {
          return 'A post already exists at $newPath - rename the draft first';
        }
        alreadyPromoted = true;
      }
    } catch (e) {
      return 'Could not check the posts folder: $e';
    }

    if (!alreadyPromoted) {
      final content = FrontmatterParser.combineContent(
        promotedFrontmatter(
          rawFrontmatter: draft.rawFrontmatter ?? '',
          title: draft.title,
          now: now,
        ),
        draft.bodyContent,
      );

      final uploadResult = await uploadService.uploadPost(
        config: config,
        path: newPath,
        content: content,
        existingSha: null,
        commitMessage: 'Publish draft: ${draft.title}',
      );
      if (uploadResult is UploadFailure) return uploadResult.message;
    }

    final deleteResult = await uploadService.deleteFile(
      config: config,
      path: filePath,
      sha: sha,
      commitMessage: 'Remove draft: $fileName',
    );
    if (deleteResult is DeleteFailure) {
      return 'Draft was published to $newPath, but the old draft could '
          'not be removed: ${deleteResult.message}';
    }
    return null;
  }

  /// Delete a post/draft file from GitHub. Returns null on success,
  /// otherwise a user-facing error message. Stale shas are retried once
  /// inside [GitHubUploadService.deleteFile].
  Future<String?> deleteRemotePost(BlogPost post) async {
    final config = _config;
    if (config == null) return 'No repository configured';
    final path = post.filePath ??
        (post.fileName != null
            ? '${ContentService.cleanDir(config.postsPath)}/${post.fileName}'
            : null);
    final sha = post.sha;
    if (path == null || sha == null) {
      return 'This post is missing its GitHub file info - '
          'pull to refresh and retry';
    }

    final result = await ref.read(githubUploadServiceProvider).deleteFile(
          config: config,
          path: path,
          sha: sha,
          commitMessage: 'Delete: ${post.fileName ?? path}',
        );
    return switch (result) {
      DeleteSuccess() => null,
      DeleteFailure(message: final msg) => msg,
    };
  }

  /// Reset state
  void reset() {
    state = const PublishIdle();
  }
}

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/blog_post.dart';
import '../utils/frontmatter_parser.dart';

part 'editor_provider.g.dart';

/// State representing the editor content
class EditorState {
  final String title;
  final String bodyContent;
  final BlogPost? originalPost;

  /// The content the editor was loaded with (draft or post content).
  /// [hasUnsavedChanges] compares against this baseline so a resumed
  /// draft with no new keystrokes reads as "no changes".
  final String baselineTitle;
  final String baselineBody;
  final bool isDirty;
  final bool isNewPost;

  /// User-picked publication date from the Post settings sheet.
  /// Null = default: "now" at publish time for new posts, the original
  /// front matter date (kept verbatim) for existing posts.
  final DateTime? publishDate;

  /// Original front matter date of the post being edited (display only,
  /// used to pre-fill the date picker). Null for new posts or when the
  /// original front matter has no parseable date.
  final DateTime? originalDate;

  /// Front matter layout ('' = omit, letting _config.yml defaults apply)
  final String layout;

  /// Front matter categories (empty = omit)
  final List<String> categories;

  /// Front matter tags (empty = omit)
  final List<String> tags;

  /// Unmodeled front matter entries of the post being edited, verbatim
  /// (see [PostFrontmatter.passthrough]). Read-only in the UI; re-emitted
  /// as-is on publish.
  final Map<String, String> passthrough;

  /// True once the user changed anything in the Post settings sheet.
  /// While false, publishing an existing post re-emits its original
  /// front matter byte-exact instead of regenerating it.
  final bool frontmatterEdited;

  const EditorState({
    required this.title,
    required this.bodyContent,
    this.originalPost,
    this.baselineTitle = '',
    this.baselineBody = '',
    this.isDirty = false,
    required this.isNewPost,
    this.publishDate,
    this.originalDate,
    this.layout = '',
    this.categories = const [],
    this.tags = const [],
    this.passthrough = const {},
    this.frontmatterEdited = false,
  });

  EditorState copyWith({
    String? title,
    String? bodyContent,
    BlogPost? originalPost,
    String? baselineTitle,
    String? baselineBody,
    bool? isDirty,
    bool? isNewPost,
    DateTime? publishDate,
    DateTime? originalDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
    Map<String, String>? passthrough,
    bool? frontmatterEdited,
  }) {
    return EditorState(
      title: title ?? this.title,
      bodyContent: bodyContent ?? this.bodyContent,
      originalPost: originalPost ?? this.originalPost,
      baselineTitle: baselineTitle ?? this.baselineTitle,
      baselineBody: baselineBody ?? this.baselineBody,
      isDirty: isDirty ?? this.isDirty,
      isNewPost: isNewPost ?? this.isNewPost,
      publishDate: publishDate ?? this.publishDate,
      originalDate: originalDate ?? this.originalDate,
      layout: layout ?? this.layout,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      passthrough: passthrough ?? this.passthrough,
      frontmatterEdited: frontmatterEdited ?? this.frontmatterEdited,
    );
  }

  /// Check if there are unsaved changes relative to the loaded baseline.
  /// Post-settings edits count too (they only persist on publish).
  bool get hasUnsavedChanges {
    return title != baselineTitle ||
        bodyContent != baselineBody ||
        frontmatterEdited;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EditorState &&
        runtimeType == other.runtimeType &&
        title == other.title &&
        bodyContent == other.bodyContent &&
        originalPost == other.originalPost &&
        baselineTitle == other.baselineTitle &&
        baselineBody == other.baselineBody &&
        isDirty == other.isDirty &&
        isNewPost == other.isNewPost &&
        publishDate == other.publishDate &&
        originalDate == other.originalDate &&
        layout == other.layout &&
        listEquals(categories, other.categories) &&
        listEquals(tags, other.tags) &&
        mapEquals(passthrough, other.passthrough) &&
        frontmatterEdited == other.frontmatterEdited;
  }

  @override
  int get hashCode => Object.hash(
        title,
        bodyContent,
        originalPost,
        baselineTitle,
        baselineBody,
        isDirty,
        isNewPost,
        publishDate,
        originalDate,
        layout,
        Object.hashAll(categories),
        Object.hashAll(tags),
        // Order-independent, matching mapEquals semantics
        passthrough.entries.fold<int>(
            0, (h, e) => h ^ Object.hash(e.key, e.value)),
        frontmatterEdited,
      );
}

/// Controller for managing editor state
/// This preserves state across tab switches and rebuilds
@riverpod
class EditorController extends _$EditorController {
  @override
  EditorState build() {
    // Default state for new post
    return const EditorState(
      title: '',
      bodyContent: '',
      originalPost: null,
      isDirty: false,
      isNewPost: true,
    );
  }

  /// Initialize editor with an existing post (for editing).
  /// The post's front matter is parsed so the Post settings sheet shows
  /// its real layout/categories/tags/date; unmodeled fields are kept
  /// verbatim in [EditorState.passthrough].
  void initializeWithPost(BlogPost post) {
    final parsed = FrontmatterParser.parseFields(post.rawFrontmatter ?? '');
    state = EditorState(
      title: post.title,
      bodyContent: post.bodyContent,
      originalPost: post,
      baselineTitle: post.title,
      baselineBody: post.bodyContent,
      isDirty: false,
      isNewPost: false,
      originalDate:
          parsed.dateTime ?? FrontmatterParser.parseDateValue(post.date),
      layout: parsed.layout ?? '',
      categories: parsed.categories,
      tags: parsed.tags,
      passthrough: parsed.passthrough,
    );
  }

  /// Initialize editor for a new post. The config's front matter defaults
  /// pre-fill the Post settings sheet (the user can clear them there).
  void initializeNewPost({
    String? defaultLayout,
    List<String> defaultCategories = const [],
    List<String> defaultTags = const [],
  }) {
    state = EditorState(
      title: '',
      bodyContent: '',
      originalPost: null,
      isDirty: false,
      isNewPost: true,
      layout: defaultLayout ?? '',
      categories: defaultCategories,
      tags: defaultTags,
    );
  }

  /// Initialize editor with resumed draft content.
  /// The draft content becomes the baseline, so resuming a draft with no
  /// new keystrokes shows as saved/idle rather than permanently "Editing".
  /// [originalPost] is non-null when the draft was editing an existing
  /// post - its front matter then seeds the Post settings sheet; for a
  /// brand-new draft the config defaults do.
  void initializeWithDraft({
    required String title,
    required String bodyContent,
    BlogPost? originalPost,
    String? defaultLayout,
    List<String> defaultCategories = const [],
    List<String> defaultTags = const [],
  }) {
    final parsed = originalPost != null
        ? FrontmatterParser.parseFields(originalPost.rawFrontmatter ?? '')
        : null;
    state = EditorState(
      title: title,
      bodyContent: bodyContent,
      originalPost: originalPost,
      baselineTitle: title,
      baselineBody: bodyContent,
      isDirty: false,
      isNewPost: originalPost == null,
      originalDate: parsed == null
          ? null
          : parsed.dateTime ??
              FrontmatterParser.parseDateValue(originalPost!.date),
      layout: parsed != null ? (parsed.layout ?? '') : (defaultLayout ?? ''),
      categories: parsed?.categories ?? defaultCategories,
      tags: parsed?.tags ?? defaultTags,
      passthrough: parsed?.passthrough ?? const {},
    );
  }

  /// Update the title
  void updateTitle(String title) {
    state = state.copyWith(
      title: title,
      isDirty: true,
    );
  }

  /// Update the body content
  void updateBody(String bodyContent) {
    state = state.copyWith(
      bodyContent: bodyContent,
      isDirty: true,
    );
  }

  /// Update the publication date (Post settings sheet)
  void updatePublishDate(DateTime date) {
    state = state.copyWith(
      publishDate: date,
      isDirty: true,
      frontmatterEdited: true,
    );
  }

  /// Update the layout (Post settings sheet); '' = omit
  void updateLayout(String layout) {
    state = state.copyWith(
      layout: layout,
      isDirty: true,
      frontmatterEdited: true,
    );
  }

  /// Replace the categories list (Post settings sheet)
  void updateCategories(List<String> categories) {
    state = state.copyWith(
      categories: List.unmodifiable(categories),
      isDirty: true,
      frontmatterEdited: true,
    );
  }

  /// Replace the tags list (Post settings sheet)
  void updateTags(List<String> tags) {
    state = state.copyWith(
      tags: List.unmodifiable(tags),
      isDirty: true,
      frontmatterEdited: true,
    );
  }

  /// Reset editor to original state (discard changes)
  void reset() {
    if (state.originalPost != null) {
      initializeWithPost(state.originalPost!);
    } else {
      initializeNewPost();
    }
  }

  /// Clear the editor completely
  void clear() {
    state = const EditorState(
      title: '',
      bodyContent: '',
      originalPost: null,
      isDirty: false,
      isNewPost: true,
    );
  }
}

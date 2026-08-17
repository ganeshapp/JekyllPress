import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/blog_post.dart';

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

  const EditorState({
    required this.title,
    required this.bodyContent,
    this.originalPost,
    this.baselineTitle = '',
    this.baselineBody = '',
    this.isDirty = false,
    required this.isNewPost,
  });

  EditorState copyWith({
    String? title,
    String? bodyContent,
    BlogPost? originalPost,
    String? baselineTitle,
    String? baselineBody,
    bool? isDirty,
    bool? isNewPost,
  }) {
    return EditorState(
      title: title ?? this.title,
      bodyContent: bodyContent ?? this.bodyContent,
      originalPost: originalPost ?? this.originalPost,
      baselineTitle: baselineTitle ?? this.baselineTitle,
      baselineBody: baselineBody ?? this.baselineBody,
      isDirty: isDirty ?? this.isDirty,
      isNewPost: isNewPost ?? this.isNewPost,
    );
  }

  /// Check if there are unsaved changes relative to the loaded baseline
  bool get hasUnsavedChanges {
    return title != baselineTitle || bodyContent != baselineBody;
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
        isNewPost == other.isNewPost;
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

  /// Initialize editor with an existing post (for editing)
  void initializeWithPost(BlogPost post) {
    state = EditorState(
      title: post.title,
      bodyContent: post.bodyContent,
      originalPost: post,
      baselineTitle: post.title,
      baselineBody: post.bodyContent,
      isDirty: false,
      isNewPost: false,
    );
  }

  /// Initialize editor for a new post
  void initializeNewPost() {
    state = const EditorState(
      title: '',
      bodyContent: '',
      originalPost: null,
      isDirty: false,
      isNewPost: true,
    );
  }

  /// Initialize editor with resumed draft content.
  /// The draft content becomes the baseline, so resuming a draft with no
  /// new keystrokes shows as saved/idle rather than permanently "Editing".
  /// [originalPost] is non-null when the draft was editing an existing post.
  void initializeWithDraft({
    required String title,
    required String bodyContent,
    BlogPost? originalPost,
  }) {
    state = EditorState(
      title: title,
      bodyContent: bodyContent,
      originalPost: originalPost,
      baselineTitle: title,
      baselineBody: bodyContent,
      isDirty: false,
      isNewPost: originalPost == null,
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

  /// Get the current post data (for saving)
  BlogPost toPost() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (state.originalPost != null) {
      // Editing existing post - preserve original metadata
      return state.originalPost!.copyWith(
        title: state.title,
        bodyContent: state.bodyContent,
      );
    } else {
      // New post
      return BlogPost(
        title: state.title,
        date: dateStr,
        bodyContent: state.bodyContent,
        isLocalDraft: true,
      );
    }
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

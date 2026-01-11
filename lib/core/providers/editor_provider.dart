import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/blog_post.dart';

part 'editor_provider.g.dart';

/// State representing the editor content
class EditorState {
  final String title;
  final String bodyContent;
  final BlogPost? originalPost;
  final bool isDirty;
  final bool isNewPost;

  const EditorState({
    required this.title,
    required this.bodyContent,
    this.originalPost,
    this.isDirty = false,
    required this.isNewPost,
  });

  EditorState copyWith({
    String? title,
    String? bodyContent,
    BlogPost? originalPost,
    bool? isDirty,
    bool? isNewPost,
  }) {
    return EditorState(
      title: title ?? this.title,
      bodyContent: bodyContent ?? this.bodyContent,
      originalPost: originalPost ?? this.originalPost,
      isDirty: isDirty ?? this.isDirty,
      isNewPost: isNewPost ?? this.isNewPost,
    );
  }

  /// Check if there are unsaved changes
  bool get hasUnsavedChanges {
    if (originalPost == null) {
      // New post - dirty if has content
      return title.isNotEmpty || bodyContent.isNotEmpty;
    }
    // Existing post - check if content changed
    return title != originalPost!.title || bodyContent != originalPost!.bodyContent;
  }
}

/// Controller for managing editor state
/// This preserves state across tab switches and rebuilds
@riverpod
class EditorController extends _$EditorController {
  @override
  EditorState build() {
    // Default state for new post
    return EditorState(
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/models/blog_post.dart';
import 'package:jekyllpress/core/providers/editor_provider.dart';

void main() {
  BlogPost buildPost({
    String title = 'Hello World',
    String body = 'Some body content',
    String date = '2024-03-15',
  }) {
    return BlogPost(
      sha: 'abc123',
      fileName: '2024-03-15-hello-world.md',
      title: title,
      date: date,
      bodyContent: body,
    );
  }

  group('EditorState equality', () {
    test('identical field values are equal with same hashCode', () {
      const a = EditorState(
        title: 't',
        bodyContent: 'b',
        baselineTitle: 't',
        baselineBody: 'b',
        isNewPost: true,
      );
      const b = EditorState(
        title: 't',
        bodyContent: 'b',
        baselineTitle: 't',
        baselineBody: 'b',
        isNewPost: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing content is not equal', () {
      const a = EditorState(title: 't', bodyContent: 'b', isNewPost: true);
      const b = EditorState(title: 't', bodyContent: 'c', isNewPost: true);
      const c = EditorState(title: 'x', bodyContent: 'b', isNewPost: true);
      const d = EditorState(title: 't', bodyContent: 'b', isNewPost: false);

      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('copyWith with no changes stays equal (rebuild suppression)', () {
      const a = EditorState(
        title: 't',
        bodyContent: 'b',
        baselineTitle: 't',
        baselineBody: 'b',
        isDirty: true,
        isNewPost: true,
      );

      expect(a.copyWith(), equals(a));
    });
  });

  group('EditorState.hasUnsavedChanges', () {
    test('empty new post has no unsaved changes', () {
      const state = EditorState(title: '', bodyContent: '', isNewPost: true);
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('content matching baseline has no unsaved changes', () {
      const state = EditorState(
        title: 'Draft title',
        bodyContent: 'Draft body',
        baselineTitle: 'Draft title',
        baselineBody: 'Draft body',
        isNewPost: true,
      );
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('content diverging from baseline has unsaved changes', () {
      const state = EditorState(
        title: 'Draft title',
        bodyContent: 'Draft body edited',
        baselineTitle: 'Draft title',
        baselineBody: 'Draft body',
        isNewPost: true,
      );
      expect(state.hasUnsavedChanges, isTrue);
    });
  });

  group('EditorController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializeWithDraft sets draft content as baseline', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithDraft(
        title: 'Resumed title',
        bodyContent: 'Resumed body',
      );

      final state = container.read(editorControllerProvider);
      expect(state.title, 'Resumed title');
      expect(state.bodyContent, 'Resumed body');
      expect(state.isNewPost, isTrue);
      expect(state.originalPost, isNull);
      // Resumed draft with no new keystrokes shows as no changes
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('initializeWithDraft for existing post keeps originalPost', () {
      final post = buildPost();
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithDraft(
        title: post.title,
        bodyContent: 'Draft body different from post',
        originalPost: post,
      );

      final state = container.read(editorControllerProvider);
      expect(state.isNewPost, isFalse);
      expect(state.originalPost, post);
      // Baseline is the draft content, not the post content
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('typing after resume marks unsaved, reverting clears it', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithDraft(
        title: 'Title',
        bodyContent: 'Body',
      );

      controller.updateBody('Body plus');
      expect(container.read(editorControllerProvider).hasUnsavedChanges, isTrue);

      controller.updateBody('Body');
      expect(container.read(editorControllerProvider).hasUnsavedChanges, isFalse);
    });

    test('initializeWithPost uses post content as baseline', () {
      final post = buildPost();
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithPost(post);

      var state = container.read(editorControllerProvider);
      expect(state.hasUnsavedChanges, isFalse);
      expect(state.isNewPost, isFalse);

      controller.updateBody('changed');
      state = container.read(editorControllerProvider);
      expect(state.hasUnsavedChanges, isTrue);
    });

    test('identical update does not change state (operator==)', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithDraft(title: 'T', bodyContent: 'B');

      final before = container.read(editorControllerProvider);
      controller.updateBody('B2');
      final after = container.read(editorControllerProvider);
      controller.updateBody('B2');
      final again = container.read(editorControllerProvider);

      expect(before, isNot(equals(after)));
      expect(after, equals(again));
    });

    test('toPost preserves original metadata when editing', () {
      final post = buildPost();
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithPost(post);
      controller.updateBody('new body');

      final result = controller.toPost();
      expect(result.sha, post.sha);
      expect(result.fileName, post.fileName);
      expect(result.date, post.date);
      expect(result.bodyContent, 'new body');
    });

    test('clear resets to empty new-post state', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithPost(buildPost());
      controller.clear();

      final state = container.read(editorControllerProvider);
      expect(state.title, isEmpty);
      expect(state.bodyContent, isEmpty);
      expect(state.originalPost, isNull);
      expect(state.isNewPost, isTrue);
      expect(state.hasUnsavedChanges, isFalse);
    });
  });
}

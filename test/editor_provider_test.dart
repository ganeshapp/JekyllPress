import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/models/blog_post.dart';
import 'package:jekyllpress/core/providers/editor_provider.dart';

void main() {
  BlogPost buildPost({
    String title = 'Hello World',
    String body = 'Some body content',
    String date = '2024-03-15',
    String? rawFrontmatter,
  }) {
    return BlogPost(
      sha: 'abc123',
      fileName: '2024-03-15-hello-world.md',
      title: title,
      date: date,
      rawFrontmatter: rawFrontmatter,
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

    test('front matter fields participate in == and hashCode', () {
      final a = EditorState(
        title: 't',
        bodyContent: 'b',
        isNewPost: true,
        publishDate: DateTime(2024, 3, 15, 10, 30),
        layout: 'single',
        categories: const ['blog'],
        tags: const ['dev'],
        passthrough: const {'header': 'header:\n  image: /x.jpg'},
      );
      final b = EditorState(
        title: 't',
        bodyContent: 'b',
        isNewPost: true,
        publishDate: DateTime(2024, 3, 15, 10, 30),
        // Different list/map instances with the same content
        layout: 'single',
        categories: ['blog'],
        tags: ['dev'],
        passthrough: {'header': 'header:\n  image: /x.jpg'},
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      expect(a, isNot(equals(a.copyWith(tags: ['other']))));
      expect(a, isNot(equals(a.copyWith(layout: ''))));
      expect(a, isNot(equals(a.copyWith(frontmatterEdited: true))));
      expect(
        a,
        isNot(equals(a.copyWith(publishDate: DateTime(2025, 1, 1)))),
      );
    });

    test('copyWith with no changes stays equal with front matter set', () {
      final a = EditorState(
        title: 't',
        bodyContent: 'b',
        isNewPost: false,
        originalDate: DateTime(2024, 3, 15),
        layout: 'post',
        categories: const ['a', 'b'],
        passthrough: const {'toc': 'toc: true'},
        frontmatterEdited: true,
      );
      expect(a.copyWith(), equals(a));
      expect(a.copyWith().hashCode, equals(a.hashCode));
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

  group('EditorController front matter (Post settings)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializeNewPost pre-fills config defaults', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeNewPost(
        defaultLayout: 'single',
        defaultCategories: const ['blog'],
        defaultTags: const ['dev'],
      );

      final state = container.read(editorControllerProvider);
      expect(state.layout, 'single');
      expect(state.categories, ['blog']);
      expect(state.tags, ['dev']);
      expect(state.publishDate, isNull);
      expect(state.originalDate, isNull);
      expect(state.passthrough, isEmpty);
      expect(state.frontmatterEdited, isFalse);
      expect(state.hasUnsavedChanges, isFalse);
    });

    test('initializeWithPost parses the post front matter into the sheet '
        'state and keeps unknown fields as passthrough', () {
      final post = buildPost(
        rawFrontmatter: 'title: "Hello World"\n'
            'date: 2024-03-15 10:30:00 +0000\n'
            'layout: wide\n'
            'categories: [a, b]\n'
            'tags:\n  - t1\n'
            'header:\n  image: /hero.jpg',
      );
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithPost(post);

      final state = container.read(editorControllerProvider);
      expect(state.layout, 'wide');
      expect(state.categories, ['a', 'b']);
      expect(state.tags, ['t1']);
      expect(state.passthrough['header'], 'header:\n  image: /hero.jpg');
      expect(state.publishDate, isNull);
      expect(state.originalDate!.toUtc(),
          DateTime.utc(2024, 3, 15, 10, 30));
      expect(state.frontmatterEdited, isFalse);
    });

    test('initializeWithPost without raw front matter falls back to the '
        'post date for originalDate', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithPost(buildPost());

      final state = container.read(editorControllerProvider);
      expect(state.originalDate, DateTime(2024, 3, 15));
      expect(state.layout, isEmpty);
      expect(state.passthrough, isEmpty);
    });

    test('initializeWithDraft: existing post front matter wins over '
        'config defaults', () {
      final post = buildPost(
        rawFrontmatter: 'title: "Hello World"\nlayout: wide\ntoc: true',
      );
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithDraft(
        title: 'Draft title',
        bodyContent: 'Draft body',
        originalPost: post,
        defaultLayout: 'single',
        defaultCategories: const ['blog'],
      );

      final state = container.read(editorControllerProvider);
      expect(state.layout, 'wide');
      expect(state.categories, isEmpty);
      expect(state.passthrough['toc'], 'toc: true');
    });

    test('initializeWithDraft: brand-new draft uses config defaults', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithDraft(
        title: 'T',
        bodyContent: 'B',
        defaultLayout: 'single',
        defaultTags: const ['dev'],
      );

      final state = container.read(editorControllerProvider);
      expect(state.layout, 'single');
      expect(state.tags, ['dev']);
      expect(state.passthrough, isEmpty);
    });

    test('sheet updates set frontmatterEdited and hasUnsavedChanges', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeNewPost(defaultLayout: 'single');

      controller.updateLayout('');
      var state = container.read(editorControllerProvider);
      expect(state.layout, isEmpty);
      expect(state.frontmatterEdited, isTrue);
      expect(state.hasUnsavedChanges, isTrue);

      controller.updateCategories(const ['x']);
      controller.updateTags(const ['y', 'z']);
      controller.updatePublishDate(DateTime(2026, 8, 17, 9, 15));

      state = container.read(editorControllerProvider);
      expect(state.categories, ['x']);
      expect(state.tags, ['y', 'z']);
      expect(state.publishDate, DateTime(2026, 8, 17, 9, 15));
    });

    test('body/title edits alone do not mark frontmatterEdited', () {
      final controller = container.read(editorControllerProvider.notifier);
      controller.initializeWithPost(buildPost(
        rawFrontmatter: 'title: "Hello World"\ncustom: kept',
      ));

      controller.updateBody('new body');
      controller.updateTitle('Hello World');

      final state = container.read(editorControllerProvider);
      expect(state.frontmatterEdited, isFalse);
    });
  });
}

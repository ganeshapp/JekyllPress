import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/features/config/presentation/config_screen.dart';
import 'package:jekyllpress/features/config/presentation/folder_browser_screen.dart';

void main() {
  group('parseCommaList', () {
    test('splits on commas and trims each value', () {
      expect(parseCommaList('blog, notes ,  jekyll'),
          ['blog', 'notes', 'jekyll']);
    });

    test('drops empty values from stray/trailing commas', () {
      expect(parseCommaList(', blog,, notes ,'), ['blog', 'notes']);
    });

    test('empty and whitespace-only input give an empty list', () {
      expect(parseCommaList(''), isEmpty);
      expect(parseCommaList('   '), isEmpty);
      expect(parseCommaList(' , , '), isEmpty);
    });

    test('single value without commas', () {
      expect(parseCommaList('blog'), ['blog']);
    });
  });

  group('parseOwnerRepo', () {
    test('plain owner/name', () {
      expect(parseOwnerRepo('gapp/blog'), (owner: 'gapp', name: 'blog'));
    });

    test('trims whitespace and stray slashes', () {
      expect(parseOwnerRepo('  /gapp/blog/  '),
          (owner: 'gapp', name: 'blog'));
    });

    test('tolerates a full github.com URL and .git suffix', () {
      expect(parseOwnerRepo('https://github.com/gapp/blog'),
          (owner: 'gapp', name: 'blog'));
      expect(parseOwnerRepo('https://www.github.com/gapp/blog.git'),
          (owner: 'gapp', name: 'blog'));
      expect(parseOwnerRepo('git@github.com:gapp/blog.git'),
          (owner: 'gapp', name: 'blog'));
    });

    test('keeps dots, hyphens, and underscores in names', () {
      expect(parseOwnerRepo('my-org/gapp.github.io'),
          (owner: 'my-org', name: 'gapp.github.io'));
      expect(parseOwnerRepo('a_b/c-d.e'), (owner: 'a_b', name: 'c-d.e'));
    });

    test('rejects input without exactly owner/name', () {
      expect(parseOwnerRepo(''), isNull);
      expect(parseOwnerRepo('blog'), isNull);
      expect(parseOwnerRepo('a/b/c'), isNull);
      expect(parseOwnerRepo('gapp/'), isNull);
      expect(parseOwnerRepo('/blog'), isNull);
    });

    test('rejects invalid characters', () {
      expect(parseOwnerRepo('ga pp/blog'), isNull);
      expect(parseOwnerRepo('gapp/bl?og'), isNull);
    });
  });

  group('joinNewFolderPath', () {
    test('joins a child folder onto the current path', () {
      expect(joinNewFolderPath('docs', '_wiki'), 'docs/_wiki');
    });

    test('root base returns just the cleaned child', () {
      expect(joinNewFolderPath('', '_wiki'), '_wiki');
    });

    test('cleans leading/trailing slashes and inner whitespace', () {
      expect(joinNewFolderPath('', '/docs/notes/'), 'docs/notes');
      expect(joinNewFolderPath('docs', ' notes / 2026 '), 'docs/notes/2026');
    });

    test('allows typing nested paths', () {
      expect(joinNewFolderPath('docs', 'a/b/c'), 'docs/a/b/c');
    });

    test('rejects empty and traversal segments', () {
      expect(joinNewFolderPath('docs', ''), isNull);
      expect(joinNewFolderPath('docs', '   '), isNull);
      expect(joinNewFolderPath('docs', '..'), isNull);
      expect(joinNewFolderPath('docs', 'a/../b'), isNull);
      expect(joinNewFolderPath('docs', '.'), isNull);
      expect(joinNewFolderPath('docs', 'a//b'), isNull);
    });
  });
}

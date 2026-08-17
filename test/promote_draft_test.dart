import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/providers/publish_provider.dart';

void main() {
  final now = DateTime(2026, 8, 17, 9, 5, 3);

  group('promotedFileName', () {
    test('prefixes the draft slug with today\'s date', () {
      expect(promotedFileName('my-idea.md', now), '2026-08-17-my-idea.md');
    });

    test('an existing date prefix is replaced, not doubled', () {
      expect(
        promotedFileName('2024-01-05-my-idea.md', now),
        '2026-08-17-my-idea.md',
      );
    });

    test('.markdown normalizes to .md', () {
      expect(promotedFileName('note.markdown', now), '2026-08-17-note.md');
    });

    test('collection targets keep a plain slug filename', () {
      expect(
        promotedFileName('2024-01-05-my-idea.md', now, datePrefixed: false),
        'my-idea.md',
      );
    });

    test('a filename that is only a date prefix falls back to "post"', () {
      expect(promotedFileName('2024-01-05-.md', now), '2026-08-17-post.md');
    });
  });

  group('promotedFrontmatter', () {
    test('front matter with a date passes through verbatim', () {
      const raw = 'title: "Idea"\ndate: 2024-01-05 10:00:00 +0900\ncustom: x';
      expect(
        promotedFrontmatter(rawFrontmatter: raw, title: 'Idea', now: now),
        '---\n$raw\n---',
      );
    });

    test('a date the parser cannot lift still counts as present', () {
      const raw = 'title: "Idea"\ndate:\n  odd: form';
      expect(
        promotedFrontmatter(rawFrontmatter: raw, title: 'Idea', now: now),
        '---\n$raw\n---',
      );
    });

    test('missing date gets a full timestamp appended, rest verbatim', () {
      const raw = 'title: "Idea"\ncustom: x';
      final result =
          promotedFrontmatter(rawFrontmatter: raw, title: 'Idea', now: now);
      expect(result, startsWith('---\ntitle: "Idea"\ncustom: x\ndate: '));
      expect(result, contains('date: 2026-08-17 09:05:03 '));
      expect(result, endsWith('\n---'));
    });

    test('no front matter at all gets minimal title+date', () {
      final result =
          promotedFrontmatter(rawFrontmatter: '', title: 'My Idea', now: now);
      expect(result, startsWith('---\ntitle: "My Idea"\ndate: 2026-08-17'));
      expect(result, endsWith('---'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/utils/frontmatter_parser.dart';

void main() {
  group('FrontmatterParser.generateFrontmatter', () {
    test('emits minimal front matter (title + date only) by default', () {
      final result = FrontmatterParser.generateFrontmatter(
        title: 'Hello',
        date: '2026-08-17 10:30:05 +0900',
      );
      expect(result, '''---
title: "Hello"
date: 2026-08-17 10:30:05 +0900
---
''');
      expect(result.contains('layout'), isFalse);
      expect(result.contains('categories'), isFalse);
    });

    test('escapes double quotes in title', () {
      final result = FrontmatterParser.generateFrontmatter(
        title: 'My "Best" Post',
        date: '2026-08-17',
      );
      expect(result, contains(r'title: "My \"Best\" Post"'));
    });

    test('escapes backslashes in title', () {
      final result = FrontmatterParser.generateFrontmatter(
        title: r'back\slash',
        date: '2026-08-17',
      );
      expect(result, contains(r'title: "back\\slash"'));
    });

    test('escapes backslash-then-quote correctly', () {
      final result = FrontmatterParser.generateFrontmatter(
        title: r'a\"b',
        date: '2026-08-17',
      );
      expect(result, contains(r'title: "a\\\"b"'));
    });

    test('includes layout when provided', () {
      final result = FrontmatterParser.generateFrontmatter(
        title: 'Hello',
        date: '2026-08-17',
        layout: 'post',
      );
      expect(result, contains('layout: post'));
    });

    test('includes categories when non-empty', () {
      final result = FrontmatterParser.generateFrontmatter(
        title: 'Hello',
        date: '2026-08-17',
        categories: const ['blog', 'dev'],
      );
      expect(result, contains('categories: [blog, dev]'));
    });

    test('includes extra fields when provided', () {
      final result = FrontmatterParser.generateFrontmatter(
        title: 'Hello',
        date: '2026-08-17',
        extraFields: const {'excerpt': 'A summary'},
      );
      expect(result, contains('excerpt: A summary'));
    });
  });

  group('FrontmatterParser.parse', () {
    test('parses simple front matter', () {
      final parsed = FrontmatterParser.parse(
        '---\ntitle: "Hello"\ndate: 2026-08-17\n---\nBody text',
      );
      expect(parsed.title, 'Hello');
      expect(parsed.date, '2026-08-17');
      expect(parsed.bodyContent, 'Body text');
    });

    test('quote escaping round-trips through generate then parse', () {
      const title = 'My "Best" Post with back\\slash';
      final frontmatter = FrontmatterParser.generateFrontmatter(
        title: title,
        date: '2026-08-17',
      );
      final parsed = FrontmatterParser.parse(
        FrontmatterParser.combineContent(frontmatter, 'Body'),
      );
      expect(parsed.title, title);
      expect(parsed.bodyContent, 'Body');
    });

    test('strips UTF-8 BOM before matching front matter', () {
      final parsed = FrontmatterParser.parse(
        '\uFEFF---\ntitle: "Hi"\n---\nBody',
      );
      expect(parsed.title, 'Hi');
      expect(parsed.bodyContent, 'Body');
    });

    test('non-anchored --- pair in body is NOT treated as front matter', () {
      const content = 'Intro paragraph.\n\n---\ntitle: fake\n---\nMore text';
      final parsed = FrontmatterParser.parse(content);
      expect(parsed.rawFrontmatter, '');
      expect(parsed.bodyContent, contains('Intro paragraph.'));
      expect(parsed.bodyContent, contains('More text'));
      expect(parsed.title, isNot('fake'));
    });

    test('horizontal rules in body survive when front matter exists', () {
      const content =
          '---\ntitle: "Real"\n---\nFirst section\n\n---\n\nSecond section';
      final parsed = FrontmatterParser.parse(content);
      expect(parsed.title, 'Real');
      expect(parsed.bodyContent, contains('First section'));
      expect(parsed.bodyContent, contains('Second section'));
    });

    test('value that is a single quote character does not crash', () {
      final parsed = FrontmatterParser.parse(
        '---\ntitle: "\ndate: 2026-08-17\n---\nBody',
      );
      expect(parsed.date, '2026-08-17');
      expect(parsed.bodyContent, 'Body');
    });

    test("value that is a single apostrophe does not crash", () {
      final parsed = FrontmatterParser.parse(
        "---\ntitle: '\n---\nBody",
      );
      expect(parsed.bodyContent, 'Body');
    });

    test('malformed YAML lines are skipped, valid ones kept', () {
      final parsed = FrontmatterParser.parse(
        '---\n:::: garbage\ntitle: "Kept"\n- just a dash\n---\nBody',
      );
      expect(parsed.title, 'Kept');
      expect(parsed.bodyContent, 'Body');
    });

    test('date normalization: full Jekyll timestamp reduces to date', () {
      final parsed = FrontmatterParser.parse(
        '---\ntitle: "T"\ndate: 2024-01-15 10:30:00 +0000\n---\nBody',
      );
      expect(parsed.date, '2024-01-15');
    });

    test('date normalization: ISO T-separated timestamp reduces to date', () {
      final parsed = FrontmatterParser.parse(
        '---\ntitle: "T"\ndate: 2024-01-15T10:30:00Z\n---\nBody',
      );
      expect(parsed.date, '2024-01-15');
    });

    test('single-quoted values have quotes stripped', () {
      final parsed = FrontmatterParser.parse(
        "---\ntitle: 'Single Quoted'\n---\nBody",
      );
      expect(parsed.title, 'Single Quoted');
    });

    test('no front matter: whole content is body, title from heading', () {
      final parsed = FrontmatterParser.parse('# My Heading\n\nSome text');
      expect(parsed.title, 'My Heading');
      expect(parsed.rawFrontmatter, '');
      expect(parsed.bodyContent, contains('Some text'));
    });

    test('no front matter and no heading: Untitled', () {
      final parsed = FrontmatterParser.parse('Just some text');
      expect(parsed.title, 'Untitled');
      expect(parsed.bodyContent, 'Just some text');
    });

    test('front matter closing delimiter at end of file (no newline)', () {
      final parsed = FrontmatterParser.parse('---\ntitle: "End"\n---');
      expect(parsed.title, 'End');
      expect(parsed.bodyContent, '');
    });

    test('CRLF line endings are handled', () {
      final parsed = FrontmatterParser.parse(
        '---\r\ntitle: "CRLF"\r\n---\r\nBody',
      );
      expect(parsed.title, 'CRLF');
      expect(parsed.bodyContent, 'Body');
    });
  });
}

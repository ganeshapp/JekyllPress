import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/services/publish_service.dart';

void main() {
  group('PublishService.toKebabCase', () {
    test('simple title', () {
      expect(PublishService.toKebabCase('Hello World'), 'hello-world');
    });

    test('punctuation is collapsed into single hyphens', () {
      expect(PublishService.toKebabCase('Hello, World!'), 'hello-world');
      expect(
        PublishService.toKebabCase('Foo: Bar (Baz) -- Qux?!'),
        'foo-bar-baz-qux',
      );
    });

    test('straight apostrophes are removed entirely', () {
      expect(
        PublishService.toKebabCase("What's New in Flutter?"),
        'whats-new-in-flutter',
      );
    });

    test('curly apostrophes are removed entirely', () {
      expect(
        PublishService.toKebabCase('It’s a Test'),
        'its-a-test',
      );
      expect(
        PublishService.toKebabCase('‘Quoted’ Title'),
        'quoted-title',
      );
    });

    test('Korean characters are preserved', () {
      expect(
        PublishService.toKebabCase('안녕하세요 새 글입니다'),
        '안녕하세요-새-글입니다',
      );
    });

    test('accented characters are preserved', () {
      expect(PublishService.toKebabCase('Café Notes'), 'café-notes');
    });

    test('emoji is stripped without crashing', () {
      expect(PublishService.toKebabCase('My Post 🎉'), 'my-post');
      expect(PublishService.toKebabCase('🎉 Party 🎉 Time 🎉'), 'party-time');
    });

    test('double spaces collapse to one hyphen', () {
      expect(
        PublishService.toKebabCase('Hello  Double  Space'),
        'hello-double-space',
      );
    });

    test('trailing and leading spaces are trimmed', () {
      expect(PublishService.toKebabCase('Trailing space '), 'trailing-space');
      expect(PublishService.toKebabCase(' Leading space'), 'leading-space');
    });

    test('underscores become hyphens', () {
      expect(
        PublishService.toKebabCase('snake_case_title'),
        'snake-case-title',
      );
    });

    test('mixed punctuation-heavy title does not throw RangeError', () {
      expect(
        PublishService.toKebabCase('Hello!!! World!!!'),
        'hello-world',
      );
    });

    test('over 50 chars cuts back to last hyphen when > 20 chars remain', () {
      final title =
          'aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee'; // 54-char slug
      expect(
        PublishService.toKebabCase(title),
        'aaaaaaaaaa-bbbbbbbbbb-cccccccccc-dddddddddd',
      );
    });

    test('over 50 chars keeps hard cut when last hyphen is at <= 20', () {
      final title = 'abcdefghijklmnop ${'q' * 40}';
      final result = PublishService.toKebabCase(title);
      expect(result, 'abcdefghijklmnop-${'q' * 33}');
      expect(result.length, 50);
    });

    test('over 50 chars with no hyphens keeps 50 chars', () {
      expect(PublishService.toKebabCase('a' * 60), 'a' * 50);
    });

    test('exactly 50 chars is untouched', () {
      final slug = 'a' * 50;
      expect(PublishService.toKebabCase(slug), slug);
    });

    test('no trailing hyphen after truncation', () {
      final result = PublishService.toKebabCase(
        'word word word word word word word word word word word',
      );
      expect(result.length, lessThanOrEqualTo(50));
      expect(result.endsWith('-'), isFalse);
    });

    test('punctuation-only title falls back to post-HHmmss', () {
      final now = DateTime(2026, 8, 17, 9, 5, 3);
      expect(PublishService.toKebabCase('!!!???...', now: now), 'post-090503');
    });

    test('empty and whitespace-only titles fall back to post-HHmmss', () {
      final now = DateTime(2026, 8, 17, 23, 59, 59);
      expect(PublishService.toKebabCase('', now: now), 'post-235959');
      expect(PublishService.toKebabCase('   ', now: now), 'post-235959');
    });

    test('fallback without injected time matches post-\\d{6}', () {
      expect(
        PublishService.toKebabCase('!!!'),
        matches(RegExp(r'^post-\d{6}$')),
      );
    });
  });

  group('PublishService.formatJekyllDate', () {
    test('UTC time formats with +0000 offset', () {
      final utc = DateTime.utc(2026, 1, 2, 3, 4, 5);
      expect(PublishService.formatJekyllDate(utc), '2026-01-02 03:04:05 +0000');
    });

    test('local time matches YYYY-MM-DD HH:MM:SS +HHMM shape', () {
      final dt = DateTime(2026, 8, 17, 10, 30, 5);
      final result = PublishService.formatJekyllDate(dt);
      expect(
        result,
        matches(RegExp(r'^2026-08-17 10:30:05 [+-]\d{4}$')),
      );
    });

    test('offset digits match the device offset', () {
      final dt = DateTime(2026, 8, 17, 10, 30, 5);
      final offset = dt.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final abs = offset.abs();
      final expected =
          '$sign${abs.inHours.toString().padLeft(2, '0')}${(abs.inMinutes % 60).toString().padLeft(2, '0')}';
      expect(PublishService.formatJekyllDate(dt).split(' ').last, expected);
    });

    test('single-digit components are zero padded', () {
      final utc = DateTime.utc(2026, 3, 4, 5, 6, 7);
      expect(PublishService.formatJekyllDate(utc), '2026-03-04 05:06:07 +0000');
    });
  });
}

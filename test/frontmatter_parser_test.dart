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

  group('FrontmatterParser.parseFields', () {
    test('empty raw front matter yields empty fields', () {
      final fm = FrontmatterParser.parseFields('');
      expect(fm.title, isNull);
      expect(fm.date, isNull);
      expect(fm.layout, isNull);
      expect(fm.categories, isEmpty);
      expect(fm.tags, isEmpty);
      expect(fm.passthrough, isEmpty);
    });

    test('modeled keys are lifted; date stays raw', () {
      final fm = FrontmatterParser.parseFields(
        'title: "Hello"\n'
        'date: 2024-01-15 10:30:00 +0900\n'
        'layout: single\n',
      );
      expect(fm.title, 'Hello');
      expect(fm.date, '2024-01-15 10:30:00 +0900');
      expect(fm.layout, 'single');
      expect(fm.passthrough, isEmpty);
    });

    test('flow list form: categories: [a, b]', () {
      final fm = FrontmatterParser.parseFields('categories: [blog, dev]');
      expect(fm.categories, ['blog', 'dev']);
    });

    test('flow list with quoted item containing a comma', () {
      final fm = FrontmatterParser.parseFields('tags: [a, "b, c", \'d\']');
      expect(fm.tags, ['a', 'b, c', 'd']);
    });

    test('empty flow list and bare key both mean empty list', () {
      expect(FrontmatterParser.parseFields('tags: []').tags, isEmpty);
      expect(FrontmatterParser.parseFields('tags:').tags, isEmpty);
    });

    test('block list form with indentation', () {
      final fm = FrontmatterParser.parseFields(
        'categories:\n  - blog\n  - dev\n',
      );
      expect(fm.categories, ['blog', 'dev']);
      expect(fm.passthrough, isEmpty);
    });

    test('block list form at zero indent (YAML-legal)', () {
      final fm = FrontmatterParser.parseFields(
        'tags:\n- alpha\n- beta\n',
      );
      expect(fm.tags, ['alpha', 'beta']);
    });

    test('single scalar form becomes a one-item list', () {
      final fm = FrontmatterParser.parseFields('categories: blog');
      expect(fm.categories, ['blog']);
    });

    test('unknown keys pass through byte-exact', () {
      const raw = 'excerpt: "A summary"\ncustom_key:   spaced   value';
      final fm = FrontmatterParser.parseFields(raw);
      expect(fm.passthrough['excerpt'], 'excerpt: "A summary"');
      expect(
          fm.passthrough['custom_key'], 'custom_key:   spaced   value');
    });

    test('multiline unknown block (header image) is one verbatim entry',
        () {
      const raw = 'title: "T"\n'
          'header:\n'
          '  image: /assets/hero.jpg\n'
          '  caption: "My caption"\n'
          'layout: post';
      final fm = FrontmatterParser.parseFields(raw);
      expect(fm.title, 'T');
      expect(fm.layout, 'post');
      expect(
        fm.passthrough['header'],
        'header:\n  image: /assets/hero.jpg\n  caption: "My caption"',
      );
    });

    test('multiline literal block with internal blank line stays intact',
        () {
      const raw = 'description: |\n'
          '  first paragraph\n'
          '\n'
          '  second paragraph\n'
          'layout: post';
      final fm = FrontmatterParser.parseFields(raw);
      expect(fm.layout, 'post');
      expect(
        fm.passthrough['description'],
        'description: |\n  first paragraph\n\n  second paragraph',
      );
    });

    test('comments and blank lines are preserved in order', () {
      const raw = '# leading comment\n'
          'title: "T"\n'
          '\n'
          'seo: value';
      final fm = FrontmatterParser.parseFields(raw);
      expect(fm.title, 'T');
      expect(fm.passthrough.values.toList(), [
        '# leading comment',
        '',
        'seo: value',
      ]);
    });

    test('modeled key in a form the model cannot handle passes through',
        () {
      const raw = 'title: >\n  folded\n  title\ndate: 2024-01-01';
      final fm = FrontmatterParser.parseFields(raw);
      expect(fm.title, isNull);
      expect(fm.date, '2024-01-01');
      expect(fm.passthrough['title'], 'title: >\n  folded\n  title');
    });

    test('unbalanced flow list passes through instead of mis-parsing', () {
      const raw = 'tags: [a, "b\nlayout: post';
      final fm = FrontmatterParser.parseFields(raw);
      expect(fm.tags, isEmpty);
      expect(fm.passthrough['tags'], 'tags: [a, "b');
      expect(fm.layout, 'post');
    });

    test('duplicate unknown keys both survive', () {
      const raw = 'foo: one\nfoo: two';
      final fm = FrontmatterParser.parseFields(raw);
      expect(fm.passthrough.values.toList(), ['foo: one', 'foo: two']);
    });

    test('quoted scalar values are unquoted', () {
      final fm = FrontmatterParser.parseFields(
        "layout: 'single'\ntags: ['a', \"b\"]",
      );
      expect(fm.layout, 'single');
      expect(fm.tags, ['a', 'b']);
    });
  });

  group('FrontmatterParser.parseDateValue', () {
    test('Jekyll timestamp with space before offset parses', () {
      final dt = FrontmatterParser.parseDateValue('2024-01-15 10:30:00 +0000');
      expect(dt, isNotNull);
      expect(dt!.toUtc(), DateTime.utc(2024, 1, 15, 10, 30));
    });

    test('plain date parses', () {
      final dt = FrontmatterParser.parseDateValue('2024-01-15');
      expect(dt, DateTime(2024, 1, 15));
    });

    test('null, empty, and garbage return null', () {
      expect(FrontmatterParser.parseDateValue(null), isNull);
      expect(FrontmatterParser.parseDateValue(''), isNull);
      expect(FrontmatterParser.parseDateValue('not a date'), isNull);
    });
  });

  group('FrontmatterParser.generateFrontmatterFields', () {
    test('emits title, date, layout, categories, tags in order', () {
      final result = FrontmatterParser.generateFrontmatterFields(
        title: 'Hello',
        date: '2026-08-17 10:30:05 +0900',
        layout: 'single',
        categories: const ['blog'],
        tags: const ['dev', 'notes'],
      );
      expect(result, '''---
title: "Hello"
date: 2026-08-17 10:30:05 +0900
layout: single
categories: [blog]
tags: [dev, notes]
---
''');
    });

    test('null title/date and empty layout/lists are omitted', () {
      final result = FrontmatterParser.generateFrontmatterFields(
        title: 'T',
        date: '2026-08-17',
        layout: '',
      );
      expect(result, isNot(contains('layout:')));
      expect(result, isNot(contains('categories:')));
      expect(result, isNot(contains('tags:')));

      final noTitle = FrontmatterParser.generateFrontmatterFields(
        date: '2026-08-17',
      );
      expect(noTitle, isNot(contains('title:')));
    });

    test('passthrough blocks are emitted verbatim after modeled keys', () {
      final result = FrontmatterParser.generateFrontmatterFields(
        title: 'T',
        date: '2026-08-17',
        passthrough: const {
          'header': 'header:\n  image: /assets/hero.jpg',
          '#raw-0': '# a comment',
        },
      );
      expect(
        result,
        contains('header:\n  image: /assets/hero.jpg\n# a comment\n---'),
      );
    });

    test('list items with special characters are quoted', () {
      final result = FrontmatterParser.generateFrontmatterFields(
        title: 'T',
        date: '2026-08-17',
        tags: const ['plain', 'has, comma', 'has: colon'],
      );
      expect(result, contains('tags: [plain, "has, comma", "has: colon"]'));
    });
  });

  group('parseFields <-> generateFrontmatterFields round-trip', () {
    // Realistic front matter mixing every supported form plus custom
    // fields the model must never destroy
    const original = '---\n'
        'title: "My \\"Best\\" Post"\n'
        'date: 2024-01-15 10:30:00 +0900\n'
        'layout: single\n'
        'categories:\n'
        '  - blog\n'
        '  - dev\n'
        'tags: [a, "b, c"]\n'
        '# keep me\n'
        'header:\n'
        '  overlay_image: /assets/hero.jpg\n'
        '  overlay_filter: 0.5\n'
        'toc: true\n'
        '---\n'
        'Body text\n';

    test('parse -> edit nothing -> regenerate is semantically identical '
        'and passthrough is byte-exact', () {
      final parsed = FrontmatterParser.parse(original);
      final fm = FrontmatterParser.parseFields(parsed.rawFrontmatter);

      final regenerated = FrontmatterParser.generateFrontmatterFields(
        title: fm.title,
        date: fm.date,
        layout: fm.layout,
        categories: fm.categories,
        tags: fm.tags,
        passthrough: fm.passthrough,
      );

      // Passthrough blocks appear byte-exact in the output
      expect(regenerated, contains('# keep me'));
      expect(
        regenerated,
        contains(
          'header:\n  overlay_image: /assets/hero.jpg\n'
          '  overlay_filter: 0.5',
        ),
      );
      expect(regenerated, contains('toc: true'));

      // Re-parsing the regenerated front matter yields the same model
      final reparsed = FrontmatterParser.parseFields(
        FrontmatterParser.parse('${regenerated}Body').rawFrontmatter,
      );
      expect(reparsed.title, fm.title);
      expect(reparsed.date, fm.date);
      expect(reparsed.layout, fm.layout);
      expect(reparsed.categories, fm.categories);
      expect(reparsed.tags, fm.tags);
      expect(reparsed.passthrough.values.toList(),
          fm.passthrough.values.toList());
    });

    test('regenerate -> parse -> regenerate is byte-stable (fixpoint)', () {
      final fm = FrontmatterParser.parseFields(
        FrontmatterParser.parse(original).rawFrontmatter,
      );
      final once = FrontmatterParser.generateFrontmatterFields(
        title: fm.title,
        date: fm.date,
        layout: fm.layout,
        categories: fm.categories,
        tags: fm.tags,
        passthrough: fm.passthrough,
      );
      final fm2 = FrontmatterParser.parseFields(
        FrontmatterParser.parse('${once}Body').rawFrontmatter,
      );
      final twice = FrontmatterParser.generateFrontmatterFields(
        title: fm2.title,
        date: fm2.date,
        layout: fm2.layout,
        categories: fm2.categories,
        tags: fm2.tags,
        passthrough: fm2.passthrough,
      );
      expect(twice, once);
    });
  });
}

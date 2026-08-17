import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/utils/permalink.dart';

void main() {
  final date = DateTime(2024, 1, 5, 10, 30);

  group('postSlugFromFileName', () {
    test('strips the date prefix and markdown extension', () {
      expect(postSlugFromFileName('2024-01-05-my-post.md'), 'my-post');
      expect(postSlugFromFileName('2024-1-5-short.markdown'), 'short');
    });

    test('plain draft filenames only lose the extension', () {
      expect(postSlugFromFileName('idea-dump.md'), 'idea-dump');
    });

    test('unicode slugs survive', () {
      expect(postSlugFromFileName('2024-01-05-한글-포스트.md'), '한글-포스트');
    });

    test('nested paths use the basename', () {
      expect(postSlugFromFileName('_posts/2024/2024-01-05-deep.md'), 'deep');
    });
  });

  group('buildPostUrl', () {
    test("the owner's real pattern /blog/:title/", () {
      final url = buildPostUrl(
        siteUrl: 'https://gapp.github.io',
        permalinkPattern: '/blog/:title/',
        fileName: '2024-01-05-my-post.md',
        date: date,
      );
      expect(url, 'https://gapp.github.io/blog/my-post/');
    });

    test("empty pattern falls back to Jekyll's default date style", () {
      final url = buildPostUrl(
        siteUrl: 'https://gapp.github.io',
        permalinkPattern: '',
        fileName: '2024-01-05-my-post.md',
        date: date,
        categories: ['blog'],
      );
      expect(url, 'https://gapp.github.io/blog/2024/01/05/my-post.html');
    });

    test('default date style without categories collapses the slot', () {
      final url = buildPostUrl(
        siteUrl: 'https://gapp.github.io',
        fileName: '2024-01-05-my-post.md',
        date: date,
      );
      expect(url, 'https://gapp.github.io/2024/01/05/my-post.html');
    });

    test('built-in styles: pretty, ordinal, none', () {
      String? style(String s) => buildPostUrl(
            siteUrl: 'https://x.io',
            permalinkPattern: s,
            fileName: '2024-01-05-p.md',
            date: date,
            categories: ['a', 'b'],
          );
      expect(style('pretty'), 'https://x.io/a/b/2024/01/05/p/');
      expect(style('ordinal'), 'https://x.io/a/b/2024/005/p.html');
      expect(style('none'), 'https://x.io/a/b/p.html');
    });

    test('ordinal :y_day counts calendar days (DST-safe), incl. leap years',
        () {
      String? yDay(DateTime d) => buildPostUrl(
            siteUrl: 'https://x.io',
            permalinkPattern: '/:y_day/',
            fileName: 'p.md',
            date: d,
          );
      expect(yDay(DateTime(2026, 1, 1)), 'https://x.io/001/');
      // Late in the year, PAST any DST switch: a local-time difference
      // would come up an hour (= a day, truncated) short
      expect(yDay(DateTime(2026, 12, 31)), 'https://x.io/365/');
      expect(yDay(DateTime(2024, 12, 31)), 'https://x.io/366/'); // leap
    });

    test('categories are slugified for the URL', () {
      final url = buildPostUrl(
        siteUrl: 'https://x.io',
        permalinkPattern: '/:categories/:title/',
        fileName: 'p.md',
        date: date,
        categories: ['Dev Notes'],
      );
      expect(url, 'https://x.io/dev-notes/p/');
    });

    test('extra tokens: :i_month, :i_day, :short_year', () {
      final url = buildPostUrl(
        siteUrl: 'https://x.io',
        permalinkPattern: '/:short_year/:i_month/:i_day/:title',
        fileName: '2024-01-05-p.md',
        date: date,
      );
      expect(url, 'https://x.io/24/1/5/p');
    });

    test('baseurl is appended when the site URL does not carry it', () {
      final url = buildPostUrl(
        siteUrl: 'https://gapp.in',
        baseurl: '/blog',
        permalinkPattern: '/:title/',
        fileName: 'p.md',
        date: date,
      );
      expect(url, 'https://gapp.in/blog/p/');
    });

    test('baseurl is NOT doubled when the inferred site URL already '
        'ends with it (project pages)', () {
      final url = buildPostUrl(
        siteUrl: 'https://gapp.github.io/blog',
        baseurl: '/blog',
        permalinkPattern: '/:title/',
        fileName: 'p.md',
        date: date,
      );
      expect(url, 'https://gapp.github.io/blog/p/');
    });

    test('trailing slash on the site URL is normalized', () {
      final url = buildPostUrl(
        siteUrl: 'https://x.io/',
        permalinkPattern: '/:title/',
        fileName: 'p.md',
        date: date,
      );
      expect(url, 'https://x.io/p/');
    });

    test('empty site URL yields null (nothing to link to)', () {
      expect(
        buildPostUrl(siteUrl: '', fileName: 'p.md', date: date),
        isNull,
      );
    });
  });
}

/// Pure helpers for building a published post's public URL from the site
/// config and the post's filename/front matter, expanding Jekyll
/// permalink patterns.
library;

/// Jekyll's built-in permalink styles (weekdate is intentionally not
/// supported - it needs strftime week bookkeeping nothing here uses)
const _builtInStyles = <String, String>{
  'date': '/:categories/:year/:month/:day/:title.html',
  'pretty': '/:categories/:year/:month/:day/:title/',
  'ordinal': '/:categories/:year/:y_day/:title.html',
  'none': '/:categories/:title.html',
};

/// Tokens supported in a permalink pattern. Longer names are matched
/// first so ':year' never eats the tail of ':short_year'.
final _tokenRegex = RegExp(
  r':(categories|short_year|i_month|i_day|y_day|year|month|day|title|slug|name)',
);

/// Slug of a post file: the basename minus any 'YYYY-MM-DD-' date prefix
/// and the markdown extension (Jekyll's :title/:slug/:name value)
String postSlugFromFileName(String fileName) {
  var slug = fileName.split('/').last;
  slug = slug.replaceFirst(
      RegExp(r'\.(md|markdown)$', caseSensitive: false), '');
  slug = slug.replaceFirst(RegExp(r'^\d{4}-\d{1,2}-\d{1,2}-'), '');
  return slug;
}

/// Build the public URL of a post.
///
/// [permalinkPattern] may be a built-in style name ('date', 'pretty',
/// 'ordinal', 'none') or a token pattern like '/blog/:title/'; ''
/// falls back to Jekyll's DEFAULT 'date' style
/// (/:categories/:year/:month/:day/:title.html). [baseurl] is appended
/// to [siteUrl] unless the configured site URL already carries it (the
/// GitHub Pages inference stores project sites as
/// 'https://owner.github.io/repo' AND baseurl '/repo').
///
/// Returns null when [siteUrl] is empty - there is no site to link to.
String? buildPostUrl({
  required String siteUrl,
  String baseurl = '',
  String permalinkPattern = '',
  required String fileName,
  required DateTime date,
  List<String> categories = const [],
}) {
  final site = siteUrl.trim().replaceAll(RegExp(r'/+$'), '');
  if (site.isEmpty) return null;

  final style = permalinkPattern.trim();
  final pattern = style.isEmpty
      ? _builtInStyles['date']!
      : (_builtInStyles[style] ?? style);

  String two(int n) => n.toString().padLeft(2, '0');
  // Computed on UTC dates so a DST shift earlier in the year can't make
  // the local-time difference come up a day short
  final yearDay = DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(date.year))
          .inDays +
      1;
  final slug = postSlugFromFileName(fileName);
  final categoriesPath =
      categories.map(slugifyPathSegment).where((c) => c.isNotEmpty).join('/');

  var path = pattern.replaceAllMapped(_tokenRegex, (m) {
    return switch (m.group(1)!) {
      'categories' => categoriesPath,
      'year' => '${date.year}',
      'short_year' => two(date.year % 100),
      'month' => two(date.month),
      'i_month' => '${date.month}',
      'day' => two(date.day),
      'i_day' => '${date.day}',
      'y_day' => yearDay.toString().padLeft(3, '0'),
      'title' || 'slug' || 'name' => slug,
      _ => m.group(0)!,
    };
  });

  // Empty tokens (no categories) leave double slashes - collapse them
  path = path.replaceAll(RegExp(r'/{2,}'), '/');
  if (!path.startsWith('/')) path = '/$path';

  final prefix = _normalizeBaseurl(baseurl);
  final root = (prefix.isNotEmpty &&
          site.toLowerCase().endsWith(prefix.toLowerCase()))
      ? site
      : '$site$prefix';
  return '$root$path';
}

/// Jekyll's default slugify for a URL path segment: lowercase, runs of
/// spaces/unsafe punctuation become one hyphen (unicode letters kept)
String slugifyPathSegment(String segment) {
  return segment
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^\p{L}\p{N}._~]+', unicode: true), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Normalize a baseurl to '' or '/segment[/…]' (leading slash, no
/// trailing slash) - kept local so this util stays pure Dart
String _normalizeBaseurl(String baseurl) {
  var cleaned = baseurl.trim().replaceAll(RegExp(r'/+$'), '');
  if (cleaned.isEmpty || cleaned == '/') return '';
  if (!cleaned.startsWith('/')) cleaned = '/$cleaned';
  return cleaned;
}

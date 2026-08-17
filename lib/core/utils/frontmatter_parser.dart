/// Result of parsing a Jekyll markdown file
class ParsedPost {
  final String title;
  final String date;
  final String rawFrontmatter;
  final String bodyContent;
  final Map<String, String> extraFields;

  const ParsedPost({
    required this.title,
    required this.date,
    required this.rawFrontmatter,
    required this.bodyContent,
    this.extraFields = const {},
  });
}

/// Parser for Jekyll frontmatter in markdown files
class FrontmatterParser {
  // Regex to match YAML frontmatter block.
  // NOT multiLine, so ^ anchors to the start of the string: content that
  // merely contains '---' lines later (e.g. horizontal rules) is body, not
  // front matter.
  static final _frontmatterRegex = RegExp(
    r'^---[^\S\n]*\n([\s\S]*?)\n---[^\S\n]*(\n|$)',
  );

  // Regex to extract key-value pairs from YAML
  static final _yamlFieldRegex = RegExp(
    r'^(\w+):\s*(.*)$',
    multiLine: true,
  );

  /// Parse a Jekyll markdown file content
  /// Extracts frontmatter and body content
  static ParsedPost parse(String content) {
    // Strip UTF-8 BOM if present so front matter at the file start is found
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    final match = _frontmatterRegex.firstMatch(content);

    if (match == null) {
      // No frontmatter found, treat entire content as body
      final body = content.trim();
      final headingMatch =
          RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(body);
      return ParsedPost(
        title: headingMatch?.group(1)?.trim() ?? 'Untitled',
        date: DateTime.now().toIso8601String().split('T').first,
        rawFrontmatter: '',
        bodyContent: body,
      );
    }

    final rawFrontmatter = match.group(1) ?? '';
    final bodyContent = content.substring(match.end).trim();

    // Parse YAML fields (never throw on malformed lines - skip them)
    final fields = <String, String>{};
    for (final fieldMatch in _yamlFieldRegex.allMatches(rawFrontmatter)) {
      try {
        final key = fieldMatch.group(1)?.toLowerCase() ?? '';
        var value = fieldMatch.group(2)?.trim() ?? '';

        // Remove surrounding quotes if present (length check guards against
        // a value that is a single quote character)
        if (value.length >= 2 &&
            value.startsWith('"') &&
            value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
          // Unescape backslash escapes inside double-quoted scalars
          value = value.replaceAllMapped(
            RegExp(r'\\(.)'),
            (m) => m.group(1)!,
          );
        } else if (value.length >= 2 &&
            value.startsWith("'") &&
            value.endsWith("'")) {
          value = value.substring(1, value.length - 1);
        }

        fields[key] = value;
      } catch (_) {
        // Skip malformed lines rather than failing the whole parse
        continue;
      }
    }

    // Extract title - try multiple common field names
    String title = fields['title'] ?? '';
    if (title.isEmpty) {
      // Try to extract from first heading in body
      final headingMatch = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(bodyContent);
      title = headingMatch?.group(1)?.trim() ?? 'Untitled';
    }

    // Extract date - try multiple common field names
    String date = fields['date'] ?? '';
    if (date.isEmpty) {
      date = fields['published'] ?? fields['created'] ?? '';
    }
    if (date.isEmpty) {
      date = DateTime.now().toIso8601String().split('T').first;
    } else {
      // Normalize date format (handle "2024-01-15 10:30:00 +0000" -> "2024-01-15")
      date = date.split(' ').first.split('T').first;
    }

    return ParsedPost(
      title: title,
      date: date,
      rawFrontmatter: rawFrontmatter,
      bodyContent: bodyContent,
      extraFields: fields,
    );
  }

  /// Generate frontmatter YAML from fields.
  /// Emits minimal front matter by default: only title + date.
  /// [layout] is omitted when null; [categories] is omitted when empty
  /// (kept as optional params for a future front-matter template feature).
  static String generateFrontmatter({
    required String title,
    required String date,
    String? layout,
    List<String> categories = const [],
    Map<String, String>? extraFields,
  }) {
    // Double-quoted YAML scalar: escape backslashes first, then quotes
    final escapedTitle =
        title.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('title: "$escapedTitle"');
    buffer.writeln('date: $date');
    if (layout != null) {
      buffer.writeln('layout: $layout');
    }
    if (categories.isNotEmpty) {
      buffer.writeln('categories: [${categories.join(', ')}]');
    }
    if (extraFields != null) {
      for (final entry in extraFields.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
    }
    buffer.writeln('---');
    return buffer.toString();
  }

  /// Combine frontmatter and body into full file content
  static String combineContent(String frontmatter, String body) {
    return '$frontmatter\n$body';
  }
}

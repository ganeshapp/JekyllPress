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
  // Regex to match YAML frontmatter block
  static final _frontmatterRegex = RegExp(
    r'^---\s*\n([\s\S]*?)\n---\s*\n?',
    multiLine: true,
  );

  // Regex to extract key-value pairs from YAML
  static final _yamlFieldRegex = RegExp(
    r'^(\w+):\s*(.*)$',
    multiLine: true,
  );

  /// Parse a Jekyll markdown file content
  /// Extracts frontmatter and body content
  static ParsedPost parse(String content) {
    final match = _frontmatterRegex.firstMatch(content);
    
    if (match == null) {
      // No frontmatter found, treat entire content as body
      return ParsedPost(
        title: 'Untitled',
        date: DateTime.now().toIso8601String().split('T').first,
        rawFrontmatter: '',
        bodyContent: content.trim(),
      );
    }

    final rawFrontmatter = match.group(1) ?? '';
    final bodyContent = content.substring(match.end).trim();
    
    // Parse YAML fields
    final fields = <String, String>{};
    for (final fieldMatch in _yamlFieldRegex.allMatches(rawFrontmatter)) {
      final key = fieldMatch.group(1)?.toLowerCase() ?? '';
      var value = fieldMatch.group(2)?.trim() ?? '';
      
      // Remove surrounding quotes if present
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      
      fields[key] = value;
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

  /// Generate frontmatter YAML from fields
  static String generateFrontmatter({
    required String title,
    required String date,
    String layout = 'single',
    List<String> categories = const ['blog'],
    Map<String, String>? extraFields,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('title: "$title"');
    buffer.writeln('date: $date');
    buffer.writeln('layout: $layout');
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

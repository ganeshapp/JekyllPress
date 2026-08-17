/// Structured front matter: the keys the app models (title, date, layout,
/// categories, tags) plus [passthrough] - every entry the model does NOT
/// understand, preserved VERBATIM (raw lines, order kept) so custom front
/// matter like header images or SEO blocks is never destroyed.
class PostFrontmatter {
  /// Title value, or null when the front matter has no simple title key
  final String? title;

  /// Raw date value string (e.g. '2024-01-15 10:30:00 +0900'), or null
  /// when the front matter has no simple date key. Kept raw so an
  /// untouched date round-trips without reformatting.
  final String? date;

  /// Layout value, or null when absent
  final String? layout;

  final List<String> categories;
  final List<String> tags;

  /// Unmodeled entries in original order. Key: the YAML key (or a
  /// synthetic '#raw-N' key for comments/blank/garbage lines). Value: the
  /// entry's raw line(s) verbatim, multiline blocks joined with '\n'.
  final Map<String, String> passthrough;

  const PostFrontmatter({
    this.title,
    this.date,
    this.layout,
    this.categories = const [],
    this.tags = const [],
    this.passthrough = const {},
  });

  /// [date] parsed to a local DateTime, or null when absent/unparseable.
  /// Handles Jekyll's 'YYYY-MM-DD HH:MM:SS +HHMM' (space before offset,
  /// which DateTime.parse rejects) and plain 'YYYY-MM-DD'.
  DateTime? get dateTime => FrontmatterParser.parseDateValue(date);
}

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

  // Top-level YAML mapping entry at column 0: 'key:' or 'key: value'.
  // Keys may contain letters/digits/_/-/. but must not start with '-'
  // (so block-list items like '- image_path: x' are not keys).
  static final _topLevelEntryRegex = RegExp(
    r'^([A-Za-z0-9_][A-Za-z0-9_\-.]*)[^\S\n]*:(.*)$',
  );

  // Block-sequence item: '- value' (any indent, including column 0)
  static final _listItemRegex = RegExp(r'^[^\S\n]*-([^\S\n]+.*|)$');

  /// Strip surrounding quotes from a YAML scalar (double-quoted scalars
  /// also get backslash escapes undone)
  static String _unquote(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value
          .substring(1, value.length - 1)
          .replaceAllMapped(RegExp(r'\\(.)'), (m) => m.group(1)!);
    }
    if (value.length >= 2 && value.startsWith("'") && value.endsWith("'")) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  /// Split a flow list body 'a, "b, c", d' on commas outside quotes.
  /// Returns null when the quoting is unbalanced (caller should treat the
  /// entry as opaque rather than mis-parse it).
  static List<String>? _splitFlowList(String body) {
    final items = <String>[];
    final current = StringBuffer();
    String? quote;
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (quote != null) {
        if (ch == r'\' && quote == '"' && i + 1 < body.length) {
          current.write(ch);
          current.write(body[++i]);
          continue;
        }
        if (ch == quote) quote = null;
        current.write(ch);
      } else if (ch == '"' || ch == "'") {
        quote = ch;
        current.write(ch);
      } else if (ch == ',') {
        items.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    if (quote != null) return null; // unbalanced quotes
    items.add(current.toString());
    return items
        .map((s) => _unquote(s.trim()))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Parse a raw front matter block (the inner text between the '---'
  /// delimiters, i.e. [ParsedPost.rawFrontmatter]) into structured fields.
  ///
  /// Only simple forms of the modeled keys (title/date/layout/categories/
  /// tags) are lifted into fields; categories/tags support flow lists
  /// ('[a, b]'), block lists ('- a' at any indent), and single scalars.
  /// EVERYTHING else - unknown keys, multiline blocks, comments, blank
  /// lines, even modeled keys in forms the model doesn't understand - is
  /// kept verbatim in [PostFrontmatter.passthrough], order preserved.
  static PostFrontmatter parseFields(String rawFrontmatter) {
    String? title;
    String? date;
    String? layout;
    List<String>? categories;
    List<String>? tags;
    final passthrough = <String, String>{};
    var syntheticCount = 0;

    void addPassthrough(String key, String block) {
      // Never overwrite an earlier entry: suffix duplicate keys so both
      // raw blocks survive
      var mapKey = key;
      var n = 2;
      while (passthrough.containsKey(mapKey)) {
        mapKey = '$key#$n';
        n++;
      }
      passthrough[mapKey] = block;
    }

    if (rawFrontmatter.trim().isEmpty) {
      return const PostFrontmatter();
    }

    // Normalize CRLF so verbatim blocks re-emit cleanly with \n
    final lines = rawFrontmatter.replaceAll('\r\n', '\n').split('\n');
    // A trailing newline splits into a phantom empty last line - drop it
    // (ParsedPost.rawFrontmatter never has one; direct callers might)
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final entry = _topLevelEntryRegex.firstMatch(line);
      if (entry == null) {
        // Comment / blank / garbage line: preserve verbatim, in order
        addPassthrough('#raw-${syntheticCount++}', line);
        i++;
        continue;
      }

      final key = entry.group(1)!;
      final inlineValue = entry.group(2)!.trim();

      // Collect the entry's continuation lines: indented lines, block-list
      // items (which YAML allows at the key's own indent), and blank lines
      // that are followed by more continuation lines (multiline literal
      // blocks may contain internal blank lines).
      final block = <String>[line];
      var j = i + 1;
      while (j < lines.length) {
        final next = lines[j];
        if (next.startsWith(' ') || next.startsWith('\t')) {
          block.add(next);
          j++;
        } else if (inlineValue.isEmpty && _listItemRegex.hasMatch(next)) {
          block.add(next);
          j++;
        } else if (next.trim().isEmpty) {
          // Only swallow blank lines that sit inside this block
          var k = j + 1;
          while (k < lines.length && lines[k].trim().isEmpty) {
            k++;
          }
          if (k < lines.length &&
              (lines[k].startsWith(' ') || lines[k].startsWith('\t'))) {
            block.addAll(lines.sublist(j, k));
            j = k;
          } else {
            break;
          }
        } else {
          break;
        }
      }
      i = j;

      final isSingleLine = block.length == 1;
      final rawBlock = block.join('\n');

      switch (key.toLowerCase()) {
        case 'title':
          if (isSingleLine && inlineValue.isNotEmpty) {
            title = _unquote(inlineValue);
          } else {
            addPassthrough(key, rawBlock);
          }
        case 'date':
          if (isSingleLine && inlineValue.isNotEmpty) {
            date = _unquote(inlineValue);
          } else {
            addPassthrough(key, rawBlock);
          }
        case 'layout':
          if (isSingleLine && inlineValue.isNotEmpty) {
            layout = _unquote(inlineValue);
          } else {
            addPassthrough(key, rawBlock);
          }
        case 'categories':
        case 'tags':
          final parsed = _parseListValue(inlineValue, block);
          if (parsed == null) {
            addPassthrough(key, rawBlock);
          } else if (key.toLowerCase() == 'categories') {
            categories = parsed;
          } else {
            tags = parsed;
          }
        default:
          addPassthrough(key, rawBlock);
      }
    }

    return PostFrontmatter(
      title: title,
      date: date,
      layout: layout,
      categories: categories ?? const [],
      tags: tags ?? const [],
      passthrough: passthrough,
    );
  }

  /// Parse a categories/tags value in any supported form; null means the
  /// form was not understood and the block must pass through verbatim.
  static List<String>? _parseListValue(String inlineValue, List<String> block) {
    if (block.length == 1) {
      if (inlineValue.isEmpty) return const [];
      if (inlineValue.startsWith('[') && inlineValue.endsWith(']')) {
        final body = inlineValue.substring(1, inlineValue.length - 1).trim();
        if (body.isEmpty) return const [];
        return _splitFlowList(body);
      }
      if (inlineValue.startsWith('[')) return null; // unterminated flow list
      // Single scalar: 'categories: blog'
      final single = _unquote(inlineValue);
      return single.isEmpty ? const [] : [single];
    }
    // Block list: every continuation line must be a '- item' entry
    if (inlineValue.isNotEmpty) return null;
    final items = <String>[];
    for (final line in block.skip(1)) {
      final m = _listItemRegex.firstMatch(line);
      if (m == null) return null;
      final item = _unquote(m.group(1)!.trim());
      if (item.isNotEmpty) items.add(item);
    }
    return items;
  }

  /// Parse a raw front matter date value to a local DateTime.
  /// Handles Jekyll's 'YYYY-MM-DD HH:MM:SS +HHMM' (DateTime.parse rejects
  /// the space before the offset), ISO 8601, and plain 'YYYY-MM-DD'.
  /// Returns null when absent or unparseable.
  static DateTime? parseDateValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    var parsed = DateTime.tryParse(value);
    // Jekyll style: remove the space before the timezone offset
    parsed ??= DateTime.tryParse(
      value.replaceFirst(RegExp(r' (?=[+-]\d{2}:?\d{2}$|Z$)'), ''),
    );
    // Last resort: date-only prefix
    if (parsed == null && value.length >= 10) {
      parsed = DateTime.tryParse(value.substring(0, 10));
    }
    return parsed?.toLocal();
  }

  // Characters that force a flow-list item to be double-quoted so the
  // emitted YAML stays valid
  static final _needsQuotingRegex = RegExp(r'''[:#,\[\]{}"']|^\s|\s$|^[&*!|>%@`-]''');

  /// Render one flow-list item, quoting only when needed
  static String _flowItem(String item) {
    if (item.isEmpty || _needsQuotingRegex.hasMatch(item)) {
      return '"${item.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    }
    return item;
  }

  /// Generate front matter from structured fields: title, date, layout?,
  /// categories?, tags?, then every [passthrough] entry verbatim (order
  /// preserved). Null title/date and empty layout/lists are omitted.
  /// Counterpart of [parseFields]: parse -> regenerate is semantically
  /// identical, and passthrough blocks round-trip byte-exact.
  static String generateFrontmatterFields({
    String? title,
    String? date,
    String? layout,
    List<String> categories = const [],
    List<String> tags = const [],
    Map<String, String> passthrough = const {},
  }) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    if (title != null) {
      final escapedTitle =
          title.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      buffer.writeln('title: "$escapedTitle"');
    }
    if (date != null && date.trim().isNotEmpty) {
      buffer.writeln('date: $date');
    }
    if (layout != null && layout.trim().isNotEmpty) {
      buffer.writeln('layout: ${layout.trim()}');
    }
    if (categories.isNotEmpty) {
      buffer.writeln('categories: [${categories.map(_flowItem).join(', ')}]');
    }
    if (tags.isNotEmpty) {
      buffer.writeln('tags: [${tags.map(_flowItem).join(', ')}]');
    }
    for (final block in passthrough.values) {
      buffer.writeln(block);
    }
    buffer.writeln('---');
    return buffer.toString();
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

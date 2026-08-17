import 'package:hive/hive.dart';

part 'blog_post.g.dart';

@HiveType(typeId: 1)
class BlogPost extends HiveObject {
  /// SHA of the file on GitHub (null if new/local draft)
  @HiveField(0)
  String? sha;

  /// Filename on GitHub - basename only (null if new)
  @HiveField(1)
  String? fileName;

  /// Full repo-relative path on GitHub, e.g. _posts/2024/foo.md or
  /// docs/_posts/foo.md. Null for local drafts and for records synced by
  /// v1.x - callers building API paths must fall back to
  /// 'postsPath/fileName'. Draft IDs keep using [fileName] (stable).
  @HiveField(8)
  String? filePath;

  /// Post title from frontmatter
  @HiveField(2)
  String title;

  /// Post date from frontmatter (YYYY-MM-DD format)
  @HiveField(3)
  String date;

  /// Raw frontmatter YAML string
  @HiveField(4)
  String? rawFrontmatter;

  /// The markdown body content (without frontmatter)
  @HiveField(5)
  String bodyContent;

  /// True if this is a local draft not yet pushed to GitHub
  @HiveField(6)
  bool isLocalDraft;

  /// Last sync timestamp
  @HiveField(7)
  DateTime? lastSynced;

  BlogPost({
    this.sha,
    this.fileName,
    this.filePath,
    required this.title,
    required this.date,
    this.rawFrontmatter,
    required this.bodyContent,
    this.isLocalDraft = false,
    this.lastSynced,
  });

  /// Create a copy with optional field overrides
  BlogPost copyWith({
    String? sha,
    String? fileName,
    String? filePath,
    String? title,
    String? date,
    String? rawFrontmatter,
    String? bodyContent,
    bool? isLocalDraft,
    DateTime? lastSynced,
  }) {
    return BlogPost(
      sha: sha ?? this.sha,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      date: date ?? this.date,
      rawFrontmatter: rawFrontmatter ?? this.rawFrontmatter,
      bodyContent: bodyContent ?? this.bodyContent,
      isLocalDraft: isLocalDraft ?? this.isLocalDraft,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  /// Parse date string to DateTime for sorting
  DateTime get dateTime {
    try {
      return DateTime.parse(date);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Get a preview excerpt from body content
  String get excerpt {
    final cleaned = bodyContent
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '') // Remove images
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1') // Links to text
        .replaceAll(RegExp(r'[#*`~>]'), '') // Remove markdown chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
    
    if (cleaned.length <= 150) return cleaned;
    return '${cleaned.substring(0, 147)}...';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlogPost &&
          runtimeType == other.runtimeType &&
          fileName == other.fileName &&
          sha == other.sha;

  @override
  int get hashCode => fileName.hashCode ^ sha.hashCode;
}

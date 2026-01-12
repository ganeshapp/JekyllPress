import 'package:hive/hive.dart';

part 'local_draft.g.dart';

/// A local draft that hasn't been published to GitHub yet.
/// Extends the concept of BlogPost with additional draft-specific metadata.
@HiveType(typeId: 2)
class LocalDraft extends HiveObject {
  /// Unique identifier for the draft (UUID or timestamp-based)
  @HiveField(0)
  String id;

  /// Post title
  @HiveField(1)
  String title;

  /// The markdown body content
  @HiveField(2)
  String bodyContent;

  /// When the draft was last modified
  @HiveField(3)
  DateTime lastModified;

  /// When the draft was first created
  @HiveField(4)
  DateTime createdAt;

  /// If editing an existing post, store original post metadata
  /// SHA of the original post (null if new)
  @HiveField(5)
  String? originalSha;

  /// Original filename (null if new)
  @HiveField(6)
  String? originalFileName;

  /// Original date string from the post (null if new)
  @HiveField(7)
  String? originalDate;

  /// Original raw frontmatter (null if new)
  @HiveField(8)
  String? originalFrontmatter;

  LocalDraft({
    required this.id,
    required this.title,
    required this.bodyContent,
    required this.lastModified,
    required this.createdAt,
    this.originalSha,
    this.originalFileName,
    this.originalDate,
    this.originalFrontmatter,
  });

  /// Create a new draft for a brand new post
  factory LocalDraft.newDraft({
    required String id,
    String title = '',
    String bodyContent = '',
  }) {
    final now = DateTime.now();
    return LocalDraft(
      id: id,
      title: title,
      bodyContent: bodyContent,
      lastModified: now,
      createdAt: now,
    );
  }

  /// Create a draft from an existing published post (for editing)
  factory LocalDraft.fromExistingPost({
    required String id,
    required String title,
    required String bodyContent,
    required String sha,
    required String fileName,
    required String date,
    String? rawFrontmatter,
  }) {
    final now = DateTime.now();
    return LocalDraft(
      id: id,
      title: title,
      bodyContent: bodyContent,
      lastModified: now,
      createdAt: now,
      originalSha: sha,
      originalFileName: fileName,
      originalDate: date,
      originalFrontmatter: rawFrontmatter,
    );
  }

  /// Whether this is editing an existing post vs a new one
  bool get isEditingExisting =>
      originalSha != null &&
      originalSha!.isNotEmpty &&
      originalFileName != null &&
      originalFileName!.isNotEmpty;

  /// Update the draft content
  LocalDraft copyWith({
    String? title,
    String? bodyContent,
    DateTime? lastModified,
  }) {
    return LocalDraft(
      id: id,
      title: title ?? this.title,
      bodyContent: bodyContent ?? this.bodyContent,
      lastModified: lastModified ?? DateTime.now(),
      createdAt: createdAt,
      originalSha: originalSha,
      originalFileName: originalFileName,
      originalDate: originalDate,
      originalFrontmatter: originalFrontmatter,
    );
  }

  /// Check if draft has meaningful content worth saving
  bool get hasContent => title.trim().isNotEmpty || bodyContent.trim().isNotEmpty;

  /// Get a preview excerpt from body content
  String get excerpt {
    final cleaned = bodyContent
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '') // Remove images
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1') // Links to text
        .replaceAll(RegExp(r'[#*`~>]'), '') // Remove markdown chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();

    if (cleaned.length <= 100) return cleaned;
    return '${cleaned.substring(0, 97)}...';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDraft && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

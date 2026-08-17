import 'package:hive/hive.dart';
import '../models/blog_post.dart';

/// A publish operation captured while offline, waiting for connectivity.
///
/// Stored in the 'publish_queue' Hive box as a PLAIN MAP (see [toMap] /
/// [QueuedPublish.fromMap]) - deliberately no TypeAdapter, so the queue
/// can never break a Hive migration.
class QueuedPublish {
  static const typeCreate = 'create';
  static const typeUpdate = 'update';

  /// Automatic retries stop after this many failed attempts; the item
  /// then waits for a manual retry (or reopen-in-editor) on the dashboard
  static const maxAttempts = 3;

  final String id;

  /// [typeCreate] or [typeUpdate]
  final String type;
  final String title;
  final String bodyContent;

  /// Create only: target the remote Jekyll drafts dir instead of posts
  final bool asDraft;
  final DateTime createdAt;

  // Post-settings values captured at queue time. Null means what it
  // means at publish time: config defaults for creates, "keep the
  // original front matter" for updates.
  final DateTime? publishDate;
  final String? layout;
  final List<String>? categories;
  final List<String>? tags;

  // Update target (null for creates)
  final String? originalPath;
  final String? originalSha;
  final String? originalFileName;
  final String? originalDate;
  final String? originalFrontmatter;

  /// Id of the local safety-net draft holding the same content; deleted
  /// together with the queue item once the publish succeeds
  final String? safetyDraftId;

  /// Failed automatic attempts so far
  final int attempts;

  /// Message of the most recent failure (shown after attempts run out)
  final String? lastError;

  const QueuedPublish({
    required this.id,
    required this.type,
    required this.title,
    required this.bodyContent,
    required this.createdAt,
    this.asDraft = false,
    this.publishDate,
    this.layout,
    this.categories,
    this.tags,
    this.originalPath,
    this.originalSha,
    this.originalFileName,
    this.originalDate,
    this.originalFrontmatter,
    this.safetyDraftId,
    this.attempts = 0,
    this.lastError,
  });

  bool get isUpdate => type == typeUpdate;

  /// True once automatic retries are exhausted
  bool get isFailed => attempts >= maxAttempts;

  /// Reconstruct the post an [typeUpdate] item targets, exactly as the
  /// editor would have passed it to PublishService.updatePost
  BlogPost toOriginalPost() {
    return BlogPost(
      sha: originalSha,
      fileName: originalFileName,
      filePath: originalPath,
      title: title,
      date: originalDate ?? '',
      rawFrontmatter: originalFrontmatter,
      bodyContent: bodyContent,
    );
  }

  QueuedPublish copyWith({int? attempts, String? lastError}) {
    return QueuedPublish(
      id: id,
      type: type,
      title: title,
      bodyContent: bodyContent,
      createdAt: createdAt,
      asDraft: asDraft,
      publishDate: publishDate,
      layout: layout,
      categories: categories,
      tags: tags,
      originalPath: originalPath,
      originalSha: originalSha,
      originalFileName: originalFileName,
      originalDate: originalDate,
      originalFrontmatter: originalFrontmatter,
      safetyDraftId: safetyDraftId,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'bodyContent': bodyContent,
      'asDraft': asDraft,
      'createdAt': createdAt.toIso8601String(),
      'publishDate': publishDate?.toIso8601String(),
      'layout': layout,
      'categories': categories,
      'tags': tags,
      'originalPath': originalPath,
      'originalSha': originalSha,
      'originalFileName': originalFileName,
      'originalDate': originalDate,
      'originalFrontmatter': originalFrontmatter,
      'safetyDraftId': safetyDraftId,
      'attempts': attempts,
      'lastError': lastError,
    };
  }

  /// Hive returns maps with dynamic keys/values - every read is
  /// defensive so a malformed record can never crash the queue
  factory QueuedPublish.fromMap(Map<dynamic, dynamic> map) {
    String? str(String key) => map[key] as String?;
    List<String>? strList(String key) {
      final value = map[key];
      if (value is! List) return null;
      return value.map((e) => e.toString()).toList();
    }

    return QueuedPublish(
      id: str('id') ?? '',
      type: str('type') ?? typeCreate,
      title: str('title') ?? '',
      bodyContent: str('bodyContent') ?? '',
      asDraft: map['asDraft'] == true,
      createdAt: DateTime.tryParse(str('createdAt') ?? '') ?? DateTime.now(),
      publishDate: DateTime.tryParse(str('publishDate') ?? ''),
      layout: str('layout'),
      categories: strList('categories'),
      tags: strList('tags'),
      originalPath: str('originalPath'),
      originalSha: str('originalSha'),
      originalFileName: str('originalFileName'),
      originalDate: str('originalDate'),
      originalFrontmatter: str('originalFrontmatter'),
      safetyDraftId: str('safetyDraftId'),
      attempts: map['attempts'] is int ? map['attempts'] as int : 0,
      lastError: str('lastError'),
    );
  }
}

/// Thin persistence layer over the 'publish_queue' Hive box.
/// The queue is FIFO by [QueuedPublish.createdAt].
class PublishQueueService {
  static const boxName = 'publish_queue';

  final Box<Map> _box;

  PublishQueueService({required Box<Map> box}) : _box = box;

  /// All queued items, oldest first. Unreadable records are skipped.
  List<QueuedPublish> loadAll() {
    final items = <QueuedPublish>[];
    for (final raw in _box.values) {
      try {
        final item = QueuedPublish.fromMap(raw);
        if (item.id.isNotEmpty) items.add(item);
      } catch (_) {
        // Corrupt record - never let it take the queue down
      }
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> put(QueuedPublish item) => _box.put(item.id, item.toMap());

  Future<void> remove(String id) => _box.delete(id);

  /// Drop every queued item. Used when the repo-scoped local data is
  /// wiped (logout / repository change) - a queued item carries its own
  /// body and would otherwise flush into whatever repo is configured next.
  Future<void> clear() async {
    await _box.clear();
  }
}

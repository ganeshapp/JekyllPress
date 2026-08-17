import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/services/publish_queue_service.dart';

QueuedPublish _createItem({
  String id = 'queued_1',
  DateTime? createdAt,
  int attempts = 0,
}) {
  return QueuedPublish(
    id: id,
    type: QueuedPublish.typeCreate,
    title: 'Hello',
    bodyContent: 'body text',
    asDraft: true,
    createdAt: createdAt ?? DateTime(2026, 8, 17, 10),
    publishDate: DateTime(2026, 8, 18, 9, 30),
    layout: 'post',
    categories: const ['dev', 'notes'],
    tags: const ['flutter'],
    safetyDraftId: 'draft_123',
    attempts: attempts,
  );
}

QueuedPublish _updateItem({String id = 'queued_2', DateTime? createdAt}) {
  return QueuedPublish(
    id: id,
    type: QueuedPublish.typeUpdate,
    title: 'Existing post',
    bodyContent: 'new body',
    createdAt: createdAt ?? DateTime(2026, 8, 17, 11),
    originalPath: '_posts/2024/2024-01-01-existing.md',
    originalSha: 'sha_orig',
    originalFileName: '2024-01-01-existing.md',
    originalDate: '2024-01-01',
    originalFrontmatter: 'title: Existing post\ndate: 2024-01-01',
    safetyDraftId: 'draft_edit_2024-01-01-existing.md',
  );
}

void main() {
  group('QueuedPublish map round-trip', () {
    test('create item survives toMap/fromMap byte-exact', () {
      final item = _createItem();
      final back = QueuedPublish.fromMap(item.toMap());

      expect(back.id, item.id);
      expect(back.type, QueuedPublish.typeCreate);
      expect(back.isUpdate, isFalse);
      expect(back.title, item.title);
      expect(back.bodyContent, item.bodyContent);
      expect(back.asDraft, isTrue);
      expect(back.createdAt, item.createdAt);
      expect(back.publishDate, item.publishDate);
      expect(back.layout, 'post');
      expect(back.categories, ['dev', 'notes']);
      expect(back.tags, ['flutter']);
      expect(back.safetyDraftId, 'draft_123');
      expect(back.attempts, 0);
      expect(back.lastError, isNull);
    });

    test('update item keeps the original-post target fields', () {
      final back = QueuedPublish.fromMap(_updateItem().toMap());

      expect(back.isUpdate, isTrue);
      expect(back.originalPath, '_posts/2024/2024-01-01-existing.md');
      expect(back.originalSha, 'sha_orig');
      expect(back.originalFileName, '2024-01-01-existing.md');
      expect(back.originalDate, '2024-01-01');
      expect(back.originalFrontmatter, contains('title: Existing post'));
      // Null sheet values mean "keep the original front matter verbatim"
      expect(back.publishDate, isNull);
      expect(back.layout, isNull);
      expect(back.categories, isNull);
      expect(back.tags, isNull);
    });

    test('fromMap tolerates dynamic-key maps and missing fields', () {
      final back = QueuedPublish.fromMap(<dynamic, dynamic>{
        'id': 'q1',
        'title': 'T',
        'bodyContent': 'B',
        'createdAt': '2026-08-17T10:00:00.000',
      });

      expect(back.id, 'q1');
      expect(back.type, QueuedPublish.typeCreate);
      expect(back.asDraft, isFalse);
      expect(back.attempts, 0);
      expect(back.categories, isNull);
    });
  });

  group('QueuedPublish behavior', () {
    test('toOriginalPost reconstructs the update target', () {
      final post = _updateItem().toOriginalPost();

      expect(post.sha, 'sha_orig');
      expect(post.fileName, '2024-01-01-existing.md');
      expect(post.filePath, '_posts/2024/2024-01-01-existing.md');
      expect(post.title, 'Existing post');
      expect(post.date, '2024-01-01');
      expect(post.rawFrontmatter, contains('date: 2024-01-01'));
      expect(post.bodyContent, 'new body');
    });

    test('copyWith increments attempts and records the error', () {
      final item = _createItem();
      final failed = item.copyWith(attempts: 1, lastError: 'boom');

      expect(failed.attempts, 1);
      expect(failed.lastError, 'boom');
      // Everything else untouched
      expect(failed.id, item.id);
      expect(failed.title, item.title);
      expect(failed.safetyDraftId, item.safetyDraftId);
    });

    test('isFailed only after maxAttempts automatic failures', () {
      expect(_createItem(attempts: 0).isFailed, isFalse);
      expect(_createItem(attempts: 2).isFailed, isFalse);
      expect(_createItem(attempts: QueuedPublish.maxAttempts).isFailed, isTrue);
    });
  });

  group('PublishQueueService', () {
    late Directory tempDir;
    late Box<Map> box;
    late PublishQueueService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('queue_test');
      Hive.init(tempDir.path);
      box = await Hive.openBox<Map>(PublishQueueService.boxName);
      service = PublishQueueService(box: box);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('loadAll returns items oldest-first (FIFO)', () async {
      await service.put(_createItem(
          id: 'newer', createdAt: DateTime(2026, 8, 17, 12)));
      await service.put(_updateItem(
          id: 'older', createdAt: DateTime(2026, 8, 17, 8)));

      final items = service.loadAll();
      expect(items.map((i) => i.id), ['older', 'newer']);
    });

    test('put/remove round-trips through the box', () async {
      await service.put(_createItem(id: 'a'));
      expect(service.loadAll().single.id, 'a');

      await service.remove('a');
      expect(service.loadAll(), isEmpty);
    });

    test('put with an existing id replaces the record (attempts)', () async {
      final item = _createItem(id: 'a');
      await service.put(item);
      await service.put(item.copyWith(attempts: 2, lastError: 'x'));

      final stored = service.loadAll().single;
      expect(stored.attempts, 2);
      expect(stored.lastError, 'x');
      expect(box.length, 1);
    });

    test('records without an id are skipped, not fatal', () async {
      await box.put('junk', <String, dynamic>{'garbage': true});
      await service.put(_createItem(id: 'good'));

      final items = service.loadAll();
      expect(items.map((i) => i.id), ['good']);
    });

    test('clear empties the box (logout / repository change)', () async {
      await service.put(_createItem(id: 'a'));
      await service.put(_updateItem(id: 'b'));
      expect(service.loadAll(), hasLength(2));

      await service.clear();

      expect(service.loadAll(), isEmpty);
      expect(box.isEmpty, isTrue);
    });
  });
}

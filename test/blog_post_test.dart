import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/blog_post.dart';
import 'package:jekyllpress/core/models/local_draft.dart';

/// The exact BlogPost adapter shape shipped in v1.x (8 fields, no filePath),
/// used to write real v1 bytes so the v2 adapter's migration path is
/// exercised against an actual on-disk record.
class _V1BlogPostAdapter extends TypeAdapter<BlogPost> {
  @override
  final int typeId = 1;

  @override
  BlogPost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlogPost(
      sha: fields[0] as String?,
      fileName: fields[1] as String?,
      title: fields[2] as String,
      date: fields[3] as String,
      rawFrontmatter: fields[4] as String?,
      bodyContent: fields[5] as String,
      isLocalDraft: fields[6] as bool,
      lastSynced: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BlogPost obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.sha)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.rawFrontmatter)
      ..writeByte(5)
      ..write(obj.bodyContent)
      ..writeByte(6)
      ..write(obj.isLocalDraft)
      ..writeByte(7)
      ..write(obj.lastSynced);
  }
}

/// The exact LocalDraft adapter shape shipped in v1.x (9 fields, no
/// originalFilePath).
class _V1LocalDraftAdapter extends TypeAdapter<LocalDraft> {
  @override
  final int typeId = 2;

  @override
  LocalDraft read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalDraft(
      id: fields[0] as String,
      title: fields[1] as String,
      bodyContent: fields[2] as String,
      lastModified: fields[3] as DateTime,
      createdAt: fields[4] as DateTime,
      originalSha: fields[5] as String?,
      originalFileName: fields[6] as String?,
      originalDate: fields[7] as String?,
      originalFrontmatter: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalDraft obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.bodyContent)
      ..writeByte(3)
      ..write(obj.lastModified)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.originalSha)
      ..writeByte(6)
      ..write(obj.originalFileName)
      ..writeByte(7)
      ..write(obj.originalDate)
      ..writeByte(8)
      ..write(obj.originalFrontmatter);
  }
}

void main() {
  group('Hive migration (v1 bytes read by v2 adapters)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('blog_post_test');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('a BlogPost written by the v1 adapter reads cleanly with v2',
        () async {
      // Write with the v1 (8-field, filePath-less) adapter
      Hive.registerAdapter(_V1BlogPostAdapter(), override: true);
      var box = await Hive.openBox<BlogPost>('posts_cache');
      final synced = DateTime.utc(2024, 5, 1, 12);
      await box.put(
        '2024-01-01-hello.md',
        BlogPost(
          sha: 'abc123',
          fileName: '2024-01-01-hello.md',
          title: 'Hello',
          date: '2024-01-01',
          rawFrontmatter: 'title: Hello\ndate: 2024-01-01',
          bodyContent: 'Body text',
          isLocalDraft: false,
          lastSynced: synced,
        ),
      );
      await box.close();

      // Read back the same bytes with the real v2 adapter
      Hive.registerAdapter(BlogPostAdapter(), override: true);
      box = await Hive.openBox<BlogPost>('posts_cache');
      final post = box.get('2024-01-01-hello.md');

      expect(post, isNotNull);
      expect(post!.sha, 'abc123');
      expect(post.fileName, '2024-01-01-hello.md');
      expect(post.title, 'Hello');
      expect(post.date, '2024-01-01');
      expect(post.rawFrontmatter, 'title: Hello\ndate: 2024-01-01');
      expect(post.bodyContent, 'Body text');
      expect(post.isLocalDraft, isFalse);
      expect(post.lastSynced, synced);
      // The v2-only field is absent in v1 records: null, so callers fall
      // back to 'postsPath/fileName'.
      expect(post.filePath, isNull);
    });

    test('a v2 BlogPost round-trips filePath through disk', () async {
      Hive.registerAdapter(BlogPostAdapter(), override: true);
      var box = await Hive.openBox<BlogPost>('posts_cache_v2');
      await box.put(
        'docs/_posts/foo.md',
        BlogPost(
          sha: 'def456',
          fileName: 'foo.md',
          filePath: 'docs/_posts/foo.md',
          title: 'Foo',
          date: '2025-02-03',
          bodyContent: 'x',
        ),
      );
      await box.close();

      box = await Hive.openBox<BlogPost>('posts_cache_v2');
      final post = box.get('docs/_posts/foo.md')!;
      expect(post.filePath, 'docs/_posts/foo.md');
      expect(post.fileName, 'foo.md');
    });

    test('a LocalDraft written by the v1 adapter reads cleanly with v2',
        () async {
      // Write with the v1 (9-field, originalFilePath-less) adapter
      Hive.registerAdapter(_V1LocalDraftAdapter(), override: true);
      var box = await Hive.openBox<LocalDraft>('drafts');
      final modified = DateTime.utc(2024, 6, 2, 8, 30);
      final created = DateTime.utc(2024, 6, 1, 9);
      await box.put(
        'draft-1',
        LocalDraft(
          id: 'draft-1',
          title: 'WIP',
          bodyContent: 'Draft body',
          lastModified: modified,
          createdAt: created,
          originalSha: 'sha-1',
          originalFileName: '2024-06-01-wip.md',
          originalDate: '2024-06-01',
          originalFrontmatter: 'title: WIP',
        ),
      );
      await box.close();

      // Read back the same bytes with the real v2 adapter
      Hive.registerAdapter(LocalDraftAdapter(), override: true);
      box = await Hive.openBox<LocalDraft>('drafts');
      final draft = box.get('draft-1');

      expect(draft, isNotNull);
      expect(draft!.id, 'draft-1');
      expect(draft.title, 'WIP');
      expect(draft.bodyContent, 'Draft body');
      expect(draft.lastModified, modified);
      expect(draft.createdAt, created);
      expect(draft.originalSha, 'sha-1');
      expect(draft.originalFileName, '2024-06-01-wip.md');
      expect(draft.originalDate, '2024-06-01');
      expect(draft.originalFrontmatter, 'title: WIP');
      // v2-only field absent in v1 records
      expect(draft.originalFilePath, isNull);
    });
  });
}

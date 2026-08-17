import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/local_draft.dart';
import 'package:jekyllpress/core/providers/drafts_provider.dart';

void main() {
  late Directory tempDir;
  late Box<LocalDraft> box;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('drafts_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(LocalDraftAdapter());
    }
    box = await Hive.openBox<LocalDraft>('drafts_box');

    container = ProviderContainer();
    // Keep the autoDispose providers alive for the duration of the test
    container.listen(draftsNotifierProvider, (_, __) {});
    container.listen(currentDraftNotifierProvider, (_, __) {});
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('CurrentDraftNotifier.updateAndSave', () {
    test('persists content and returns true', () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();

      final persisted =
          await notifier.updateAndSave(title: 'Hello', bodyContent: 'World');

      expect(persisted, isTrue);
      expect(box.length, 1);
      expect(box.values.first.title, 'Hello');
      expect(box.values.first.bodyContent, 'World');
    });

    test('returns promptly without awaiting the 2s status reset', () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();

      final stopwatch = Stopwatch()..start();
      await notifier.updateAndSave(title: 'Hello', bodyContent: 'World');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(container.read(currentDraftNotifierProvider),
          DraftSaveStatus.saved);
    });

    test('emptied content deletes the stored record and returns false',
        () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();
      await notifier.updateAndSave(title: 'Hello', bodyContent: 'World');
      final draftId = notifier.currentDraft!.id;
      expect(box.get(draftId), isNotNull);

      // User deletes everything: the record must be removed, not skipped
      final persisted = await notifier.updateAndSave(title: '', bodyContent: '');

      expect(persisted, isFalse);
      expect(box.get(draftId), isNull);
      expect(box.isEmpty, isTrue);
      expect(
          container.read(currentDraftNotifierProvider), DraftSaveStatus.idle);
    });

    test('empty content with nothing stored skips and returns false',
        () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();

      final persisted = await notifier.updateAndSave(title: '', bodyContent: '');

      expect(persisted, isFalse);
      expect(box.isEmpty, isTrue);
    });

    test('emptied content does not resurrect on next open', () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();
      await notifier.updateAndSave(title: 'Keep me?', bodyContent: 'No.');
      final draftId = notifier.currentDraft!.id;

      await notifier.updateAndSave(title: '', bodyContent: '');

      final draftsNotifier = container.read(draftsNotifierProvider.notifier);
      expect(draftsNotifier.getDraft(draftId), isNull);
    });

    test('is a no-op while clearAfterPublish is running', () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();
      await notifier.updateAndSave(title: 'Post', bodyContent: 'Body');
      final draftId = notifier.currentDraft!.id;

      // Simulate the debounced autosave firing mid-publish-cleanup
      final clearFuture = notifier.clearAfterPublish();
      final persisted =
          await notifier.updateAndSave(title: 'Post', bodyContent: 'Body v2');
      await clearFuture;

      expect(persisted, isFalse);
      expect(box.get(draftId), isNull);
      expect(box.isEmpty, isTrue);
    });
  });

  group('CurrentDraftNotifier.forceSave', () {
    test('persists content and returns true', () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();

      final persisted =
          await notifier.forceSave(title: 'Hello', bodyContent: 'World');

      expect(persisted, isTrue);
      expect(box.length, 1);
    });

    test('emptied content deletes the stored record and returns false',
        () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();
      await notifier.forceSave(title: 'Hello', bodyContent: 'World');
      final draftId = notifier.currentDraft!.id;

      final persisted = await notifier.forceSave(title: '', bodyContent: '');

      expect(persisted, isFalse);
      expect(box.get(draftId), isNull);
    });

    test('empty content with nothing stored returns false', () async {
      final notifier = container.read(currentDraftNotifierProvider.notifier);
      notifier.initializeNewDraft();

      final persisted = await notifier.forceSave(title: '', bodyContent: '');

      expect(persisted, isFalse);
      expect(box.isEmpty, isTrue);
    });
  });

  group('DraftsNotifier.clearAll', () {
    test('wipes the box and the state', () async {
      await box.put('a', LocalDraft.newDraft(id: 'a', title: 'One'));
      await box.put('b', LocalDraft.newDraft(id: 'b', title: 'Two'));

      final draftsNotifier = container.read(draftsNotifierProvider.notifier);
      await draftsNotifier.clearAll();

      expect(box.isEmpty, isTrue);
      expect(container.read(draftsNotifierProvider).drafts, isEmpty);
    });
  });
}

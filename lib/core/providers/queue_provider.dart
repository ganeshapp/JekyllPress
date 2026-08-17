import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../services/github_upload_service.dart';
import '../services/publish_queue_service.dart';
import '../services/publish_service.dart';
import 'config_provider.dart';
import 'drafts_provider.dart';
import 'posts_provider.dart';
import 'publish_provider.dart';

part 'queue_provider.g.dart';

/// Connectivity plugin access point - overridable in tests so nothing
/// touches platform channels
@Riverpod(keepAlive: true)
Connectivity connectivity(Ref ref) => Connectivity();

/// Provider for the publish queue Hive box
@riverpod
Box<Map> publishQueueBox(Ref ref) {
  return Hive.box<Map>(PublishQueueService.boxName);
}

/// Provider for PublishQueueService
@riverpod
PublishQueueService publishQueueService(Ref ref) {
  return PublishQueueService(box: ref.watch(publishQueueBoxProvider));
}

/// Offline publish queue: holds posts the user chose to 'publish when
/// online' and flushes them FIFO through the existing PublishService
/// whenever connectivity returns or the app resumes.
///
/// Kept alive: the queue must keep listening for connectivity while no
/// screen is watching it.
@Riverpod(keepAlive: true)
class PublishQueueNotifier extends _$PublishQueueNotifier {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  AppLifecycleListener? _lifecycleListener;

  /// One flush at a time - connectivity events and manual retries coalesce
  bool _isProcessing = false;

  @override
  List<QueuedPublish> build() {
    final service = ref.watch(publishQueueServiceProvider);

    _connectivitySub?.cancel();
    _connectivitySub = ref.watch(connectivityProvider).onConnectivityChanged.listen(
      (results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          processQueue();
        }
      },
      // Platform-channel hiccups must never crash the app
      onError: (_) {},
    );
    _lifecycleListener ??= AppLifecycleListener(
      onResume: () => processQueue(),
    );
    ref.onDispose(() {
      _connectivitySub?.cancel();
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    });

    return service.loadAll();
  }

  /// Queued items whose automatic retries are exhausted
  List<QueuedPublish> get failedItems =>
      state.where((item) => item.isFailed).toList();

  /// Add [item] to the queue (it will publish on the next flush)
  Future<void> enqueue(QueuedPublish item) async {
    await ref.read(publishQueueServiceProvider).put(item);
    _reload();
  }

  /// Remove [id] from the queue (e.g. the user reopened it in the editor)
  Future<void> removeItem(String id) async {
    await ref.read(publishQueueServiceProvider).remove(id);
    _reload();
  }

  /// Remove every queued item whose safety draft is [draftId]. The editor
  /// calls this when that draft is published directly (the user reopened
  /// a queued post's safety draft from the Drafts tab) or re-queued, so
  /// the queue can never publish a second copy of the same content.
  Future<void> removeItemsForDraft(String draftId) async {
    final service = ref.read(publishQueueServiceProvider);
    for (final item in service.loadAll()) {
      if (item.safetyDraftId == draftId) {
        await service.remove(item.id);
      }
    }
    _reload();
  }

  /// Publish queued items FIFO through the existing PublishService
  /// (reusing its duplicate-suffix and stale-sha handling). Per item:
  /// success deletes the item and its safety draft; a connectivity-class
  /// failure stops the pass WITHOUT burning an attempt (still offline);
  /// any other failure increments [QueuedPublish.attempts], and after
  /// [QueuedPublish.maxAttempts] the item waits for [manual] retry.
  Future<void> processQueue({bool manual = false}) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final configState = ref.read(configNotifierProvider);
      final config = configState is ConfigLoaded ? configState.config : null;
      if (config == null) return;

      final service = ref.read(publishQueueServiceProvider);
      var publishedAny = false;

      for (final item in service.loadAll()) {
        // Exhausted items only run again when the user asks
        if (!manual && item.isFailed) continue;

        final failure = await _publishItem(config, item);
        if (failure == null) {
          await service.remove(item.id);
          final draftId = item.safetyDraftId;
          if (draftId != null) {
            await ref
                .read(draftsNotifierProvider.notifier)
                .deleteDraft(draftId);
          }
          publishedAny = true;
        } else if (failure.kind == PublishErrorKind.offline) {
          // Still offline: the whole pass is doomed - keep every item's
          // attempt count untouched and wait for the next connectivity
          // event
          break;
        } else {
          await service.put(item.copyWith(
            attempts: item.attempts + 1,
            lastError: failure.message,
          ));
        }
      }

      _reload();
      if (publishedAny) {
        await ref.read(postsNotifierProvider.notifier).refresh();
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<PublishFailure?> _publishItem(
    AppConfig config,
    QueuedPublish item,
  ) async {
    try {
      final publishService = ref.read(publishServiceProvider);
      final PublishResult result;
      if (item.isUpdate) {
        result = await publishService.updatePost(
          config: config,
          originalPost: item.toOriginalPost(),
          newBodyContent: item.bodyContent,
          publishDate: item.publishDate,
          layout: item.layout,
          categories: item.categories,
          tags: item.tags,
        );
      } else {
        result = await publishService.createPost(
          config: config,
          title: item.title,
          bodyContent: item.bodyContent,
          asDraft: item.asDraft,
          publishDate: item.publishDate,
          layout: item.layout,
          categories: item.categories,
          tags: item.tags,
        );
      }
      return switch (result) {
        PublishSuccess() => null,
        final PublishFailure failure => failure,
      };
    } catch (e) {
      return PublishFailure('Publish failed: $e', kind: publishErrorKindOf(e));
    }
  }

  void _reload() {
    state = ref.read(publishQueueServiceProvider).loadAll();
  }
}

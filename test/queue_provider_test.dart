import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/models/blog_post.dart';
import 'package:jekyllpress/core/models/local_draft.dart';
import 'package:jekyllpress/core/providers/queue_provider.dart';
import 'package:jekyllpress/core/providers/posts_provider.dart';
import 'package:jekyllpress/core/providers/publish_provider.dart';
import 'package:jekyllpress/core/services/content_service.dart';
import 'package:jekyllpress/core/services/github_upload_service.dart';
import 'package:jekyllpress/core/services/publish_queue_service.dart';
import 'package:jekyllpress/core/services/publish_service.dart';

/// Connectivity whose stream and check results are scripted by the test
class _FakeConnectivity implements Connectivity {
  final controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> current = const [ConnectivityResult.wifi];

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      controller.stream;
}

/// PublishService with scripted per-call results (empty script = success)
class _FakePublishService extends PublishService {
  _FakePublishService()
      : super(uploadService: GitHubUploadService(dio: Dio()));

  final List<String> createdTitles = [];
  final List<String> updatedPaths = [];
  final List<PublishResult> script = [];

  PublishResult _next(String filename) {
    if (script.isNotEmpty) return script.removeAt(0);
    return PublishSuccess(
      sha: 'sha_new',
      filename: filename,
      filePath: '_posts/$filename',
      htmlUrl: 'https://x',
    );
  }

  @override
  Future<PublishResult> createPost({
    required AppConfig config,
    required String title,
    required String bodyContent,
    bool asDraft = false,
    DateTime? publishDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
  }) async {
    createdTitles.add(title);
    return _next('$title.md');
  }

  @override
  Future<PublishResult> updatePost({
    required AppConfig config,
    required BlogPost originalPost,
    required String newBodyContent,
    DateTime? publishDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
    bool force = false,
  }) async {
    updatedPaths.add(originalPost.filePath ?? '');
    return _next(originalPost.fileName ?? 'x.md');
  }
}

/// ContentService whose sync returns nothing (posts refresh is a no-op)
class _FakeContentService extends ContentService {
  _FakeContentService() : super(dio: Dio());

  int syncCalls = 0;

  @override
  Future<List<BlogPost>> syncPosts({
    required AppConfig config,
    required Map<String, BlogPost> existingPosts,
    void Function(int done, int total)? onProgress,
  }) async {
    syncCalls++;
    return [];
  }
}

QueuedPublish _item(
  String id, {
  DateTime? createdAt,
  String? safetyDraftId,
  int attempts = 0,
}) {
  return QueuedPublish(
    id: id,
    type: QueuedPublish.typeCreate,
    title: 'Post $id',
    bodyContent: 'body',
    createdAt: createdAt ?? DateTime(2026, 8, 17, 10),
    safetyDraftId: safetyDraftId,
    attempts: attempts,
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  // AppLifecycleListener (app-resume flush) needs a widgets binding
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<Map> queueBox;
  late Box<LocalDraft> draftsBox;
  late _FakeConnectivity connectivity;
  late _FakePublishService publish;
  late _FakeContentService content;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('queue_provider_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AppConfigAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BlogPostAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(LocalDraftAdapter());
    }
    queueBox = await Hive.openBox<Map>(PublishQueueService.boxName);
    draftsBox = await Hive.openBox<LocalDraft>('drafts_box');
    await Hive.openBox<BlogPost>('posts_box');
    final configBox = await Hive.openBox<AppConfig>('app_config');
    await configBox.put(
      'current_config',
      AppConfig(repoOwner: 'gapp', repoName: 'blog'),
    );

    connectivity = _FakeConnectivity();
    publish = _FakePublishService();
    content = _FakeContentService();
    container = ProviderContainer(
      overrides: [
        connectivityProvider.overrideWithValue(connectivity),
        publishQueueBoxProvider.overrideWithValue(queueBox),
        publishServiceProvider.overrideWithValue(publish),
        contentServiceProvider.overrideWithValue(content),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await connectivity.controller.close();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  PublishQueueNotifier notifier() =>
      container.read(publishQueueNotifierProvider.notifier);

  test('build loads persisted queue items oldest-first', () async {
    await queueBox.put('b',
        _item('b', createdAt: DateTime(2026, 8, 17, 12)).toMap());
    await queueBox.put('a',
        _item('a', createdAt: DateTime(2026, 8, 17, 8)).toMap());

    final state = container.read(publishQueueNotifierProvider);
    expect(state.map((i) => i.id), ['a', 'b']);
  });

  test('enqueue persists to the box and updates state', () async {
    await notifier().enqueue(_item('q1'));

    expect(queueBox.containsKey('q1'), isTrue);
    expect(
      container.read(publishQueueNotifierProvider).single.id,
      'q1',
    );
  });

  test('processQueue publishes FIFO, removes items and safety drafts, '
      'and refreshes posts', () async {
    await draftsBox.put(
        'draft_safe', LocalDraft.newDraft(id: 'draft_safe', title: 'Post 1'));
    await notifier().enqueue(_item('1',
        createdAt: DateTime(2026, 8, 17, 8), safetyDraftId: 'draft_safe'));
    await notifier().enqueue(_item('2', createdAt: DateTime(2026, 8, 17, 9)));

    await notifier().processQueue();
    await _settle();

    expect(publish.createdTitles, ['Post 1', 'Post 2']);
    expect(queueBox.isEmpty, isTrue);
    expect(container.read(publishQueueNotifierProvider), isEmpty);
    expect(draftsBox.containsKey('draft_safe'), isFalse);
    expect(content.syncCalls, greaterThanOrEqualTo(1));
  });

  test('removeItemsForDraft drops every entry backed by that safety draft '
      '(manual publish / re-queue can never double-publish)', () async {
    await notifier().enqueue(_item('1',
        createdAt: DateTime(2026, 8, 17, 8), safetyDraftId: 'draft_a'));
    await notifier().enqueue(_item('2',
        createdAt: DateTime(2026, 8, 17, 9), safetyDraftId: 'draft_a'));
    await notifier().enqueue(_item('3',
        createdAt: DateTime(2026, 8, 17, 10), safetyDraftId: 'draft_b'));

    await notifier().removeItemsForDraft('draft_a');

    expect(queueBox.containsKey('1'), isFalse);
    expect(queueBox.containsKey('2'), isFalse);
    expect(queueBox.containsKey('3'), isTrue);
    expect(
      container.read(publishQueueNotifierProvider).map((i) => i.id),
      ['3'],
    );
  });

  test('update items go through PublishService.updatePost', () async {
    final update = QueuedPublish(
      id: 'u1',
      type: QueuedPublish.typeUpdate,
      title: 'Existing',
      bodyContent: 'new body',
      createdAt: DateTime(2026, 8, 17, 10),
      originalPath: '_posts/2024-01-01-existing.md',
      originalSha: 'sha_orig',
      originalFileName: '2024-01-01-existing.md',
      originalDate: '2024-01-01',
    );
    await notifier().enqueue(update);

    await notifier().processQueue();

    expect(publish.updatedPaths, ['_posts/2024-01-01-existing.md']);
    expect(publish.createdTitles, isEmpty);
    expect(queueBox.isEmpty, isTrue);
  });

  test('a non-offline failure increments attempts and keeps the item',
      () async {
    publish.script.add(const PublishFailure('Validation failed'));
    await notifier().enqueue(_item('q1'));

    await notifier().processQueue();

    final stored = container.read(publishQueueNotifierProvider).single;
    expect(stored.attempts, 1);
    expect(stored.lastError, 'Validation failed');
    expect(stored.isFailed, isFalse);
  });

  test('after maxAttempts the item is skipped automatically but a manual '
      'retry still runs it', () async {
    await notifier().enqueue(
        _item('q1', attempts: QueuedPublish.maxAttempts));

    await notifier().processQueue();
    expect(publish.createdTitles, isEmpty, reason: 'automatic pass skips');
    expect(queueBox.containsKey('q1'), isTrue);

    await notifier().processQueue(manual: true);
    expect(publish.createdTitles, ['Post q1']);
    expect(queueBox.isEmpty, isTrue);
  });

  test('an offline failure stops the pass without burning attempts',
      () async {
    publish.script.add(const PublishFailure('No internet connection',
        kind: PublishErrorKind.offline));
    await notifier().enqueue(_item('1', createdAt: DateTime(2026, 8, 17, 8)));
    await notifier().enqueue(_item('2', createdAt: DateTime(2026, 8, 17, 9)));

    await notifier().processQueue();

    // Only the first item was attempted; both are still queued untouched
    expect(publish.createdTitles, ['Post 1']);
    final state = container.read(publishQueueNotifierProvider);
    expect(state.length, 2);
    expect(state.every((i) => i.attempts == 0), isTrue);
  });

  test('a connectivity-restored event flushes the queue', () async {
    await notifier().enqueue(_item('q1'));

    connectivity.controller.add(const [ConnectivityResult.wifi]);
    await _settle();

    expect(publish.createdTitles, ['Post q1']);
    expect(queueBox.isEmpty, isTrue);
  });

  test('a none-connectivity event does not trigger a flush', () async {
    await notifier().enqueue(_item('q1'));

    connectivity.controller.add(const [ConnectivityResult.none]);
    await _settle();

    expect(publish.createdTitles, isEmpty);
    expect(queueBox.containsKey('q1'), isTrue);
  });
}

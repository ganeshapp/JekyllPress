import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/models/blog_post.dart';
import 'package:jekyllpress/core/providers/posts_provider.dart';
import 'package:jekyllpress/core/services/content_service.dart';

/// ContentService whose syncPosts is fully scripted from the test
class FakeContentService extends ContentService {
  FakeContentService() : super(dio: Dio());

  /// When set, syncPosts returns this; when null, syncPosts throws
  List<BlogPost> Function()? onSync;

  /// When set, syncPosts blocks on this until completed
  Completer<List<BlogPost>>? gate;

  /// When set, syncPosts reports this (done, total) sequence
  List<(int, int)> progressScript = const [];

  int syncCalls = 0;

  @override
  Future<List<BlogPost>> syncPosts({
    required AppConfig config,
    required Map<String, BlogPost> existingPosts,
    void Function(int done, int total)? onProgress,
  }) async {
    syncCalls++;
    final pending = gate;
    if (pending != null) return pending.future;
    for (final (done, total) in progressScript) {
      onProgress?.call(done, total);
    }
    final handler = onSync;
    if (handler == null) throw Exception('network down');
    return handler();
  }
}

BlogPost _post(String fileName, String date, {DateTime? lastSynced}) {
  return BlogPost(
    sha: 'sha_$fileName',
    fileName: fileName,
    title: fileName,
    date: date,
    bodyContent: 'body',
    lastSynced: lastSynced,
  );
}

/// Let scheduled microtasks/futures run
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late Directory tempDir;
  late Box<BlogPost> postsBox;
  late Box<AppConfig> configBox;
  late FakeContentService fakeService;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('posts_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AppConfigAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BlogPostAdapter());
    }
    postsBox = await Hive.openBox<BlogPost>('posts_box');
    configBox = await Hive.openBox<AppConfig>('app_config');
    await configBox.put(
      'current_config',
      AppConfig(repoOwner: 'gapp', repoName: 'blog'),
    );

    fakeService = FakeContentService();
    container = ProviderContainer(
      overrides: [
        contentServiceProvider.overrideWithValue(fakeService),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  /// Read the provider (triggering build) and keep it alive
  PostsState readPosts() {
    container.listen(postsNotifierProvider, (_, __) {});
    return container.read(postsNotifierProvider);
  }

  group('PostsNotifier.build', () {
    test('returns cached posts synchronously with isRefreshing', () async {
      final synced = DateTime(2026, 8, 1, 12);
      await postsBox.put(
        '2026-07-01-a.md',
        _post('2026-07-01-a.md', '2026-07-01', lastSynced: synced),
      );
      fakeService.onSync = () => [];

      // The FIRST synchronous read must already contain the cached posts -
      // no spinner, no waiting for the network
      final state = readPosts();

      expect(state, isA<PostsLoaded>());
      final loaded = state as PostsLoaded;
      expect(loaded.posts.length, 1);
      expect(loaded.posts.first.fileName, '2026-07-01-a.md');
      expect(loaded.isRefreshing, isTrue);
      expect(loaded.lastSynced, synced);
      await _settle();
    });

    test('returns PostsInitial when cache is empty', () async {
      fakeService.onSync = () => [];

      final state = readPosts();

      expect(state, isA<PostsInitial>());
      await _settle();
    });

    test('schedules a background refresh', () async {
      fakeService.onSync = () => [_post('2026-08-01-b.md', '2026-08-01')];

      readPosts();
      await _settle();

      expect(fakeService.syncCalls, 1);
      final state = container.read(postsNotifierProvider);
      expect(state, isA<PostsLoaded>());
      expect((state as PostsLoaded).posts.first.fileName, '2026-08-01-b.md');
      expect(state.isRefreshing, isFalse);
    });
  });

  group('PostsNotifier.refresh', () {
    test('failure keeps cached posts and carries syncError', () async {
      await postsBox.put(
        '2026-07-01-a.md',
        _post('2026-07-01-a.md', '2026-07-01', lastSynced: DateTime(2026, 8)),
      );
      fakeService.onSync = null; // every sync throws

      readPosts();
      await _settle();

      final state = container.read(postsNotifierProvider);
      expect(state, isA<PostsLoaded>());
      final loaded = state as PostsLoaded;
      expect(loaded.posts.length, 1);
      expect(loaded.syncError, isNotNull);
      expect(loaded.syncError, contains('network down'));
      expect(loaded.isRefreshing, isFalse);
      expect(loaded.lastSynced, DateTime(2026, 8));
      // Cache untouched on failure
      expect(postsBox.length, 1);
    });

    test('success updates posts, clears syncError, stamps lastSynced',
        () async {
      await postsBox.put(
        '2026-07-01-a.md',
        _post('2026-07-01-a.md', '2026-07-01', lastSynced: DateTime(2026, 1)),
      );
      fakeService.onSync = () => [_post('2026-08-10-c.md', '2026-08-10')];

      readPosts();
      await _settle();

      final state = container.read(postsNotifierProvider);
      expect(state, isA<PostsLoaded>());
      final loaded = state as PostsLoaded;
      expect(loaded.syncError, isNull);
      expect(loaded.posts.map((p) => p.fileName), ['2026-08-10-c.md']);
      expect(loaded.lastSynced, isNotNull);
      // Cache rewritten and stamped with the sync time (persisted)
      expect(postsBox.length, 1);
      expect(postsBox.get('2026-08-10-c.md')!.lastSynced, loaded.lastSynced);
    });

    test('overlapping refresh calls coalesce into one sync', () async {
      fakeService.gate = Completer<List<BlogPost>>();

      readPosts();
      await _settle(); // build's refresh is now in flight, blocked on gate

      final notifier = container.read(postsNotifierProvider.notifier);
      await notifier.refresh(); // must coalesce, not start a second sync
      await notifier.refresh();

      expect(fakeService.syncCalls, 1);

      fakeService.gate!.complete([_post('2026-08-11-d.md', '2026-08-11')]);
      fakeService.gate = null;
      await _settle();

      final state = container.read(postsNotifierProvider);
      expect(state, isA<PostsLoaded>());
      expect((state as PostsLoaded).posts.length, 1);
    });

    test('surfaces sync progress through the refreshing state', () async {
      await postsBox.put(
        '2026-07-01-a.md',
        _post('2026-07-01-a.md', '2026-07-01'),
      );
      fakeService.progressScript = const [(0, 2), (1, 2), (2, 2)];
      fakeService.onSync = () => [_post('2026-08-10-c.md', '2026-08-10')];

      final progress = <(int?, int?)>[];
      container.listen(postsNotifierProvider, (_, next) {
        if (next is PostsLoaded && next.isRefreshing && next.syncTotal != null) {
          progress.add((next.syncDone, next.syncTotal));
        }
      });
      container.read(postsNotifierProvider);
      await _settle();

      expect(progress, [(0, 2), (1, 2), (2, 2)]);
      // Progress fields are cleared once the refresh lands
      final state = container.read(postsNotifierProvider);
      expect(state, isA<PostsLoaded>());
      final loaded = state as PostsLoaded;
      expect(loaded.isRefreshing, isFalse);
      expect(loaded.syncDone, isNull);
      expect(loaded.syncTotal, isNull);
    });

    test('reports PostsError when no repository is configured', () async {
      await configBox.delete('current_config');
      fakeService.onSync = () => [];

      readPosts();
      await _settle();

      final state = container.read(postsNotifierProvider);
      expect(state, isA<PostsError>());
      expect((state as PostsError).message, 'No repository configured');
    });
  });

  group('PostsNotifier.clearAll', () {
    test('empties the cache box and resets state', () async {
      await postsBox.put(
        '2026-07-01-a.md',
        _post('2026-07-01-a.md', '2026-07-01'),
      );
      fakeService.onSync = () => [_post('2026-07-01-a.md', '2026-07-01')];

      readPosts();
      await _settle();
      expect(postsBox.isNotEmpty, isTrue);

      await container.read(postsNotifierProvider.notifier).clearAll();

      expect(postsBox.isEmpty, isTrue);
      expect(container.read(postsNotifierProvider), isA<PostsInitial>());
    });
  });
}

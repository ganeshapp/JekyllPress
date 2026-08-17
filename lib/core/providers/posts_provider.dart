import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../services/content_service.dart';
import '../services/dio_client.dart';
import 'config_provider.dart';

part 'posts_provider.g.dart';

/// Provider for ContentService
@riverpod
ContentService contentService(Ref ref) {
  return ContentService(dio: ref.watch(apiClientProvider).dio);
}

/// Provider for the posts Hive box
@riverpod
Box<BlogPost> postsBox(Ref ref) {
  return Hive.box<BlogPost>('posts_box');
}

/// True when [post] is a Jekyll draft living under [config.draftsPath]
/// on GitHub.
///
/// DESIGN: nothing extra is stored - remote drafts are synced and cached
/// exactly like posts (keyed by filePath), and the draft-ness is DERIVED
/// from the stored path wherever it is needed. This avoids a Hive
/// migration and can never disagree with where the file actually lives.
bool isRemoteDraft(BlogPost post, AppConfig config) {
  final path = post.filePath;
  if (path == null) return false;
  return path.startsWith('${ContentService.cleanDir(config.draftsPath)}/');
}

/// Case-insensitive dashboard search: keeps posts whose title or body
/// contains [query] as a substring. An empty/whitespace query keeps all.
List<BlogPost> filterPostsByQuery(List<BlogPost> posts, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return posts;
  return posts
      .where((p) =>
          p.title.toLowerCase().contains(q) ||
          p.bodyContent.toLowerCase().contains(q))
      .toList();
}

/// State for posts list
sealed class PostsState {
  const PostsState();
}

class PostsInitial extends PostsState {
  const PostsInitial();
}

class PostsLoading extends PostsState {
  final List<BlogPost> cachedPosts;
  const PostsLoading([this.cachedPosts = const []]);
}

class PostsLoaded extends PostsState {
  final List<BlogPost> posts;
  final bool isRefreshing;
  final DateTime? lastSynced;

  /// Sync progress while [isRefreshing]: changed files fetched so far /
  /// total changed files. Null when no fetch is in flight (nothing
  /// changed, or refresh not started) - the dashboard shows
  /// 'Syncing x of y' only when both are set.
  final int? syncDone;
  final int? syncTotal;

  /// Non-null when the last refresh failed but cached posts are shown
  final String? syncError;

  const PostsLoaded({
    required this.posts,
    this.isRefreshing = false,
    this.lastSynced,
    this.syncDone,
    this.syncTotal,
    this.syncError,
  });
}

class PostsError extends PostsState {
  final String message;
  final List<BlogPost> cachedPosts;
  
  const PostsError(this.message, [this.cachedPosts = const []]);
}

/// Notifier for managing posts with offline-first logic
@riverpod
class PostsNotifier extends _$PostsNotifier {
  /// In-flight guard so overlapping refresh() calls (build + pull-to-refresh
  /// + post-publish) don't interleave cache writes
  bool _isRefreshing = false;

  @override
  PostsState build() {
    // Read the cache synchronously and return it directly - state writes
    // inside build()'s prelude are discarded by Riverpod (the return value
    // wins), so the cached posts must BE the return value.
    List<BlogPost> cachedPosts;
    try {
      cachedPosts = _loadFromCache();
    } catch (_) {
      cachedPosts = const [];
    }

    // Background refresh from API
    Future.microtask(() async {
      try {
        await refresh();
      } catch (_) {
        // Provider was disposed before/while the initial refresh ran
      }
    });

    if (cachedPosts.isEmpty) {
      return const PostsInitial();
    }
    return PostsLoaded(
      posts: cachedPosts,
      isRefreshing: true,
      lastSynced: _latestSync(cachedPosts),
    );
  }

  /// Get current config
  AppConfig? get _config {
    final configState = ref.read(configNotifierProvider);
    return configState is ConfigLoaded ? configState.config : null;
  }

  /// Load posts from Hive cache
  List<BlogPost> _loadFromCache() {
    final box = ref.read(postsBoxProvider);
    final posts = box.values.toList();
    // Sort by date, newest first
    posts.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return posts;
  }

  /// Latest successful sync time recorded across cached posts
  /// (persisted per-post in the Hive box, so it survives restarts)
  DateTime? _latestSync(List<BlogPost> posts) {
    DateTime? latest;
    for (final post in posts) {
      final synced = post.lastSynced;
      if (synced != null && (latest == null || synced.isAfter(latest))) {
        latest = synced;
      }
    }
    return latest;
  }

  /// Cache/box key for a synced post: the full repo-relative path when
  /// known (unique across _posts subfolders), else the bare filename
  /// (v1 records, local drafts)
  String? _cacheKey(BlogPost post) => post.filePath ?? post.fileName;

  /// Save posts to Hive cache, stamping each with the sync time.
  /// Entries are built first, then written with clear + putAll in one
  /// sequence to minimize the window for a partial cache.
  Future<void> _saveToCache(List<BlogPost> posts, DateTime syncTime) async {
    final box = ref.read(postsBoxProvider);
    final entries = <String, BlogPost>{};
    for (final post in posts) {
      final key = _cacheKey(post);
      if (key != null) {
        post.lastSynced = syncTime;
        entries[key] = post;
      }
    }
    await box.clear();
    await box.putAll(entries);
  }

  /// Refresh posts from GitHub API. Concurrent calls coalesce into the
  /// already-running refresh.
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      await _doRefresh();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _doRefresh() async {
    final config = _config;
    if (config == null) {
      state = const PostsError('No repository configured');
      return;
    }

    final currentPosts = switch (state) {
      PostsLoaded(posts: final p) => p,
      PostsLoading(cachedPosts: final p) => p,
      PostsError(cachedPosts: final p) => p,
      _ => <BlogPost>[],
    };

    // Show refreshing state if we have existing posts
    if (currentPosts.isNotEmpty) {
      state = PostsLoaded(
        posts: currentPosts,
        isRefreshing: true,
        lastSynced: _latestSync(currentPosts),
      );
    }

    try {
      final contentService = ref.read(contentServiceProvider);

      // Create map of existing posts for SHA comparison, keyed by full
      // repo-relative path (v1 records fall back to '<postsPath>/<name>')
      final existingMap = {
        for (var p in currentPosts)
          if (p.fileName != null)
            (p.filePath ?? '${config.postsPath}/${p.fileName}'): p
      };

      // Sync (only fetches changed files), surfacing progress so the
      // dashboard can show 'Syncing x of y'
      final posts = await contentService.syncPosts(
        config: config,
        existingPosts: existingMap,
        onProgress: (done, total) {
          state = PostsLoaded(
            posts: currentPosts,
            isRefreshing: true,
            lastSynced: _latestSync(currentPosts),
            syncDone: done,
            syncTotal: total,
          );
        },
      );

      final allPosts = [...posts];
      allPosts.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      // Save to cache
      final syncTime = DateTime.now();
      await _saveToCache(allPosts, syncTime);

      state = PostsLoaded(
        posts: allPosts,
        isRefreshing: false,
        lastSynced: syncTime,
      );
    } catch (e) {
      // On error, keep showing cached data but surface the failure
      if (currentPosts.isNotEmpty) {
        state = PostsLoaded(
          posts: currentPosts,
          isRefreshing: false,
          lastSynced: _latestSync(currentPosts),
          syncError: e.toString(),
        );
      } else {
        state = PostsError(e.toString(), currentPosts);
      }
    }
  }

  /// Clear all cached posts (used on logout / repository change)
  Future<void> clearAll() async {
    final box = ref.read(postsBoxProvider);
    await box.clear();
    state = const PostsInitial();
  }

  /// Update a post
  Future<void> updatePost(BlogPost post) async {
    final box = ref.read(postsBoxProvider);
    final key = _cacheKey(post);
    if (key != null) {
      await box.put(key, post);
    }

    final currentPosts = switch (state) {
      PostsLoaded(posts: final p) => p,
      _ => <BlogPost>[],
    };

    final index =
        key == null ? -1 : currentPosts.indexWhere((p) => _cacheKey(p) == key);
    if (index != -1) {
      currentPosts[index] = post;
      state = PostsLoaded(
        posts: List.from(currentPosts),
        lastSynced: DateTime.now(),
      );
    }
  }

  /// Remove a post from the cache and state (after it was deleted or
  /// moved on GitHub). The next sync would drop it anyway; this keeps
  /// the UI consistent immediately.
  Future<void> removePost(BlogPost post) async {
    final key = _cacheKey(post);
    if (key == null) return;

    final box = ref.read(postsBoxProvider);
    await box.delete(key);

    final currentPosts = switch (state) {
      PostsLoaded(posts: final p) => p,
      _ => <BlogPost>[],
    };
    final remaining =
        currentPosts.where((p) => _cacheKey(p) != key).toList();
    state = PostsLoaded(
      posts: remaining,
      lastSynced: _latestSync(remaining),
    );
  }
}

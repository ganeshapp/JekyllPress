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

  /// Non-null when the last refresh failed but cached posts are shown
  final String? syncError;

  const PostsLoaded({
    required this.posts,
    this.isRefreshing = false,
    this.lastSynced,
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

  /// Save posts to Hive cache, stamping each with the sync time.
  /// Entries are built first, then written with clear + putAll in one
  /// sequence to minimize the window for a partial cache.
  Future<void> _saveToCache(List<BlogPost> posts, DateTime syncTime) async {
    final box = ref.read(postsBoxProvider);
    final entries = <String, BlogPost>{};
    for (final post in posts) {
      if (post.fileName != null) {
        post.lastSynced = syncTime;
        entries[post.fileName!] = post;
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

      // Create map of existing posts for SHA comparison
      final existingMap = {
        for (var p in currentPosts)
          if (p.fileName != null) p.fileName!: p
      };

      // Sync (only fetches changed files)
      final posts = await contentService.syncPosts(
        config: config,
        existingPosts: existingMap,
      );

      // Include local drafts
      final localDrafts = currentPosts.where((p) => p.isLocalDraft).toList();
      final allPosts = [...localDrafts, ...posts];
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

  /// Add a new local draft
  Future<void> addDraft(BlogPost draft) async {
    final box = ref.read(postsBoxProvider);
    final key = 'draft_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, draft);
    
    final currentPosts = switch (state) {
      PostsLoaded(posts: final p) => p,
      _ => <BlogPost>[],
    };
    
    final allPosts = [draft, ...currentPosts];
    allPosts.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    
    state = PostsLoaded(
      posts: allPosts,
      lastSynced: DateTime.now(),
    );
  }

  /// Update a post
  Future<void> updatePost(BlogPost post) async {
    final box = ref.read(postsBoxProvider);
    if (post.fileName != null) {
      await box.put(post.fileName, post);
    }
    
    final currentPosts = switch (state) {
      PostsLoaded(posts: final p) => p,
      _ => <BlogPost>[],
    };
    
    final index = currentPosts.indexWhere((p) => p.fileName == post.fileName);
    if (index != -1) {
      currentPosts[index] = post;
      state = PostsLoaded(
        posts: List.from(currentPosts),
        lastSynced: DateTime.now(),
      );
    }
  }

  /// Delete a local draft
  Future<void> deleteDraft(BlogPost draft) async {
    if (!draft.isLocalDraft) return;
    
    await draft.delete();
    
    final currentPosts = switch (state) {
      PostsLoaded(posts: final p) => p,
      _ => <BlogPost>[],
    };
    
    currentPosts.removeWhere((p) => p.fileName == draft.fileName);
    state = PostsLoaded(
      posts: List.from(currentPosts),
      lastSynced: DateTime.now(),
    );
  }
}

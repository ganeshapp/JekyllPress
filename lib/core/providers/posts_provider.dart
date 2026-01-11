import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../services/content_service.dart';
import 'auth_provider.dart';
import 'config_provider.dart';

part 'posts_provider.g.dart';

/// Provider for ContentService
@riverpod
ContentService contentService(Ref ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ContentService(secureStorage: secureStorage);
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
  
  const PostsLoaded({
    required this.posts,
    this.isRefreshing = false,
    this.lastSynced,
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
  @override
  PostsState build() {
    // Load from cache first, then refresh
    _loadFromCacheAndRefresh();
    return const PostsInitial();
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

  /// Save posts to Hive cache
  Future<void> _saveToCache(List<BlogPost> posts) async {
    final box = ref.read(postsBoxProvider);
    await box.clear();
    for (final post in posts) {
      if (post.fileName != null) {
        await box.put(post.fileName, post);
      }
    }
  }

  /// Load from cache first, then background refresh
  Future<void> _loadFromCacheAndRefresh() async {
    final cachedPosts = _loadFromCache();
    
    if (cachedPosts.isNotEmpty) {
      // Show cached data immediately
      state = PostsLoaded(
        posts: cachedPosts,
        isRefreshing: true,
        lastSynced: cachedPosts.first.lastSynced,
      );
    } else {
      state = const PostsLoading();
    }

    // Background refresh from API
    await refresh();
  }

  /// Refresh posts from GitHub API
  Future<void> refresh() async {
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
        lastSynced: currentPosts.isNotEmpty ? currentPosts.first.lastSynced : null,
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
      await _saveToCache(allPosts);

      state = PostsLoaded(
        posts: allPosts,
        isRefreshing: false,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      // On error, keep showing cached data
      if (currentPosts.isNotEmpty) {
        state = PostsLoaded(
          posts: currentPosts,
          isRefreshing: false,
          lastSynced: currentPosts.first.lastSynced,
        );
      } else {
        state = PostsError(e.toString(), currentPosts);
      }
    }
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

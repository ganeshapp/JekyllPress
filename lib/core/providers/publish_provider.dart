import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../models/blog_post.dart';
import '../services/publish_service.dart';
import 'config_provider.dart';
import 'image_provider.dart';

part 'publish_provider.g.dart';

/// Provider for PublishService
@riverpod
PublishService publishService(Ref ref) {
  final uploadService = ref.watch(githubUploadServiceProvider);
  return PublishService(uploadService: uploadService);
}

/// State for publish operation
sealed class PublishState {
  const PublishState();
}

class PublishIdle extends PublishState {
  const PublishIdle();
}

class Publishing extends PublishState {
  final String message;
  const Publishing([this.message = 'Publishing...']);
}

class PublishSucceeded extends PublishState {
  final String filename;
  final String htmlUrl;
  const PublishSucceeded({required this.filename, required this.htmlUrl});
}

class PublishFailed extends PublishState {
  final String error;
  const PublishFailed(this.error);
}

/// Notifier for managing publish operations
@riverpod
class PublishNotifier extends _$PublishNotifier {
  @override
  PublishState build() {
    return const PublishIdle();
  }

  /// Get current app config
  AppConfig? get _config {
    final configState = ref.read(configNotifierProvider);
    return configState is ConfigLoaded ? configState.config : null;
  }

  /// Publish a new post. [publishDate]/[layout]/[categories]/[tags] come
  /// from the editor's Post settings sheet; null falls back to the config
  /// defaults, '' / empty list omits the key (see PublishService.createPost).
  Future<bool> publishNewPost({
    required String title,
    required String bodyContent,
    DateTime? publishDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
  }) async {
    final config = _config;
    if (config == null) {
      state = const PublishFailed('No repository configured');
      return false;
    }

    state = const Publishing('Creating post...');

    try {
      final publishService = ref.read(publishServiceProvider);
      final result = await publishService.createPost(
        config: config,
        title: title,
        bodyContent: bodyContent,
        publishDate: publishDate,
        layout: layout,
        categories: categories,
        tags: tags,
      );

      switch (result) {
        case PublishSuccess(filename: final f, htmlUrl: final url):
          state = PublishSucceeded(filename: f, htmlUrl: url);
          return true;
        case PublishFailure(message: final msg):
          state = PublishFailed(msg);
          return false;
      }
    } catch (e) {
      // Never let an exception escape to the async zone - surface it
      state = PublishFailed('Publish failed: $e');
      return false;
    }
  }

  /// Update an existing post. When all merge params are null the original
  /// front matter is preserved byte-exact; otherwise the sheet edits are
  /// merged into the modeled keys and unmodeled entries pass through
  /// verbatim (see PublishService.updatePost).
  Future<bool> publishUpdate({
    required BlogPost originalPost,
    required String newBodyContent,
    DateTime? publishDate,
    String? layout,
    List<String>? categories,
    List<String>? tags,
  }) async {
    final config = _config;
    if (config == null) {
      state = const PublishFailed('No repository configured');
      return false;
    }

    state = const Publishing('Updating post...');

    try {
      final publishService = ref.read(publishServiceProvider);
      final result = await publishService.updatePost(
        config: config,
        originalPost: originalPost,
        newBodyContent: newBodyContent,
        publishDate: publishDate,
        layout: layout,
        categories: categories,
        tags: tags,
      );

      switch (result) {
        case PublishSuccess(filename: final f, htmlUrl: final url):
          state = PublishSucceeded(filename: f, htmlUrl: url);
          return true;
        case PublishFailure(message: final msg):
          state = PublishFailed(msg);
          return false;
      }
    } catch (e) {
      // Never let an exception escape to the async zone - surface it
      state = PublishFailed('Publish failed: $e');
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const PublishIdle();
  }
}

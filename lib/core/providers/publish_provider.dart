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

  /// Publish a new post
  Future<bool> publishNewPost({
    required String title,
    required String bodyContent,
  }) async {
    final config = _config;
    if (config == null) {
      state = const PublishFailed('No repository configured');
      return false;
    }

    state = const Publishing('Creating post...');

    final publishService = ref.read(publishServiceProvider);
    final result = await publishService.createPost(
      config: config,
      title: title,
      bodyContent: bodyContent,
    );

    switch (result) {
      case PublishSuccess(filename: final f, htmlUrl: final url):
        state = PublishSucceeded(filename: f, htmlUrl: url);
        return true;
      case PublishFailure(message: final msg):
        state = PublishFailed(msg);
        return false;
    }
  }

  /// Update an existing post
  Future<bool> publishUpdate({
    required BlogPost originalPost,
    required String newBodyContent,
  }) async {
    final config = _config;
    if (config == null) {
      state = const PublishFailed('No repository configured');
      return false;
    }

    state = const Publishing('Updating post...');

    final publishService = ref.read(publishServiceProvider);
    final result = await publishService.updatePost(
      config: config,
      originalPost: originalPost,
      newBodyContent: newBodyContent,
    );

    switch (result) {
      case PublishSuccess(filename: final f, htmlUrl: final url):
        state = PublishSucceeded(filename: f, htmlUrl: url);
        return true;
      case PublishFailure(message: final msg):
        state = PublishFailed(msg);
        return false;
    }
  }

  /// Reset state
  void reset() {
    state = const PublishIdle();
  }
}

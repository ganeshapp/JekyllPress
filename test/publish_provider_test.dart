import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/models/blog_post.dart';
import 'package:jekyllpress/core/providers/image_provider.dart';
import 'package:jekyllpress/core/providers/posts_provider.dart';
import 'package:jekyllpress/core/providers/publish_provider.dart';
import 'package:jekyllpress/core/services/content_service.dart';
import 'package:jekyllpress/core/services/github_upload_service.dart';
import 'package:jekyllpress/core/services/publish_service.dart';

/// PublishService returning a scripted result without any network
class _FakePublishService extends PublishService {
  _FakePublishService(this.result)
      : super(uploadService: GitHubUploadService(dio: Dio()));

  final PublishResult result;

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
    return result;
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
    return result;
  }
}

/// Upload service with scripted existence/upload/delete behavior so the
/// promote flow can be exercised without any network
class _FakeUploadService extends GitHubUploadService {
  _FakeUploadService() : super(dio: Dio());

  bool targetExists = false;
  UploadResult uploadResult =
      const UploadSuccess(sha: 'sha_new', htmlUrl: 'https://x');
  DeleteResult deleteResult = const DeleteSuccess();
  final uploadedPaths = <String>[];
  final deletedPaths = <String>[];

  @override
  Future<bool> postExists({
    required AppConfig config,
    required String path,
  }) async {
    return targetExists;
  }

  @override
  Future<UploadResult> uploadPost({
    required AppConfig config,
    required String path,
    required String content,
    String? existingSha,
    String? commitMessage,
    bool force = false,
  }) async {
    uploadedPaths.add(path);
    return uploadResult;
  }

  @override
  Future<DeleteResult> deleteFile({
    required AppConfig config,
    required String path,
    required String sha,
    String? commitMessage,
  }) async {
    deletedPaths.add(path);
    return deleteResult;
  }
}

/// ContentService returning a scripted file body (the promote flow's
/// already-promoted check fetches the existing target)
class _FakeContentService extends ContentService {
  _FakeContentService() : super(dio: Dio());

  String fileContent = '';

  @override
  Future<String> fetchFileContent(AppConfig config, String path) async {
    return fileContent;
  }
}

BlogPost _post({
  String? filePath,
  String? rawFrontmatter,
  String date = '2024-03-05',
}) {
  return BlogPost(
    sha: 'sha_a',
    fileName: '2024-03-05-hello.md',
    filePath: filePath ?? '_posts/2024-03-05-hello.md',
    title: 'Hello',
    date: date,
    rawFrontmatter: rawFrontmatter,
    bodyContent: 'body',
  );
}

void main() {
  group('urlFieldsForUpdate', () {
    test('explicit sheet edits win over the front matter', () {
      final fields = urlFieldsForUpdate(
        originalPost: _post(
          rawFrontmatter: 'date: 2024-03-05 10:00:00 +0900\n'
              'categories: [old]',
        ),
        publishDate: DateTime(2026, 1, 2),
        categories: const ['new'],
      );

      expect(fields.date, DateTime(2026, 1, 2));
      expect(fields.categories, ['new']);
    });

    test('falls back to the original front matter', () {
      final fields = urlFieldsForUpdate(
        originalPost: _post(
          rawFrontmatter: 'date: 2024-03-05 10:00:00 +0900\n'
              'categories: [dev, notes]',
        ),
      );

      expect(fields.date.year, 2024);
      expect(fields.date.month, 3);
      expect(fields.date.day, 5);
      expect(fields.categories, ['dev', 'notes']);
    });

    test('falls back to the post date when there is no front matter', () {
      final fields = urlFieldsForUpdate(originalPost: _post());

      expect(fields.date, DateTime(2024, 3, 5));
      expect(fields.categories, isEmpty);
    });
  });

  group('PublishNotifier states', () {
    late Directory tempDir;
    late Box<AppConfig> configBox;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('publish_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AppConfigAdapter());
      }
      configBox = await Hive.openBox<AppConfig>('app_config');
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    Future<PublishNotifier> setupNotifier(
      PublishResult result, {
      String siteUrl = 'https://example.com',
      String permalink = '/blog/:title/',
    }) async {
      await configBox.put(
        'current_config',
        AppConfig(
          repoOwner: 'gapp',
          repoName: 'blog',
          siteUrl: siteUrl,
          permalinkPattern: permalink,
        ),
      );
      container = ProviderContainer(
        overrides: [
          publishServiceProvider
              .overrideWithValue(_FakePublishService(result)),
        ],
      );
      container.listen(publishNotifierProvider, (_, __) {});
      return container.read(publishNotifierProvider.notifier);
    }

    const success = PublishSuccess(
      sha: 'sha_new',
      filename: '2026-08-17-hello.md',
      filePath: '_posts/2026-08-17-hello.md',
      htmlUrl: 'https://github.com/x',
    );

    test('publishNewPost success carries the permalink-expanded publicUrl',
        () async {
      final notifier = await setupNotifier(success);

      final ok = await notifier.publishNewPost(
        title: 'Hello',
        bodyContent: 'body',
      );

      expect(ok, isTrue);
      final state = container.read(publishNotifierProvider);
      expect(state, isA<PublishSucceeded>());
      expect((state as PublishSucceeded).publicUrl,
          'https://example.com/blog/hello/');
    });

    test('saving a remote draft never links a public URL', () async {
      final notifier = await setupNotifier(success);

      await notifier.publishNewPost(
        title: 'Hello',
        bodyContent: 'body',
        asDraft: true,
      );

      final state =
          container.read(publishNotifierProvider) as PublishSucceeded;
      expect(state.publicUrl, isNull);
    });

    test('no configured site URL means no publicUrl', () async {
      final notifier = await setupNotifier(success, siteUrl: '');

      await notifier.publishNewPost(title: 'Hello', bodyContent: 'body');

      final state =
          container.read(publishNotifierProvider) as PublishSucceeded;
      expect(state.publicUrl, isNull);
    });

    test('publishUpdate success builds the URL from the original post',
        () async {
      final notifier = await setupNotifier(success);

      await notifier.publishUpdate(
        originalPost: _post(),
        newBodyContent: 'new body',
      );

      final state =
          container.read(publishNotifierProvider) as PublishSucceeded;
      expect(state.publicUrl, 'https://example.com/blog/hello/');
    });

    test('updating a file under the drafts dir has no publicUrl', () async {
      final notifier = await setupNotifier(success);

      await notifier.publishUpdate(
        originalPost: _post(filePath: '_drafts/hello.md'),
        newBodyContent: 'new body',
      );

      final state =
          container.read(publishNotifierProvider) as PublishSucceeded;
      expect(state.publicUrl, isNull);
    });

    test('failure kind is threaded onto PublishFailed', () async {
      final notifier = await setupNotifier(const PublishFailure(
        'This post changed on GitHub since it was loaded.',
        kind: PublishErrorKind.conflict,
      ));

      final ok = await notifier.publishUpdate(
        originalPost: _post(),
        newBodyContent: 'new body',
      );

      expect(ok, isFalse);
      final state = container.read(publishNotifierProvider);
      expect(state, isA<PublishFailed>());
      expect((state as PublishFailed).kind, PublishErrorKind.conflict);
    });

    test('offline failures read as PublishErrorKind.offline', () async {
      final notifier = await setupNotifier(const PublishFailure(
        'No internet connection',
        kind: PublishErrorKind.offline,
      ));

      await notifier.publishNewPost(title: 'Hello', bodyContent: 'body');

      final state = container.read(publishNotifierProvider) as PublishFailed;
      expect(state.kind, PublishErrorKind.offline);
    });
  });

  group('PublishNotifier.promoteRemoteDraft', () {
    late Directory tempDir;
    late Box<AppConfig> configBox;
    late ProviderContainer container;
    late _FakeUploadService upload;
    late _FakeContentService content;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('promote_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AppConfigAdapter());
      }
      configBox = await Hive.openBox<AppConfig>('app_config');
      await configBox.put(
        'current_config',
        AppConfig(repoOwner: 'gapp', repoName: 'blog'),
      );

      upload = _FakeUploadService();
      content = _FakeContentService();
      container = ProviderContainer(
        overrides: [
          githubUploadServiceProvider.overrideWithValue(upload),
          contentServiceProvider.overrideWithValue(content),
        ],
      );
      container.listen(publishNotifierProvider, (_, __) {});
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    BlogPost draft() => BlogPost(
          sha: 'sha_draft',
          fileName: 'my-idea.md',
          filePath: '_drafts/my-idea.md',
          title: 'My idea',
          date: '',
          rawFrontmatter: 'title: My idea',
          bodyContent: 'draft body',
        );

    test('creates the post first, then deletes the old draft', () async {
      final error = await container
          .read(publishNotifierProvider.notifier)
          .promoteRemoteDraft(draft());

      expect(error, isNull);
      expect(upload.uploadedPaths, hasLength(1));
      expect(upload.uploadedPaths.single, startsWith('_posts/'));
      expect(upload.uploadedPaths.single, endsWith('-my-idea.md'));
      expect(upload.deletedPaths, ['_drafts/my-idea.md']);
    });

    test('retry after a failed delete detects the already-created target: '
        'skips the create and just removes the old draft', () async {
      upload.targetExists = true;
      content.fileContent = '---\ntitle: My idea\n'
          'date: 2026-08-17 09:00:00 +0900\n---\n\ndraft body';

      final error = await container
          .read(publishNotifierProvider.notifier)
          .promoteRemoteDraft(draft());

      expect(error, isNull);
      expect(upload.uploadedPaths, isEmpty,
          reason: 'the target already holds this draft - no second create');
      expect(upload.deletedPaths, ['_drafts/my-idea.md']);
    });

    test('an unrelated file at the target path still blocks the promote',
        () async {
      upload.targetExists = true;
      content.fileContent =
          '---\ntitle: Something else\n---\n\ncompletely different body';

      final error = await container
          .read(publishNotifierProvider.notifier)
          .promoteRemoteDraft(draft());

      expect(error, contains('already exists'));
      expect(upload.uploadedPaths, isEmpty);
      expect(upload.deletedPaths, isEmpty);
    });

    test('a failed delete after a successful create names the new path',
        () async {
      upload.deleteResult = const DeleteFailure('Permission denied: nope');

      final error = await container
          .read(publishNotifierProvider.notifier)
          .promoteRemoteDraft(draft());

      expect(error, isNotNull);
      expect(error, contains('could not be removed'));
      expect(error, contains('_posts/'));
      expect(upload.uploadedPaths, hasLength(1));
    });
  });
}

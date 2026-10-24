import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/models/local_draft.dart';
import 'package:jekyllpress/core/providers/drafts_provider.dart';
import 'package:jekyllpress/core/providers/editor_provider.dart';
import 'package:jekyllpress/core/providers/image_provider.dart';
import 'package:jekyllpress/core/services/github_upload_service.dart';
import 'package:jekyllpress/core/services/publish_service.dart';
import 'fakes.dart';

class _Uploads extends GitHubUploadService {
  _Uploads() : super(dio: offlineDio());
  final files = <String, String>{};
  bool loseResponse = true;
  int mediaUploads = 0;
  @override
  Future<bool> postExists({
    required AppConfig config,
    required String path,
  }) async => files.containsKey(path);
  @override
  Future<UploadResult> uploadPost({
    required AppConfig config,
    required String path,
    required String content,
    String? existingSha,
    String? commitMessage,
    bool force = false,
  }) async {
    if (files.containsKey(path) && !force) {
      return const UploadFailure('Already exists');
    }
    files[path] = content;
    if (loseResponse) {
      loseResponse = false;
      return const UploadFailure(
        'Response lost',
        kind: PublishErrorKind.offline,
      );
    }
    return const UploadSuccess(sha: 'blob', htmlUrl: 'https://github.com/file');
  }

  @override
  Future<UploadResult> uploadImage({
    required AppConfig config,
    required File file,
    required String filename,
    String? commitMessage,
  }) async {
    mediaUploads++;
    return const UploadSuccess(
      sha: 'media',
      htmlUrl: 'https://github.com/image',
    );
  }
}

void main() {
  late Directory dir;
  late Box<Map> journal;
  late ProviderContainer container;
  final config = AppConfig(
    repoOwner: 'me',
    repoName: 'blog',
    activeContentDir: '_wiki',
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('publish_recovery');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AppConfigAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(LocalDraftAdapter());
    await (await Hive.openBox<AppConfig>(
      'app_config',
    )).put('current_config', config.copyWith());
    await Hive.openBox<LocalDraft>('drafts_box');
    await Hive.openBox<String>('local_image_map');
    journal = await Hive.openBox<Map>('publishing_state');
    container = ProviderContainer();
  });
  tearDown(() async {
    container.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'settings-only edits and explicitly cleared lists survive a Hive restart',
    () async {
      final draftSub = container.listen(
        currentDraftNotifierProvider,
        (_, __) {},
      );
      final editorSub = container.listen(editorControllerProvider, (_, __) {});
      final drafts = container.read(currentDraftNotifierProvider.notifier);
      final editor = container.read(editorControllerProvider.notifier);
      drafts.initializeWithDraft(
        LocalDraft.newDraft(id: 'draft', title: 'Trip', bodyContent: 'Body'),
      );
      editor.initializeNewPost(
        defaultLayout: 'post',
        defaultCategories: ['travel'],
      );
      editor.updatePublishDate(DateTime(2026, 1, 2));
      editor.updateLayout('');
      editor.updateCategories([]);
      editor.updateTags(['seoul']);
      await drafts.forceSave(
        title: 'Trip',
        bodyContent: 'Body',
        settings: container.read(editorControllerProvider),
      );
      draftSub.close();
      editorSub.close();
      container.dispose();
      await Hive.box<LocalDraft>('drafts_box').close();
      final box = await Hive.openBox<LocalDraft>('drafts_box');
      final restored = box.get('draft')!;
      container = ProviderContainer();
      final resumed = container.read(editorControllerProvider.notifier);
      resumed.initializeWithDraft(
        title: restored.title,
        bodyContent: restored.bodyContent,
        savedDraft: restored,
        defaultLayout: 'post',
        defaultCategories: ['travel'],
      );
      final state = container.read(editorControllerProvider);
      expect(state.publishDate, DateTime(2026, 1, 2));
      expect(state.layout, '');
      expect(state.categories, isEmpty);
      expect(state.tags, ['seoul']);
      expect(state.frontmatterEdited, isTrue);
    },
  );

  test(
    'response lost after create retries one destination after restart, even after edits',
    () async {
      final uploads = _Uploads();
      var publisher = PublishService(uploadService: uploads, attempts: journal);
      expect(
        await publisher.createPost(
          config: config,
          attemptId: 'draft-1',
          title: 'Trip',
          bodyContent: 'first',
        ),
        isA<PublishFailure>(),
      );
      await journal.close();
      journal = await Hive.openBox<Map>('publishing_state');
      publisher = PublishService(uploadService: uploads, attempts: journal);
      expect(
        await publisher.createPost(
          config: config,
          attemptId: 'draft-1',
          title: 'Trip',
          bodyContent: 'edited',
        ),
        isA<PublishSuccess>(),
      );
      expect(uploads.files.keys, ['_wiki/trip.md']);
      expect(uploads.files.values.single, contains('edited'));
      // A deliberately new draft with the same title still gets its own filename.
      await publisher.createPost(
        config: config,
        attemptId: 'draft-2',
        title: 'Trip',
        bodyContent: 'new',
      );
      expect(uploads.files.keys, ['_wiki/trip.md', '_wiki/trip-2.md']);
    },
  );

  test(
    'pending media survives restart and is uploaded before queued text; completed media stays completed',
    () async {
      final file = await File('${dir.path}/photo.jpg').writeAsBytes([1, 2, 3]);
      await Hive.box<String>('local_image_map').put('photo.jpg', file.path);
      await journal.put('media:photo.jpg', {'uploaded': false});
      await journal.close();
      journal = await Hive.openBox<Map>('publishing_state');
      final uploads = _Uploads();
      container.dispose();
      container = ProviderContainer(
        overrides: [githubUploadServiceProvider.overrideWithValue(uploads)],
      );
      expect(
        container.read(imageManagerProvider)['photo.jpg']!.isUploaded,
        isFalse,
      );
      expect(
        await container
            .read(imageManagerProvider.notifier)
            .ensureUploaded('![x](/photo.jpg)'),
        isNull,
      );
      expect(uploads.mediaUploads, 1);
      container.dispose();
      container = ProviderContainer(
        overrides: [githubUploadServiceProvider.overrideWithValue(uploads)],
      );
      expect(
        container.read(imageManagerProvider)['photo.jpg']!.isUploaded,
        isTrue,
      );
      await container
          .read(imageManagerProvider.notifier)
          .ensureUploaded('![x](/photo.jpg)');
      expect(uploads.mediaUploads, 1);
    },
  );
}

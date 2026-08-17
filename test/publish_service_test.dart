import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/models/blog_post.dart';
import 'package:jekyllpress/core/services/github_upload_service.dart';
import 'package:jekyllpress/core/services/publish_service.dart';

/// Upload service with scripted existence checks and captured uploads
class _FakeUploadService extends GitHubUploadService {
  _FakeUploadService() : super(dio: Dio());

  /// Paths that report "already exists"
  Set<String> takenPaths = {};

  final List<String> existenceChecks = [];
  String? uploadedPath;
  String? uploadedContent;
  String? uploadedCommitMessage;
  String? uploadedExistingSha;
  bool? uploadedForce;

  @override
  Future<bool> postExists({
    required AppConfig config,
    required String path,
  }) async {
    existenceChecks.add(path);
    return takenPaths.contains(path);
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
    uploadedPath = path;
    uploadedContent = content;
    uploadedCommitMessage = commitMessage;
    uploadedExistingSha = existingSha;
    uploadedForce = force;
    return const UploadSuccess(sha: 'new_sha', htmlUrl: 'https://x');
  }
}

String _todayStr() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

void main() {
  late _FakeUploadService uploads;
  late PublishService service;

  setUp(() {
    uploads = _FakeUploadService();
    service = PublishService(uploadService: uploads);
  });

  group('PublishService.usesDatePrefixedFilenames', () {
    test('true only when the last segment is _posts', () {
      expect(PublishService.usesDatePrefixedFilenames('_posts'), isTrue);
      expect(PublishService.usesDatePrefixedFilenames('docs/_posts'), isTrue);
      expect(PublishService.usesDatePrefixedFilenames('/_posts/'), isTrue);
      expect(PublishService.usesDatePrefixedFilenames('_wiki'), isFalse);
      expect(PublishService.usesDatePrefixedFilenames('_drafts'), isFalse);
      expect(PublishService.usesDatePrefixedFilenames('_posts/2024'), isFalse);
      expect(PublishService.usesDatePrefixedFilenames('_postsx'), isFalse);
      expect(PublishService.usesDatePrefixedFilenames(''), isFalse);
    });
  });

  group('PublishService.createPost paths', () {
    test('active _posts dir gets a date-prefixed filename', () async {
      final result = await service.createPost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        title: 'Hello World',
        bodyContent: 'body',
      );

      expect(result, isA<PublishSuccess>());
      final success = result as PublishSuccess;
      expect(uploads.uploadedPath, '_posts/${_todayStr()}-hello-world.md');
      expect(success.filePath, uploads.uploadedPath);
      expect(success.filename, '${_todayStr()}-hello-world.md');
    });

    test('nested docs/_posts dir also gets the date prefix', () async {
      await service.createPost(
        config: AppConfig(
          repoOwner: 'o',
          repoName: 'r',
          postsPath: 'docs/_posts',
        ),
        title: 'Hello World',
        bodyContent: 'body',
      );

      expect(
          uploads.uploadedPath, 'docs/_posts/${_todayStr()}-hello-world.md');
    });

    test('collection dir gets a plain slug filename', () async {
      await service.createPost(
        config: AppConfig(
          repoOwner: 'o',
          repoName: 'r',
          contentDirs: ['_posts', '_wiki'],
          activeContentDir: '_wiki',
        ),
        title: 'Hello World',
        bodyContent: 'body',
      );

      expect(uploads.uploadedPath, '_wiki/hello-world.md');
    });

    test('asDraft targets draftsPath with a plain slug filename '
        '(even when a collection dir is active) and keeps the date '
        'front matter', () async {
      await service.createPost(
        config: AppConfig(
          repoOwner: 'o',
          repoName: 'r',
          activeContentDir: '_wiki',
        ),
        title: 'Hello World',
        bodyContent: 'body',
        asDraft: true,
      );

      expect(uploads.uploadedPath, '_drafts/hello-world.md');
      expect(uploads.uploadedCommitMessage, 'Create draft: Hello World');
      expect(uploads.uploadedContent, contains('date: '));
    });

    test('taken path is suffixed and checks run against the target dir',
        () async {
      final today = _todayStr();
      uploads.takenPaths = {'_posts/$today-hello.md'};

      final result = await service.createPost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        title: 'Hello',
        bodyContent: 'body',
      );

      expect(uploads.existenceChecks.first, '_posts/$today-hello.md');
      expect(uploads.uploadedPath, '_posts/$today-hello-2.md');
      expect((result as PublishSuccess).filename, '$today-hello-2.md');
    });

    test('minimal front matter by default; configured layout/categories/'
        'tags are emitted', () async {
      await service.createPost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        title: 'Plain',
        bodyContent: 'body',
      );
      expect(uploads.uploadedContent, isNot(contains('layout:')));
      expect(uploads.uploadedContent, isNot(contains('categories:')));
      expect(uploads.uploadedContent, isNot(contains('tags:')));

      await service.createPost(
        config: AppConfig(
          repoOwner: 'o',
          repoName: 'r',
          defaultLayout: 'single',
          defaultCategories: ['blog'],
          defaultTags: ['dev', 'notes'],
        ),
        title: 'Decorated',
        bodyContent: 'body',
      );
      expect(uploads.uploadedContent, contains('layout: single'));
      expect(uploads.uploadedContent, contains('categories: [blog]'));
      expect(uploads.uploadedContent, contains('tags: [dev, notes]'));
    });

    test('explicit publishDate drives the filename prefix and the front '
        'matter date', () async {
      final chosen = DateTime(2024, 12, 31, 23, 45, 10);
      await service.createPost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        title: 'Countdown',
        bodyContent: 'body',
        publishDate: chosen,
      );

      expect(uploads.uploadedPath, '_posts/2024-12-31-countdown.md');
      expect(uploads.uploadedContent,
          contains('date: ${PublishService.formatJekyllDate(chosen)}'));
    });

    test('sheet values override config defaults; cleared values omit '
        'the keys', () async {
      final config = AppConfig(
        repoOwner: 'o',
        repoName: 'r',
        defaultLayout: 'single',
        defaultCategories: ['blog'],
        defaultTags: ['dev'],
      );

      // Explicit values win over config defaults
      await service.createPost(
        config: config,
        title: 'Override',
        bodyContent: 'body',
        layout: 'wide',
        categories: ['essays'],
        tags: ['a', 'b'],
      );
      expect(uploads.uploadedContent, contains('layout: wide'));
      expect(uploads.uploadedContent, contains('categories: [essays]'));
      expect(uploads.uploadedContent, contains('tags: [a, b]'));

      // Cleared values ('' / empty list) omit the keys despite defaults
      await service.createPost(
        config: config,
        title: 'Cleared',
        bodyContent: 'body',
        layout: '',
        categories: const [],
        tags: const [],
      );
      expect(uploads.uploadedContent, isNot(contains('layout:')));
      expect(uploads.uploadedContent, isNot(contains('categories:')));
      expect(uploads.uploadedContent, isNot(contains('tags:')));
    });
  });

  group('PublishService.updatePost paths', () {
    BlogPost post({String? filePath}) => BlogPost(
          sha: 'old_sha',
          fileName: '2024-01-01-old.md',
          filePath: filePath,
          title: 'Old',
          date: '2024-01-01',
          rawFrontmatter: 'title: "Old"\ndate: 2024-01-01',
          bodyContent: 'old body',
        );

    test('uses the post\'s own filePath when present', () async {
      final result = await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: post(filePath: '_posts/2024/2024-01-01-old.md'),
        newBodyContent: 'new body',
      );

      expect(uploads.uploadedPath, '_posts/2024/2024-01-01-old.md');
      expect(uploads.uploadedExistingSha, 'old_sha');
      expect((result as PublishSuccess).filePath,
          '_posts/2024/2024-01-01-old.md');
    });

    test('falls back to <postsPath>/<fileName> for v1 records', () async {
      await service.updatePost(
        config: AppConfig(
          repoOwner: 'o',
          repoName: 'r',
          postsPath: 'docs/_posts',
        ),
        originalPost: post(),
        newBodyContent: 'new body',
      );

      expect(uploads.uploadedPath, 'docs/_posts/2024-01-01-old.md');
    });

    test('force (conflict overwrite) threads through to the upload',
        () async {
      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: post(filePath: '_posts/2024-01-01-old.md'),
        newBodyContent: 'new body',
        force: true,
      );
      expect(uploads.uploadedForce, isTrue);

      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: post(filePath: '_posts/2024-01-01-old.md'),
        newBodyContent: 'new body',
      );
      expect(uploads.uploadedForce, isFalse);
    });
  });

  group('PublishService.updatePost front matter merge', () {
    // Realistic front matter with custom fields the merge must never touch
    const raw = 'title: "Old"\n'
        'date: 2024-01-01 08:00:00 +0900\n'
        'layout: single\n'
        'categories: [blog]\n'
        'tags:\n'
        '  - old-tag\n'
        'header:\n'
        '  overlay_image: /assets/hero.jpg\n'
        'toc: true';

    BlogPost post() => BlogPost(
          sha: 'old_sha',
          fileName: '2024-01-01-old.md',
          filePath: '_posts/2024-01-01-old.md',
          title: 'Old',
          date: '2024-01-01',
          rawFrontmatter: raw,
          bodyContent: 'old body',
        );

    test('no merge params: original front matter is re-emitted byte-exact',
        () async {
      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: post(),
        newBodyContent: 'new body',
      );

      expect(uploads.uploadedContent, '---\n$raw\n---\nnew body');
    });

    test('date edit changes the front matter date but NEVER the filename',
        () async {
      final newDate = DateTime(2025, 6, 1, 12, 0, 0);
      final result = await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: post(),
        newBodyContent: 'new body',
        publishDate: newDate,
      );

      // Path and filename are untouched
      expect(uploads.uploadedPath, '_posts/2024-01-01-old.md');
      expect((result as PublishSuccess).filename, '2024-01-01-old.md');

      // Date line replaced with the chosen timestamp
      expect(uploads.uploadedContent,
          contains('date: ${PublishService.formatJekyllDate(newDate)}'));
      expect(uploads.uploadedContent,
          isNot(contains('2024-01-01 08:00:00 +0900')));

      // Untouched modeled keys and custom fields survive
      expect(uploads.uploadedContent, contains('title: "Old"'));
      expect(uploads.uploadedContent, contains('layout: single'));
      expect(uploads.uploadedContent, contains('categories: [blog]'));
      expect(uploads.uploadedContent, contains('tags: [old-tag]'));
      expect(
        uploads.uploadedContent,
        contains('header:\n  overlay_image: /assets/hero.jpg\ntoc: true'),
      );
    });

    test('merge keeps the original date verbatim when only other keys '
        'change', () async {
      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: post(),
        newBodyContent: 'new body',
        tags: const ['fresh'],
      );

      expect(uploads.uploadedContent,
          contains('date: 2024-01-01 08:00:00 +0900'));
      expect(uploads.uploadedContent, contains('tags: [fresh]'));
      expect(uploads.uploadedContent, isNot(contains('old-tag')));
    });

    test('cleared layout/categories remove the keys; passthrough is '
        'preserved verbatim', () async {
      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: post(),
        newBodyContent: 'new body',
        layout: '',
        categories: const [],
      );

      expect(uploads.uploadedContent, isNot(contains('layout:')));
      expect(uploads.uploadedContent, isNot(contains('categories:')));
      // Unedited modeled keys keep their parsed values
      expect(uploads.uploadedContent, contains('tags: [old-tag]'));
      expect(
        uploads.uploadedContent,
        contains('header:\n  overlay_image: /assets/hero.jpg\ntoc: true'),
      );
    });

    test('editing a key the parser kept in passthrough (un-understood '
        'form) replaces it instead of emitting a duplicate', () async {
      // 'categories' here is an unterminated flow list, so parseFields
      // cannot lift it and keeps the raw line in passthrough
      final weird = BlogPost(
        sha: 'old_sha',
        fileName: '2024-01-01-old.md',
        filePath: '_posts/2024-01-01-old.md',
        title: 'Old',
        date: '2024-01-01',
        rawFrontmatter: 'title: "Old"\n'
            'date: 2024-01-01 08:00:00 +0900\n'
            'categories: ["a, b\n'
            'toc: true',
        bodyContent: 'old body',
      );

      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: weird,
        newBodyContent: 'new body',
        categories: const ['blog'],
      );

      final content = uploads.uploadedContent!;
      // Exactly one categories key: the user's edit, not the stale block
      expect('categories:'.allMatches(content).length, 1);
      expect(content, contains('categories: [blog]'));
      expect(content, isNot(contains('categories: ["a, b')));
      // Untouched passthrough still survives verbatim
      expect(content, contains('toc: true'));
    });

    test('untouched passthrough-form keys still pass through when other '
        'keys are edited', () async {
      final weird = BlogPost(
        sha: 'old_sha',
        fileName: '2024-01-01-old.md',
        filePath: '_posts/2024-01-01-old.md',
        title: 'Old',
        date: '2024-01-01',
        rawFrontmatter: 'title: "Old"\n'
            'categories: ["a, b\n'
            'toc: true',
        bodyContent: 'old body',
      );

      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: weird,
        newBodyContent: 'new body',
        tags: const ['t'],
      );

      final content = uploads.uploadedContent!;
      // categories was NOT edited: its raw un-understood block survives
      expect(content, contains('categories: ["a, b'));
      expect(content, contains('tags: [t]'));
      expect(content, contains('toc: true'));
    });

    test('merge on a post whose front matter has no title key does not '
        'invent one', () async {
      final noTitle = BlogPost(
        sha: 'old_sha',
        fileName: '2024-01-01-old.md',
        filePath: '_posts/2024-01-01-old.md',
        title: 'Heading Derived',
        date: '2024-01-01',
        rawFrontmatter: 'layout: single',
        bodyContent: '# Heading Derived\n\nbody',
      );

      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: noTitle,
        newBodyContent: 'new body',
        tags: const ['t'],
      );

      expect(uploads.uploadedContent, isNot(contains('title:')));
      expect(uploads.uploadedContent, contains('layout: single'));
      expect(uploads.uploadedContent, contains('tags: [t]'));
    });

    test('merge on a post without any front matter regenerates the '
        'minimal title + date plus the edits', () async {
      final bare = BlogPost(
        sha: 'old_sha',
        fileName: '2024-01-01-old.md',
        filePath: '_posts/2024-01-01-old.md',
        title: 'Bare',
        date: '2024-01-01',
        bodyContent: 'body',
      );

      await service.updatePost(
        config: AppConfig(repoOwner: 'o', repoName: 'r'),
        originalPost: bare,
        newBodyContent: 'new body',
        categories: const ['c'],
      );

      expect(uploads.uploadedContent, contains('title: "Bare"'));
      expect(uploads.uploadedContent, contains('date: 2024-01-01'));
      expect(uploads.uploadedContent, contains('categories: [c]'));
    });
  });
}

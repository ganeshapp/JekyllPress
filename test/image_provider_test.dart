import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/providers/image_provider.dart';

void main() {
  group('normalizeBaseurl', () {
    test('empty, slash-only, and whitespace collapse to empty', () {
      expect(normalizeBaseurl(''), '');
      expect(normalizeBaseurl('/'), '');
      expect(normalizeBaseurl('  '), '');
    });

    test('leading slash is added, trailing slash removed', () {
      expect(normalizeBaseurl('myrepo'), '/myrepo');
      expect(normalizeBaseurl('/myrepo'), '/myrepo');
      expect(normalizeBaseurl('/myrepo/'), '/myrepo');
    });
  });

  group('stripBaseurl', () {
    test('no-op when baseurl is empty', () {
      expect(stripBaseurl('/assets/x.jpg', ''), '/assets/x.jpg');
    });

    test('strips the prefix only when it matches a whole segment', () {
      expect(stripBaseurl('/myrepo/assets/x.jpg', '/myrepo'), '/assets/x.jpg');
      expect(stripBaseurl('/myrepofake/assets/x.jpg', '/myrepo'),
          '/myrepofake/assets/x.jpg');
      expect(stripBaseurl('/assets/x.jpg', '/myrepo'), '/assets/x.jpg');
    });
  });

  group('image providers with config', () {
    late Directory tempDir;
    late Box<AppConfig> configBox;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('image_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AppConfigAdapter());
      }
      configBox = await Hive.openBox<AppConfig>('app_config');
      await Hive.openBox<String>('local_image_map');
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    Future<void> putConfig({required String baseurl}) async {
      await configBox.put(
        'current_config',
        AppConfig(
          repoOwner: 'gapp',
          repoName: 'blog',
          branch: 'main',
          baseurl: baseurl,
        ),
      );
    }

    group('ImageManager.generateMarkdownImage', () {
      test('root site (baseurl "") emits a root-relative URL', () async {
        await putConfig(baseurl: '');

        final markdown = container
            .read(imageManagerProvider.notifier)
            .generateMarkdownImage('img_1.jpg');

        expect(markdown, '![image](/assets/images/img_1.jpg)');
      });

      test('project site (baseurl "/myrepo") prefixes the baseurl', () async {
        await putConfig(baseurl: '/myrepo');

        final markdown = container
            .read(imageManagerProvider.notifier)
            .generateMarkdownImage('img_1.jpg', alt: 'photo');

        expect(markdown, '![photo](/myrepo/assets/images/img_1.jpg)');
      });
    });

    group('ImageResolver.resolveImagePath', () {
      test('baseurl "" maps straight to the raw URL on the branch', () async {
        await putConfig(baseurl: '');

        final (isLocal, url) = container
            .read(imageResolverProvider.notifier)
            .resolveImagePath('/assets/images/img_1.jpg');

        expect(isLocal, isFalse);
        expect(
            url,
            'https://raw.githubusercontent.com/gapp/blog/main/'
            'assets/images/img_1.jpg');
      });

      test('baseurl "/myrepo" is stripped before mapping to the raw URL',
          () async {
        await putConfig(baseurl: '/myrepo');

        final (isLocal, url) = container
            .read(imageResolverProvider.notifier)
            .resolveImagePath('/myrepo/assets/images/img_1.jpg');

        expect(isLocal, isFalse);
        expect(
            url,
            'https://raw.githubusercontent.com/gapp/blog/main/'
            'assets/images/img_1.jpg');
      });
    });
  });
}

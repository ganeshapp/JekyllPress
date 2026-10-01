import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/providers/image_provider.dart';
import 'package:jekyllpress/core/utils/youtube.dart';

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

  group('preprocessPreviewMarkdown', () {
    test('replaces a div-wrapped video block with a placeholder image', () {
      const markdown = 'Before\n\n'
          '<div style="text-align: center;">\n'
          '  <video autoplay loop muted playsinline controls '
          'style="max-width: 100%; border-radius: 12px;">\n'
          '    <source src="/assets/images/vid_20260817_120000_123.mp4" '
          'type="video/mp4">\n'
          '  </video>\n'
          '</div>\n\nAfter';

      expect(
        preprocessPreviewMarkdown(markdown),
        'Before\n\n'
        '![video](jekyllpress-video:/vid_20260817_120000_123.mp4)\n\n'
        'After',
      );
    });

    test('replaces a bare video block (no wrapping div)', () {
      const markdown = '<video controls>\n'
          '  <source src="/assets/images/vid_1.mp4" type="video/mp4">\n'
          '</video>';

      expect(
        preprocessPreviewMarkdown(markdown),
        '![video](jekyllpress-video:/vid_1.mp4)',
      );
    });

    test('preserves filename case (owner-style uppercase names)', () {
      const markdown = '<div style="text-align: center;">\n'
          '  <video autoplay loop muted playsinline controls '
          'style="max-width: 300px; border-radius: 12px;">\n'
          '    <source src="/assets/images/VID-20260222-WA0001.mp4" '
          'type="video/mp4">\n'
          '  </video>\n'
          '</div>';

      expect(
        preprocessPreviewMarkdown(markdown),
        '![video](jekyllpress-video:/VID-20260222-WA0001.mp4)',
      );
    });

    test('replaces every video block independently', () {
      const markdown = '<video><source src="/a/one.mp4"></video>\n\n'
          'middle\n\n'
          '<video><source src="/a/two.mp4"></video>';

      expect(
        preprocessPreviewMarkdown(markdown),
        '![video](jekyllpress-video:/one.mp4)\n\n'
        'middle\n\n'
        '![video](jekyllpress-video:/two.mp4)',
      );
    });

    test('leaves markdown without video blocks untouched', () {
      const markdown = '# Title\n\nSome *text* and ![img](/assets/x.jpg)\n\n'
          '<div>plain html without video</div>';
      expect(preprocessPreviewMarkdown(markdown), markdown);
    });

    test('replaces generated YouTube embeds with a placeholder', () {
      final regular =
          youTubeEmbed((id: 'dQw4w9WgXcQ', isShort: false, start: 90));
      final short =
          youTubeEmbed((id: 'aBcDeFgHiJk', isShort: true, start: null));

      expect(
        preprocessPreviewMarkdown('intro\n\n$regular\n\nmiddle\n\n$short'),
        'intro\n\n![youtube](jekyllpress-video:/dQw4w9WgXcQ)\n\n'
        'middle\n\n![youtube](jekyllpress-video:/aBcDeFgHiJk)',
      );
    });

    test("replaces YouTube's own embed code with a placeholder", () {
      const markdown = '<iframe width="560" height="315" '
          'src="https://www.youtube.com/embed/dQw4w9WgXcQ?si=AbCdEf&amp;start=42" '
          'title="YouTube video player" frameborder="0" '
          'allow="accelerometer; autoplay; clipboard-write; encrypted-media; '
          'gyroscope; picture-in-picture; web-share" '
          'referrerpolicy="strict-origin-when-cross-origin" '
          'allowfullscreen></iframe>';

      expect(
        preprocessPreviewMarkdown(markdown),
        '![youtube](jekyllpress-video:/dQw4w9WgXcQ)',
      );
    });

    test('leaves other iframes untouched', () {
      const markdown = '<div class="map">\n'
          '  <iframe src="https://www.google.com/maps/embed?pb=1"></iframe>\n'
          '  <iframe src="https://example.com/caf%E9/embed"></iframe>\n'
          '</div>';
      expect(preprocessPreviewMarkdown(markdown), markdown);
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

    group('ImageManager.generateVideoEmbed', () {
      test('root site (baseurl "") emits a root-relative src', () async {
        await putConfig(baseurl: '');

        final embed = container
            .read(imageManagerProvider.notifier)
            .generateVideoEmbed('vid_1.mp4');

        expect(
          embed,
          '<div style="text-align: center;">\n'
          '  <video autoplay loop muted playsinline controls '
          'style="max-width: 100%; border-radius: 12px;">\n'
          '    <source src="/assets/images/vid_1.mp4" type="video/mp4">\n'
          '  </video>\n'
          '</div>',
        );
      });

      test('project site (baseurl "/myrepo") prefixes the baseurl', () async {
        await putConfig(baseurl: '/myrepo');

        final embed = container
            .read(imageManagerProvider.notifier)
            .generateVideoEmbed('vid_1.mp4');

        expect(
          embed,
          contains('src="/myrepo/assets/images/vid_1.mp4"'),
        );
      });

      test('round-trips through preprocessPreviewMarkdown', () async {
        await putConfig(baseurl: '/myrepo');

        final embed = container
            .read(imageManagerProvider.notifier)
            .generateVideoEmbed('vid_1.mp4');

        expect(
          preprocessPreviewMarkdown('intro\n\n$embed\n\noutro'),
          'intro\n\n![video](jekyllpress-video:/vid_1.mp4)\n\noutro',
        );
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

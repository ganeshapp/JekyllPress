import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/providers/config_provider.dart';

void main() {
  group('inferPagesSite', () {
    test('user/org site repo maps to the domain root with empty baseurl', () {
      final inferred =
          inferPagesSite(repoOwner: 'gapp', repoName: 'gapp.github.io');
      expect(inferred.siteUrl, 'https://gapp.github.io');
      expect(inferred.baseurl, '');
    });

    test('matching is case-insensitive but the host is lowercase', () {
      final inferred =
          inferPagesSite(repoOwner: 'GaneshApp', repoName: 'GaneshApp.github.io');
      expect(inferred.siteUrl, 'https://ganeshapp.github.io');
      expect(inferred.baseurl, '');
    });

    test('project repo maps to /<repo> with baseurl /<repo>', () {
      final inferred = inferPagesSite(repoOwner: 'gapp', repoName: 'notes');
      expect(inferred.siteUrl, 'https://gapp.github.io/notes');
      expect(inferred.baseurl, '/notes');
    });

    test('another owner\'s .github.io repo name is still a project site', () {
      final inferred =
          inferPagesSite(repoOwner: 'gapp', repoName: 'other.github.io');
      expect(inferred.siteUrl, 'https://gapp.github.io/other.github.io');
      expect(inferred.baseurl, '/other.github.io');
    });
  });

  group('ConfigNotifier.saveConfig', () {
    late Directory tempDir;
    late Box<AppConfig> configBox;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('config_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(AppConfigAdapter());
      }
      configBox = await Hive.openBox<AppConfig>('app_config');
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('empty siteUrl is inferred (project site)', () async {
      await container.read(configNotifierProvider.notifier).saveConfig(
            repoOwner: 'gapp',
            repoName: 'notes',
            branch: 'main',
            assetsPath: 'assets/images',
          );

      final config = configBox.get('current_config')!;
      expect(config.siteUrl, 'https://gapp.github.io/notes');
      expect(config.baseurl, '/notes');

      final state = container.read(configNotifierProvider);
      expect(state, isA<ConfigLoaded>());
      expect((state as ConfigLoaded).config.siteUrl,
          'https://gapp.github.io/notes');
    });

    test('empty siteUrl is inferred (user site, empty baseurl)', () async {
      await container.read(configNotifierProvider.notifier).saveConfig(
            repoOwner: 'gapp',
            repoName: 'gapp.github.io',
            branch: 'main',
            assetsPath: 'assets/images',
          );

      final config = configBox.get('current_config')!;
      expect(config.siteUrl, 'https://gapp.github.io');
      expect(config.baseurl, '');
      // Stored explicitly, not left null
      expect(config.siteUrlRaw, 'https://gapp.github.io');
      expect(config.baseurlRaw, '');
    });

    test('explicit siteUrl and baseurl are kept verbatim', () async {
      await container.read(configNotifierProvider.notifier).saveConfig(
            repoOwner: 'gapp',
            repoName: 'notes',
            branch: 'main',
            assetsPath: 'assets/images',
            siteUrl: 'https://gapp.in',
            baseurl: '',
          );

      final config = configBox.get('current_config')!;
      expect(config.siteUrl, 'https://gapp.in');
      expect(config.baseurl, '');
    });

    test('explicit baseurl survives siteUrl inference', () async {
      await container.read(configNotifierProvider.notifier).saveConfig(
            repoOwner: 'gapp',
            repoName: 'notes',
            branch: 'main',
            assetsPath: 'assets/images',
            baseurl: '/custom',
          );

      final config = configBox.get('current_config')!;
      expect(config.siteUrl, 'https://gapp.github.io/notes');
      expect(config.baseurl, '/custom');
    });

    test('setActiveContentDir persists the switch and keeps the rest '
        'of the config, without passing through ConfigLoading', () async {
      final states = <ConfigState>[];
      // Listen before touching the notifier, mirroring the app where the
      // dashboard watches the provider. (The provider is keepAlive, so a
      // held notifier stays valid regardless - the ordering here is belt
      // and braces, not load-bearing.)
      container.listen(configNotifierProvider, (_, next) => states.add(next));

      final notifier = container.read(configNotifierProvider.notifier);
      await notifier.saveConfig(
        repoOwner: 'gapp',
        repoName: 'notes',
        branch: 'main',
        assetsPath: 'assets/images',
        defaultLayout: 'post',
        contentDirs: ['_posts', '_wiki'],
        activeContentDir: '_posts',
      );
      // Only the states emitted by the dir switch matter below
      states.clear();

      await notifier.setActiveContentDir('_wiki');

      final config = configBox.get('current_config')!;
      expect(config.activeContentDir, '_wiki');
      expect(config.contentDirs, ['_posts', '_wiki']);
      expect(config.defaultLayout, 'post');
      expect(config.repoName, 'notes');

      // The dashboard stays mounted: every emitted state is ConfigLoaded
      expect(states, isNotEmpty);
      expect(states.every((s) => s is ConfigLoaded), isTrue);
      final state = container.read(configNotifierProvider);
      expect((state as ConfigLoaded).config.activeContentDir, '_wiki');
    });

    test('setActiveContentDir is a no-op when no config is loaded', () async {
      final notifier = container.read(configNotifierProvider.notifier);
      expect(container.read(configNotifierProvider), isA<ConfigNotSet>());

      await notifier.setActiveContentDir('_wiki');

      expect(configBox.get('current_config'), isNull);
      expect(container.read(configNotifierProvider), isA<ConfigNotSet>());
    });

    test('v2 fields are persisted', () async {
      await container.read(configNotifierProvider.notifier).saveConfig(
            repoOwner: 'gapp',
            repoName: 'notes',
            branch: 'main',
            assetsPath: 'assets/images',
            postsPath: 'docs/_posts',
            draftsPath: 'docs/_drafts',
            defaultLayout: 'post',
            contentDirs: ['docs/_posts', '_wiki'],
            activeContentDir: '_wiki',
          );

      final config = configBox.get('current_config')!;
      expect(config.postsPath, 'docs/_posts');
      expect(config.draftsPath, 'docs/_drafts');
      expect(config.defaultLayout, 'post');
      expect(config.contentDirs, ['docs/_posts', '_wiki']);
      expect(config.activeContentDir, '_wiki');
    });
  });
}

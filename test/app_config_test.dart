import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/models/app_config.dart';

/// The exact adapter shape shipped in v1.x (4 fields), used to write a
/// v1 record so the v2 adapter's migration path is exercised for real.
class _V1AppConfigAdapter extends TypeAdapter<AppConfig> {
  @override
  final int typeId = 0;

  @override
  AppConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppConfig(
      repoOwner: fields[0] as String,
      repoName: fields[1] as String,
      branch: fields[2] as String,
      assetsPath: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppConfig obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.repoOwner)
      ..writeByte(1)
      ..write(obj.repoName)
      ..writeByte(2)
      ..write(obj.branch)
      ..writeByte(3)
      ..write(obj.assetsPath);
  }
}

void main() {
  group('AppConfig defaults', () {
    test('v2 getters supply defaults when raw fields are null', () {
      final config = AppConfig(repoOwner: 'gapp', repoName: 'blog');

      expect(config.postsPath, '_posts');
      expect(config.draftsPath, '_drafts');
      expect(config.siteUrl, '');
      expect(config.baseurl, '');
      expect(config.defaultLayout, isNull);
      expect(config.defaultCategories, isEmpty);
      expect(config.defaultTags, isEmpty);
      expect(config.contentDirs, ['_posts']);
      expect(config.activeContentDir, '_posts');
    });

    test('empty strings and empty lists are treated as unset', () {
      final config = AppConfig(
        repoOwner: 'gapp',
        repoName: 'blog',
        postsPath: '',
        draftsPath: '',
        contentDirs: [],
        activeContentDir: '',
      );

      expect(config.postsPath, '_posts');
      expect(config.draftsPath, '_drafts');
      expect(config.contentDirs, ['_posts']);
      expect(config.activeContentDir, '_posts');
    });

    test('contentDirs and activeContentDir defaults track postsPath', () {
      final config = AppConfig(
        repoOwner: 'gapp',
        repoName: 'blog',
        postsPath: 'docs/_posts',
      );

      expect(config.contentDirs, ['docs/_posts']);
      expect(config.activeContentDir, 'docs/_posts');
    });

    test('explicit values win over defaults', () {
      final config = AppConfig(
        repoOwner: 'gapp',
        repoName: 'blog',
        postsPath: '_posts',
        siteUrl: 'https://gapp.in',
        baseurl: '/blog',
        defaultLayout: 'post',
        defaultCategories: ['blog'],
        defaultTags: ['dev'],
        contentDirs: ['_posts', '_wiki'],
        activeContentDir: '_wiki',
      );

      expect(config.siteUrl, 'https://gapp.in');
      expect(config.baseurl, '/blog');
      expect(config.defaultLayout, 'post');
      expect(config.defaultCategories, ['blog']);
      expect(config.defaultTags, ['dev']);
      expect(config.contentDirs, ['_posts', '_wiki']);
      expect(config.activeContentDir, '_wiki');
    });
  });

  group('AppConfig.copyWith', () {
    test('overrides every field', () {
      final config = AppConfig(repoOwner: 'a', repoName: 'b').copyWith(
        repoOwner: 'o',
        repoName: 'r',
        branch: 'dev',
        assetsPath: 'img',
        postsPath: 'docs/_posts',
        draftsPath: 'docs/_drafts',
        siteUrl: 'https://o.github.io/r',
        baseurl: '/r',
        defaultLayout: 'single',
        defaultCategories: ['c'],
        defaultTags: ['t'],
        contentDirs: ['docs/_posts', '_wiki'],
        activeContentDir: '_wiki',
      );

      expect(config.repoOwner, 'o');
      expect(config.repoName, 'r');
      expect(config.branch, 'dev');
      expect(config.assetsPath, 'img');
      expect(config.postsPath, 'docs/_posts');
      expect(config.draftsPath, 'docs/_drafts');
      expect(config.siteUrl, 'https://o.github.io/r');
      expect(config.baseurl, '/r');
      expect(config.defaultLayout, 'single');
      expect(config.defaultCategories, ['c']);
      expect(config.defaultTags, ['t']);
      expect(config.contentDirs, ['docs/_posts', '_wiki']);
      expect(config.activeContentDir, '_wiki');
    });

    test('keeps existing values (and null raws stay null)', () {
      final copy = AppConfig(
        repoOwner: 'o',
        repoName: 'r',
        siteUrl: 'https://o.github.io',
      ).copyWith(branch: 'dev');

      expect(copy.repoOwner, 'o');
      expect(copy.branch, 'dev');
      expect(copy.siteUrl, 'https://o.github.io');
      // Unset raws remain unset so getter defaults keep applying
      expect(copy.postsPathRaw, isNull);
      expect(copy.postsPath, '_posts');
    });
  });

  group('AppConfig Hive migration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('app_config_test');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('a record written by the v1 adapter reads cleanly with v2', () async {
      // Write with the v1 (4-field) adapter
      Hive.registerAdapter(_V1AppConfigAdapter(), override: true);
      var box = await Hive.openBox<AppConfig>('app_config');
      await box.put(
        'current_config',
        AppConfig(
          repoOwner: 'gapp',
          repoName: 'blog',
          branch: 'master',
          assetsPath: 'assets/images',
        ),
      );
      await box.close();

      // Read back with the real v2 adapter
      Hive.registerAdapter(AppConfigAdapter(), override: true);
      box = await Hive.openBox<AppConfig>('app_config');
      final config = box.get('current_config');

      expect(config, isNotNull);
      expect(config!.repoOwner, 'gapp');
      expect(config.repoName, 'blog');
      expect(config.branch, 'master');
      expect(config.assetsPath, 'assets/images');
      // v2 fields come back null and the getters supply the defaults
      expect(config.postsPathRaw, isNull);
      expect(config.postsPath, '_posts');
      expect(config.draftsPath, '_drafts');
      expect(config.siteUrl, '');
      expect(config.baseurl, '');
      expect(config.defaultLayout, isNull);
      expect(config.defaultCategories, isEmpty);
      expect(config.defaultTags, isEmpty);
      expect(config.contentDirs, ['_posts']);
      expect(config.activeContentDir, '_posts');
    });

    test('v2 round-trips all fields', () async {
      Hive.registerAdapter(AppConfigAdapter(), override: true);
      final box = await Hive.openBox<AppConfig>('app_config_v2');
      await box.put(
        'c',
        AppConfig(
          repoOwner: 'o',
          repoName: 'r',
          branch: 'dev',
          assetsPath: 'img',
          postsPath: 'docs/_posts',
          draftsPath: 'docs/_drafts',
          siteUrl: 'https://o.github.io/r',
          baseurl: '/r',
          defaultLayout: 'post',
          defaultCategories: ['blog'],
          defaultTags: ['dev', 'notes'],
          contentDirs: ['docs/_posts', '_wiki'],
          activeContentDir: '_wiki',
        ),
      );

      final config = box.get('c')!;
      expect(config.postsPath, 'docs/_posts');
      expect(config.draftsPath, 'docs/_drafts');
      expect(config.siteUrl, 'https://o.github.io/r');
      expect(config.baseurl, '/r');
      expect(config.defaultLayout, 'post');
      expect(config.defaultCategories, ['blog']);
      expect(config.defaultTags, ['dev', 'notes']);
      expect(config.contentDirs, ['docs/_posts', '_wiki']);
      expect(config.activeContentDir, '_wiki');
    });
  });
}

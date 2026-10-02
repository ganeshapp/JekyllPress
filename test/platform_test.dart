import 'dart:io';

import 'package:flutter/foundation.dart';
// flutter_test exports host gates of the same names; the app's are under test
import 'package:flutter_test/flutter_test.dart' hide isLinux, isMacOS;
import 'package:jekyllpress/core/platform.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory home;
  late Map<String, String> env;

  setUp(() {
    home = Directory.systemTemp.createTempSync('platform_test');
    env = {'HOME': home.path};
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    home.deleteSync(recursive: true);
  });

  /// Permission bits only
  int mode(Directory dir) => dir.statSync().mode & 0x1FF;

  group('Linux app directories', () {
    test('data lives in ~/.local/share/<app id>, private to the user',
        () async {
      final dir = await appDataDir(env: env);
      expect(dir.path, p.join(home.path, '.local/share', appId));
      expect(dir.existsSync(), isTrue);
      expect(mode(dir), 0x1C0, reason: 'mode 0700');
    });

    test('cache lives in ~/.cache/<app id>, private to the user', () async {
      final dir = await appCacheDir(env: env);
      expect(dir.path, p.join(home.path, '.cache', appId));
      expect(dir.existsSync(), isTrue);
      expect(mode(dir), 0x1C0, reason: 'mode 0700');
    });

    test('XDG_DATA_HOME and XDG_CACHE_HOME override the defaults', () async {
      env['XDG_DATA_HOME'] = p.join(home.path, 'data');
      env['XDG_CACHE_HOME'] = p.join(home.path, 'cache');
      expect((await appDataDir(env: env)).path,
          p.join(home.path, 'data', appId));
      expect((await appCacheDir(env: env)).path,
          p.join(home.path, 'cache', appId));
    });

    test('a relative XDG value is ignored, as the spec says', () async {
      env['XDG_DATA_HOME'] = 'data';
      expect((await appDataDir(env: env)).path,
          p.join(home.path, '.local/share', appId));
    });

    test('the same path every launch, whatever is installed', () async {
      expect((await appDataDir(env: env)).path,
          (await appDataDir(env: env)).path);
    });

    test("2.2.0's executable-name folder is moved over, once", () async {
      final old = Directory(p.join(home.path, '.local/share/jekyllpress'))
        ..createSync(recursive: true);
      File(p.join(old.path, 'app_config.hive')).writeAsStringSync('config');

      final dir = await appDataDir(env: env);

      expect(File(p.join(dir.path, 'app_config.hive')).readAsStringSync(),
          'config');
      expect(old.existsSync(), isFalse);
    });

    test('an old folder next to an existing new one is left alone',
        () async {
      final dir = await appDataDir(env: env);
      File(p.join(dir.path, 'app_config.hive')).writeAsStringSync('new');
      final old = Directory(p.join(home.path, '.local/share/jekyllpress'))
        ..createSync(recursive: true);

      await appDataDir(env: env);

      expect(File(p.join(dir.path, 'app_config.hive')).readAsStringSync(),
          'new');
      expect(old.existsSync(), isTrue);
    });
  });

  test('platform gates', () {
    expect(isLinux, isTrue);
    expect(isMacOS, isFalse);
    expect(isDesktop, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(isMacOS, isTrue);
    expect(isDesktop, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(isDesktop, isFalse);
  });
}

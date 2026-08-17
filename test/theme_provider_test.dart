import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jekyllpress/core/providers/theme_provider.dart';

void main() {
  late Directory tempDir;
  late Box<String> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('theme_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('app_settings');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('ThemeModeNotifier', () {
    test('defaults to system when nothing is stored', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeNotifierProvider), ThemeMode.system);
    });

    test('setMode updates state and persists to the box', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(themeModeNotifierProvider, (_, __) {});

      await container
          .read(themeModeNotifierProvider.notifier)
          .setMode(ThemeMode.dark);

      expect(container.read(themeModeNotifierProvider), ThemeMode.dark);
      expect(box.get('theme_mode'), 'dark');
    });

    test('a stored value survives a fresh container (app restart)', () async {
      await box.put('theme_mode', 'light');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeNotifierProvider), ThemeMode.light);
    });

    test('an unknown stored value falls back to system', () async {
      await box.put('theme_mode', 'sepia');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeNotifierProvider), ThemeMode.system);
    });
  });
}

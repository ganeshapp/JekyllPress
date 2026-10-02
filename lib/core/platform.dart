import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Platform gates. Read through [defaultTargetPlatform], not dart:io Platform:
/// under `flutter test` it reports android on every host, so the suite keeps
/// testing the phone path on a Linux CI runner; a test opts in with
/// `debugDefaultTargetPlatformOverride`; release builds constant-fold it.
bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;
bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
bool get isDesktop => isLinux || isMacOS;

/// macOS bundle id, Linux APPLICATION_ID, keychain service name, XDG folder
const appId = 'com.jekyllpress.jekyllpress';

/// Where the app keeps its own files. Android keeps the documents dir
/// existing installs already use; on desktop that dir is the user's
/// ~/Documents. [env] is for tests.
Future<Directory> appDataDir({Map<String, String>? env}) async {
  if (isLinux) {
    final dir = _xdgDir('XDG_DATA_HOME', '.local/share', env);
    // 2.2.0 built without libglib2.0-dev kept its data under the executable
    // name: move it rather than look in two places forever
    final old = Directory(p.join(dir.parent.path, 'jekyllpress'));
    if (!dir.existsSync() && old.existsSync()) old.renameSync(dir.path);
    return _private(dir);
  }
  return isMacOS
      ? getApplicationSupportDirectory()
      : getApplicationDocumentsDirectory();
}

/// Scratch space for files made on the way to an upload (HEIC conversion).
/// On desktop never /tmp, which other users and apps can read.
Future<Directory> appCacheDir({Map<String, String>? env}) async {
  if (isLinux) return _private(_xdgDir('XDG_CACHE_HOME', '.cache', env));
  return isMacOS ? getApplicationCacheDirectory() : getTemporaryDirectory();
}

/// ${variable:-~/fallback}/appId. Computed here, not by path_provider, whose
/// Linux lookup names the folder after the GApplication id or after the
/// executable depending on whether libglib2.0-dev is installed, so a user's
/// drafts and setup "disappeared" when build tools came or went.
Directory _xdgDir(String variable, String fallback, Map<String, String>? env) {
  env ??= Platform.environment;
  final base = env[variable] ?? '';
  final home = env['HOME'] ?? (throw StateError('HOME is not set'));
  // The XDG spec says to ignore a relative value
  return Directory(
      p.join(base.startsWith('/') ? base : p.join(home, fallback), appId));
}

/// Create [dir] readable by this user only: the Hive files hold cached posts
/// from possibly private repositories
Future<Directory> _private(Directory dir) async {
  await dir.create(recursive: true);
  await Process.run('chmod', ['700', dir.path]);
  return dir;
}

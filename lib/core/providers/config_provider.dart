import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../models/github_repo.dart';
import '../repositories/repo_repository.dart';
import '../services/dio_client.dart';

part 'config_provider.g.dart';

/// Provider for RepoRepository
@riverpod
RepoRepository repoRepository(Ref ref) {
  return RepoRepository(dio: ref.watch(apiClientProvider).dio);
}

/// Provider to fetch user repositories
@riverpod
Future<List<GitHubRepo>> userRepos(Ref ref) async {
  final repoRepository = ref.watch(repoRepositoryProvider);
  return repoRepository.getUserRepos();
}

/// Provider to fetch branch names for a repository (up to
/// [RepoRepository.branchesPerPage])
@riverpod
Future<List<String>> repoBranches(
  Ref ref, {
  required String repoOwner,
  required String repoName,
}) async {
  final repoRepository = ref.watch(repoRepositoryProvider);
  return repoRepository.getBranches(
    repoOwner: repoOwner,
    repoName: repoName,
  );
}

/// Provider for the Hive app_config box
@riverpod
Box<AppConfig> appConfigBox(Ref ref) {
  return Hive.box<AppConfig>('app_config');
}

/// Infer the public site URL and baseurl for a GitHub Pages repo:
/// a repo named `<owner>.github.io` is a user/org site served at the
/// domain root; any other repo is a project site served under `/<repo>`.
({String siteUrl, String baseurl}) inferPagesSite({
  required String repoOwner,
  required String repoName,
}) {
  // Pages hostnames are always lowercase
  final owner = repoOwner.toLowerCase();
  if (repoName.toLowerCase() == '$owner.github.io') {
    return (siteUrl: 'https://$owner.github.io', baseurl: '');
  }
  return (
    siteUrl: 'https://$owner.github.io/$repoName',
    baseurl: '/$repoName',
  );
}

/// State for app configuration
sealed class ConfigState {
  const ConfigState();
}

class ConfigInitial extends ConfigState {
  const ConfigInitial();
}

class ConfigLoading extends ConfigState {
  const ConfigLoading();
}

class ConfigLoaded extends ConfigState {
  final AppConfig config;
  const ConfigLoaded(this.config);
}

class ConfigNotSet extends ConfigState {
  const ConfigNotSet();
}

/// Notifier for managing app configuration.
///
/// Kept alive: this is app-global, Hive-backed state. With autoDispose,
/// a caller holding the notifier while no widget is listening (e.g. mid
/// navigation) would mutate a detached element and the update would be
/// silently lost.
@Riverpod(keepAlive: true)
class ConfigNotifier extends _$ConfigNotifier {
  static const _configKey = 'current_config';

  @override
  ConfigState build() {
    // Load config synchronously from Hive and return correct initial state
    final box = ref.read(appConfigBoxProvider);
    final config = box.get(_configKey);
    
    if (config != null) {
      return ConfigLoaded(config);
    } else {
      return const ConfigNotSet();
    }
  }

  /// Save the repo configuration. When [siteUrl] is empty/absent, the
  /// public site URL (and, unless explicitly provided, the baseurl) is
  /// inferred from the GitHub Pages naming convention via
  /// [inferPagesSite].
  Future<void> saveConfig({
    required String repoOwner,
    required String repoName,
    required String branch,
    required String assetsPath,
    String? postsPath,
    String? draftsPath,
    String? siteUrl,
    String? baseurl,
    String? defaultLayout,
    List<String>? defaultCategories,
    List<String>? defaultTags,
    List<String>? contentDirs,
    String? activeContentDir,
  }) async {
    state = const ConfigLoading();

    var effectiveSiteUrl = siteUrl;
    var effectiveBaseurl = baseurl;
    if (siteUrl == null || siteUrl.trim().isEmpty) {
      final inferred =
          inferPagesSite(repoOwner: repoOwner, repoName: repoName);
      effectiveSiteUrl = inferred.siteUrl;
      if (baseurl == null || baseurl.trim().isEmpty) {
        effectiveBaseurl = inferred.baseurl;
      }
    }

    final box = ref.read(appConfigBoxProvider);
    final config = AppConfig(
      repoOwner: repoOwner,
      repoName: repoName,
      branch: branch,
      assetsPath: assetsPath,
      postsPath: postsPath,
      draftsPath: draftsPath,
      siteUrl: effectiveSiteUrl,
      baseurl: effectiveBaseurl,
      defaultLayout: defaultLayout,
      defaultCategories: defaultCategories,
      defaultTags: defaultTags,
      contentDirs: contentDirs,
      activeContentDir: activeContentDir,
    );

    await box.put(_configKey, config);
    state = ConfigLoaded(config);
  }

  /// Switch the content dir the app syncs from / publishes to. Unlike
  /// [saveConfig] this never passes through [ConfigLoading], so the
  /// dashboard is not swapped out while the dir changes.
  Future<void> setActiveContentDir(String dir) async {
    final current = currentConfig;
    if (current == null) return;

    final updated = current.copyWith(activeContentDir: dir);
    final box = ref.read(appConfigBoxProvider);
    await box.put(_configKey, updated);
    state = ConfigLoaded(updated);
  }

  Future<void> clearConfig() async {
    final box = ref.read(appConfigBoxProvider);
    await box.delete(_configKey);
    state = const ConfigNotSet();
  }

  /// Check if configuration exists
  bool get hasConfig => state is ConfigLoaded;

  /// Get current config if available
  AppConfig? get currentConfig {
    final s = state;
    return s is ConfigLoaded ? s.config : null;
  }
}

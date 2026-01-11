import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../models/github_repo.dart';
import '../repositories/repo_repository.dart';
import 'auth_provider.dart';

part 'config_provider.g.dart';

/// Provider for RepoRepository
@riverpod
RepoRepository repoRepository(Ref ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return RepoRepository(secureStorage: secureStorage);
}

/// Provider to fetch user repositories
@riverpod
Future<List<GitHubRepo>> userRepos(Ref ref) async {
  final repoRepository = ref.watch(repoRepositoryProvider);
  return repoRepository.getUserRepos();
}

/// Provider for the Hive app_config box
@riverpod
Box<AppConfig> appConfigBox(Ref ref) {
  return Hive.box<AppConfig>('app_config');
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

/// Notifier for managing app configuration
@riverpod
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

  Future<void> saveConfig({
    required String repoOwner,
    required String repoName,
    required String branch,
    required String assetsPath,
  }) async {
    state = const ConfigLoading();
    
    final box = ref.read(appConfigBoxProvider);
    final config = AppConfig(
      repoOwner: repoOwner,
      repoName: repoName,
      branch: branch,
      assetsPath: assetsPath,
    );
    
    await box.put(_configKey, config);
    state = ConfigLoaded(config);
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

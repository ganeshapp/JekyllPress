// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$repoRepositoryHash() => r'eacd6af938b1ca00d3808fe80ccd9ad48b09e74f';

/// Provider for RepoRepository
///
/// Copied from [repoRepository].
@ProviderFor(repoRepository)
final repoRepositoryProvider = AutoDisposeProvider<RepoRepository>.internal(
  repoRepository,
  name: r'repoRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$repoRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RepoRepositoryRef = AutoDisposeProviderRef<RepoRepository>;
String _$userReposHash() => r'372902a979a5fa85972956560ae6b855266362e6';

/// Provider to fetch user repositories
///
/// Copied from [userRepos].
@ProviderFor(userRepos)
final userReposProvider = AutoDisposeFutureProvider<List<GitHubRepo>>.internal(
  userRepos,
  name: r'userReposProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userReposHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserReposRef = AutoDisposeFutureProviderRef<List<GitHubRepo>>;
String _$appConfigBoxHash() => r'9857cb3b306ecb07aa6a05ef43ce5e9d2ef77a78';

/// Provider for the Hive app_config box
///
/// Copied from [appConfigBox].
@ProviderFor(appConfigBox)
final appConfigBoxProvider = AutoDisposeProvider<Box<AppConfig>>.internal(
  appConfigBox,
  name: r'appConfigBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appConfigBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppConfigBoxRef = AutoDisposeProviderRef<Box<AppConfig>>;
String _$configNotifierHash() => r'c97b82214bc290dad6897404fb588065cdf70c8b';

/// Notifier for managing app configuration
///
/// Copied from [ConfigNotifier].
@ProviderFor(ConfigNotifier)
final configNotifierProvider =
    AutoDisposeNotifierProvider<ConfigNotifier, ConfigState>.internal(
  ConfigNotifier.new,
  name: r'configNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$configNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ConfigNotifier = AutoDisposeNotifier<ConfigState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

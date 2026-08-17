// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$repoRepositoryHash() => r'd23a6f2ea2b3f33250459aa3c23fcfbc898834e5';

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
String _$repoBranchesHash() => r'9fa4678e63e12aba332026c064bfa9692f5dae53';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Provider to fetch branch names for a repository (up to
/// [RepoRepository.branchesPerPage])
///
/// Copied from [repoBranches].
@ProviderFor(repoBranches)
const repoBranchesProvider = RepoBranchesFamily();

/// Provider to fetch branch names for a repository (up to
/// [RepoRepository.branchesPerPage])
///
/// Copied from [repoBranches].
class RepoBranchesFamily extends Family<AsyncValue<List<String>>> {
  /// Provider to fetch branch names for a repository (up to
  /// [RepoRepository.branchesPerPage])
  ///
  /// Copied from [repoBranches].
  const RepoBranchesFamily();

  /// Provider to fetch branch names for a repository (up to
  /// [RepoRepository.branchesPerPage])
  ///
  /// Copied from [repoBranches].
  RepoBranchesProvider call({
    required String repoOwner,
    required String repoName,
  }) {
    return RepoBranchesProvider(
      repoOwner: repoOwner,
      repoName: repoName,
    );
  }

  @override
  RepoBranchesProvider getProviderOverride(
    covariant RepoBranchesProvider provider,
  ) {
    return call(
      repoOwner: provider.repoOwner,
      repoName: provider.repoName,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'repoBranchesProvider';
}

/// Provider to fetch branch names for a repository (up to
/// [RepoRepository.branchesPerPage])
///
/// Copied from [repoBranches].
class RepoBranchesProvider extends AutoDisposeFutureProvider<List<String>> {
  /// Provider to fetch branch names for a repository (up to
  /// [RepoRepository.branchesPerPage])
  ///
  /// Copied from [repoBranches].
  RepoBranchesProvider({
    required String repoOwner,
    required String repoName,
  }) : this._internal(
          (ref) => repoBranches(
            ref as RepoBranchesRef,
            repoOwner: repoOwner,
            repoName: repoName,
          ),
          from: repoBranchesProvider,
          name: r'repoBranchesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$repoBranchesHash,
          dependencies: RepoBranchesFamily._dependencies,
          allTransitiveDependencies:
              RepoBranchesFamily._allTransitiveDependencies,
          repoOwner: repoOwner,
          repoName: repoName,
        );

  RepoBranchesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.repoOwner,
    required this.repoName,
  }) : super.internal();

  final String repoOwner;
  final String repoName;

  @override
  Override overrideWith(
    FutureOr<List<String>> Function(RepoBranchesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RepoBranchesProvider._internal(
        (ref) => create(ref as RepoBranchesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        repoOwner: repoOwner,
        repoName: repoName,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<String>> createElement() {
    return _RepoBranchesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RepoBranchesProvider &&
        other.repoOwner == repoOwner &&
        other.repoName == repoName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, repoOwner.hashCode);
    hash = _SystemHash.combine(hash, repoName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RepoBranchesRef on AutoDisposeFutureProviderRef<List<String>> {
  /// The parameter `repoOwner` of this provider.
  String get repoOwner;

  /// The parameter `repoName` of this provider.
  String get repoName;
}

class _RepoBranchesProviderElement
    extends AutoDisposeFutureProviderElement<List<String>>
    with RepoBranchesRef {
  _RepoBranchesProviderElement(super.provider);

  @override
  String get repoOwner => (origin as RepoBranchesProvider).repoOwner;
  @override
  String get repoName => (origin as RepoBranchesProvider).repoName;
}

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
String _$configNotifierHash() => r'58f171c8fdb40a20810f0634ba39d11752804dd1';

/// Notifier for managing app configuration.
///
/// Kept alive: this is app-global, Hive-backed state. With autoDispose,
/// a caller holding the notifier while no widget is listening (e.g. mid
/// navigation) would mutate a detached element and the update would be
/// silently lost.
///
/// Copied from [ConfigNotifier].
@ProviderFor(ConfigNotifier)
final configNotifierProvider =
    NotifierProvider<ConfigNotifier, ConfigState>.internal(
  ConfigNotifier.new,
  name: r'configNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$configNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ConfigNotifier = Notifier<ConfigState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

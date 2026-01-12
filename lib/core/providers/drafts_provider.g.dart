// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drafts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$draftsBoxHash() => r'992a8ecdc6306371a7425e43474d73b9c62ae54d';

/// Provider for accessing the drafts Hive box
///
/// Copied from [draftsBox].
@ProviderFor(draftsBox)
final draftsBoxProvider = AutoDisposeProvider<Box<LocalDraft>>.internal(
  draftsBox,
  name: r'draftsBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$draftsBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DraftsBoxRef = AutoDisposeProviderRef<Box<LocalDraft>>;
String _$draftsNotifierHash() => r'3ab49bac08b14c2f2a46c42b94b02cfb4ed27a0d';

/// Manages local drafts - saving, loading, and deleting
///
/// Copied from [DraftsNotifier].
@ProviderFor(DraftsNotifier)
final draftsNotifierProvider =
    AutoDisposeNotifierProvider<DraftsNotifier, DraftsState>.internal(
  DraftsNotifier.new,
  name: r'draftsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$draftsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DraftsNotifier = AutoDisposeNotifier<DraftsState>;
String _$currentDraftNotifierHash() =>
    r'2178d634cd1084b1b7bc136da9df89ad38cfbacb';

/// Manages the current editing session's draft state
///
/// Copied from [CurrentDraftNotifier].
@ProviderFor(CurrentDraftNotifier)
final currentDraftNotifierProvider =
    AutoDisposeNotifierProvider<CurrentDraftNotifier, DraftSaveStatus>.internal(
  CurrentDraftNotifier.new,
  name: r'currentDraftNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentDraftNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentDraftNotifier = AutoDisposeNotifier<DraftSaveStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

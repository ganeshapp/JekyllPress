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
String _$draftsNotifierHash() => r'55e7531c51305a492758dbf50553cce17b1b8871';

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
    r'd5b3554ac96dd372aa6e5c0b74a2a41a433269e1';

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

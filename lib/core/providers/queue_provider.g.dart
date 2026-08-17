// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectivityHash() => r'e66720f09edf1a8b09e450e1eaedd51da9443f0e';

/// Connectivity plugin access point - overridable in tests so nothing
/// touches platform channels
///
/// Copied from [connectivity].
@ProviderFor(connectivity)
final connectivityProvider = Provider<Connectivity>.internal(
  connectivity,
  name: r'connectivityProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$connectivityHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectivityRef = ProviderRef<Connectivity>;
String _$publishQueueBoxHash() => r'2c445e1818dd0a9f2081fa7bbd6ddb946e92c4c4';

/// Provider for the publish queue Hive box
///
/// Copied from [publishQueueBox].
@ProviderFor(publishQueueBox)
final publishQueueBoxProvider = AutoDisposeProvider<Box<Map>>.internal(
  publishQueueBox,
  name: r'publishQueueBoxProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$publishQueueBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PublishQueueBoxRef = AutoDisposeProviderRef<Box<Map>>;
String _$publishQueueServiceHash() =>
    r'181c3c2589d2bee330d1452a0b24f3ad22c36891';

/// Provider for PublishQueueService
///
/// Copied from [publishQueueService].
@ProviderFor(publishQueueService)
final publishQueueServiceProvider =
    AutoDisposeProvider<PublishQueueService>.internal(
  publishQueueService,
  name: r'publishQueueServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$publishQueueServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PublishQueueServiceRef = AutoDisposeProviderRef<PublishQueueService>;
String _$publishQueueNotifierHash() =>
    r'8c931510fae20b0e3dbd8ba7848aee51463b2b78';

/// Offline publish queue: holds posts the user chose to 'publish when
/// online' and flushes them FIFO through the existing PublishService
/// whenever connectivity returns or the app resumes.
///
/// Kept alive: the queue must keep listening for connectivity while no
/// screen is watching it.
///
/// Copied from [PublishQueueNotifier].
@ProviderFor(PublishQueueNotifier)
final publishQueueNotifierProvider =
    NotifierProvider<PublishQueueNotifier, List<QueuedPublish>>.internal(
  PublishQueueNotifier.new,
  name: r'publishQueueNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$publishQueueNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PublishQueueNotifier = Notifier<List<QueuedPublish>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publish_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$publishServiceHash() => r'8d1564d57accbeb3b323a64b64b02abddb79bf59';

/// Provider for PublishService
///
/// Copied from [publishService].
@ProviderFor(publishService)
final publishServiceProvider = AutoDisposeProvider<PublishService>.internal(
  publishService,
  name: r'publishServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$publishServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PublishServiceRef = AutoDisposeProviderRef<PublishService>;
String _$publishNotifierHash() => r'7bb5d71e82b60b2882562a77f5c66c4827c563d5';

/// Notifier for managing publish operations
///
/// Copied from [PublishNotifier].
@ProviderFor(PublishNotifier)
final publishNotifierProvider =
    AutoDisposeNotifierProvider<PublishNotifier, PublishState>.internal(
  PublishNotifier.new,
  name: r'publishNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$publishNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PublishNotifier = AutoDisposeNotifier<PublishState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

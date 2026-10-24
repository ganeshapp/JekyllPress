// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publish_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$publishServiceHash() => r'5a68a1d3c7f4473d26c457ae2fa72ca1bfe56f74';

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
String _$publishNotifierHash() => r'5dba45cd25ac79a7f85a0d6149c8e160cd6d2638';

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

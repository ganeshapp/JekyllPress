// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'posts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$contentServiceHash() => r'db95b45abf18657d2c0586f0b124a258dcb7093a';

/// Provider for ContentService
///
/// Copied from [contentService].
@ProviderFor(contentService)
final contentServiceProvider = AutoDisposeProvider<ContentService>.internal(
  contentService,
  name: r'contentServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$contentServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContentServiceRef = AutoDisposeProviderRef<ContentService>;
String _$postsBoxHash() => r'e821fe1983db447c3b9657758c0dad33ab4f7038';

/// Provider for the posts Hive box
///
/// Copied from [postsBox].
@ProviderFor(postsBox)
final postsBoxProvider = AutoDisposeProvider<Box<BlogPost>>.internal(
  postsBox,
  name: r'postsBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$postsBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PostsBoxRef = AutoDisposeProviderRef<Box<BlogPost>>;
String _$postsNotifierHash() => r'b947a4acb2c1b8be49d44fc33a84928afea3ef46';

/// Notifier for managing posts with offline-first logic
///
/// Copied from [PostsNotifier].
@ProviderFor(PostsNotifier)
final postsNotifierProvider =
    AutoDisposeNotifierProvider<PostsNotifier, PostsState>.internal(
  PostsNotifier.new,
  name: r'postsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$postsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PostsNotifier = AutoDisposeNotifier<PostsState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

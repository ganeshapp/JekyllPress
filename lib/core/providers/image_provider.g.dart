// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$imageServiceHash() => r'7b43252a6533977db0be2e7b070e1e84a254b7ce';

/// Provider for ImageService
///
/// Copied from [imageService].
@ProviderFor(imageService)
final imageServiceProvider = AutoDisposeProvider<ImageService>.internal(
  imageService,
  name: r'imageServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$imageServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ImageServiceRef = AutoDisposeProviderRef<ImageService>;
String _$githubUploadServiceHash() =>
    r'ac2c05cc06731f9883cadbd075218cf4e6f28457';

/// Provider for GitHubUploadService
///
/// Copied from [githubUploadService].
@ProviderFor(githubUploadService)
final githubUploadServiceProvider =
    AutoDisposeProvider<GitHubUploadService>.internal(
  githubUploadService,
  name: r'githubUploadServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$githubUploadServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GithubUploadServiceRef = AutoDisposeProviderRef<GitHubUploadService>;
String _$imageAuthHeadersHash() => r'90290503732fde8f1c63e431a32b532a8d11da30';

/// Auth headers for loading raw.githubusercontent.com images in the
/// editor preview (private repos reject unauthenticated raw fetches).
/// Reads the token via the same source as the shared ApiClient.
///
/// Copied from [imageAuthHeaders].
@ProviderFor(imageAuthHeaders)
final imageAuthHeadersProvider =
    AutoDisposeFutureProvider<Map<String, String>?>.internal(
  imageAuthHeaders,
  name: r'imageAuthHeadersProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$imageAuthHeadersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ImageAuthHeadersRef
    = AutoDisposeFutureProviderRef<Map<String, String>?>;
String _$localImageMapBoxHash() => r'c1476a2e261b40a3602d6923812f18bd5b2a9ade';

/// Provider for the local_image_map Hive box
/// Maps filename -> local file path
///
/// Copied from [localImageMapBox].
@ProviderFor(localImageMapBox)
final localImageMapBoxProvider = AutoDisposeProvider<Box<String>>.internal(
  localImageMapBox,
  name: r'localImageMapBoxProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localImageMapBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalImageMapBoxRef = AutoDisposeProviderRef<Box<String>>;
String _$imageManagerHash() => r'087af327eb19c6ff64af1d0aa0d48d3d373f84eb';

/// Notifier for managing media (image + video) operations
/// keepAlive so upload statuses survive while the editor preview
/// subscribes/unsubscribes (overlays keep updating mid-upload)
///
/// Copied from [ImageManager].
@ProviderFor(ImageManager)
final imageManagerProvider =
    NotifierProvider<ImageManager, Map<String, ImageUploadStatus>>.internal(
  ImageManager.new,
  name: r'imageManagerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$imageManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ImageManager = Notifier<Map<String, ImageUploadStatus>>;
String _$imageResolverHash() => r'6265c6e90570beb255aa5a1783a8f04d0b7ab4b0';

/// Provider to resolve image paths for preview
/// Returns local file path if available, otherwise GitHub raw URL
///
/// Copied from [ImageResolver].
@ProviderFor(ImageResolver)
final imageResolverProvider =
    AutoDisposeNotifierProvider<ImageResolver, void>.internal(
  ImageResolver.new,
  name: r'imageResolverProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$imageResolverHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ImageResolver = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

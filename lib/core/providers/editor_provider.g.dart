// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$editorControllerHash() => r'625f9c57cd943c3c6132fd56713c2d3f7a05ab4b';

/// Controller for managing editor state
/// This preserves state across tab switches and rebuilds
///
/// Copied from [EditorController].
@ProviderFor(EditorController)
final editorControllerProvider =
    AutoDisposeNotifierProvider<EditorController, EditorState>.internal(
  EditorController.new,
  name: r'editorControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$editorControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$EditorController = AutoDisposeNotifier<EditorState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

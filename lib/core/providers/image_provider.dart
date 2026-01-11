import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../services/github_upload_service.dart';
import '../services/image_service.dart';
import 'auth_provider.dart';
import 'config_provider.dart';

part 'image_provider.g.dart';

/// Provider for ImageService
@riverpod
ImageService imageService(Ref ref) {
  return ImageService();
}

/// Provider for GitHubUploadService
@riverpod
GitHubUploadService githubUploadService(Ref ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return GitHubUploadService(secureStorage: secureStorage);
}

/// Provider for the local_image_map Hive box
/// Maps filename -> local file path
@riverpod
Box<String> localImageMapBox(Ref ref) {
  return Hive.box<String>('local_image_map');
}

/// State for image upload status
class ImageUploadStatus {
  final String filename;
  final bool isUploading;
  final bool isUploaded;
  final String? error;

  const ImageUploadStatus({
    required this.filename,
    this.isUploading = false,
    this.isUploaded = false,
    this.error,
  });

  ImageUploadStatus copyWith({
    String? filename,
    bool? isUploading,
    bool? isUploaded,
    String? error,
  }) {
    return ImageUploadStatus(
      filename: filename ?? this.filename,
      isUploading: isUploading ?? this.isUploading,
      isUploaded: isUploaded ?? this.isUploaded,
      error: error,
    );
  }
}

/// Notifier for managing image operations
@riverpod
class ImageManager extends _$ImageManager {
  @override
  Map<String, ImageUploadStatus> build() {
    return {};
  }

  /// Get current app config
  AppConfig? get _config {
    final configState = ref.read(configNotifierProvider);
    return configState is ConfigLoaded ? configState.config : null;
  }

  /// Pick and process an image from gallery
  /// Returns the filename for markdown insertion, or null if cancelled
  Future<String?> pickImage() async {
    final imageService = ref.read(imageServiceProvider);
    final result = await imageService.pickAndProcessImage();
    
    if (result == null) return null;

    // Save to local image map
    final box = ref.read(localImageMapBoxProvider);
    await box.put(result.filename, result.localPath);

    // Add to upload state
    state = {
      ...state,
      result.filename: ImageUploadStatus(
        filename: result.filename,
        isUploading: false,
        isUploaded: false,
      ),
    };

    // Trigger background upload
    _uploadImageInBackground(result.filename, result.file);

    return result.filename;
  }

  /// Upload image to GitHub in background
  Future<void> _uploadImageInBackground(String filename, File file) async {
    final config = _config;
    if (config == null) return;

    // Mark as uploading
    state = {
      ...state,
      filename: ImageUploadStatus(
        filename: filename,
        isUploading: true,
        isUploaded: false,
      ),
    };

    final uploadService = ref.read(githubUploadServiceProvider);
    final result = await uploadService.uploadImage(
      config: config,
      file: file,
      filename: filename,
    );

    // Update status based on result
    switch (result) {
      case UploadSuccess():
        state = {
          ...state,
          filename: ImageUploadStatus(
            filename: filename,
            isUploading: false,
            isUploaded: true,
          ),
        };
      case UploadFailure(message: final message):
        state = {
          ...state,
          filename: ImageUploadStatus(
            filename: filename,
            isUploading: false,
            isUploaded: false,
            error: message,
          ),
        };
    }
  }

  /// Retry upload for a failed image
  Future<void> retryUpload(String filename) async {
    final box = ref.read(localImageMapBoxProvider);
    final localPath = box.get(filename);
    
    if (localPath == null) return;
    
    final file = File(localPath);
    if (!await file.exists()) return;

    await _uploadImageInBackground(filename, file);
  }

  /// Get upload status for a filename
  ImageUploadStatus? getStatus(String filename) {
    return state[filename];
  }

  /// Check if a filename has a local file
  String? getLocalPath(String filename) {
    final box = ref.read(localImageMapBoxProvider);
    return box.get(filename);
  }

  /// Generate markdown image syntax
  String generateMarkdownImage(String filename, {String alt = 'image'}) {
    final config = _config;
    final assetsPath = config?.assetsPath ?? 'assets/images';
    // Clean path
    final cleanPath = assetsPath
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    return '![$alt](/$cleanPath/$filename)';
  }
}

/// Provider to resolve image paths for preview
/// Returns local file path if available, otherwise GitHub raw URL
@riverpod
class ImageResolver extends _$ImageResolver {
  @override
  void build() {}

  /// Resolve an image URL/path from markdown to a displayable source
  /// Returns (isLocal, path/url)
  (bool, String) resolveImagePath(String markdownPath) {
    // Extract filename from markdown path
    // e.g., "/assets/images/img_123.jpg" -> "img_123.jpg"
    final filename = markdownPath.split('/').last;

    // Check local image map
    final box = ref.read(localImageMapBoxProvider);
    final localPath = box.get(filename);

    if (localPath != null && File(localPath).existsSync()) {
      return (true, localPath);
    }

    // Build GitHub raw URL
    final configState = ref.read(configNotifierProvider);
    if (configState is ConfigLoaded) {
      final config = configState.config;
      
      // Handle relative paths
      String cleanPath = markdownPath;
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }
      
      final rawUrl = 'https://raw.githubusercontent.com/'
          '${config.repoOwner}/${config.repoName}/${config.branch}/$cleanPath';
      
      return (false, rawUrl);
    }

    // Fallback - return original path
    return (false, markdownPath);
  }

  /// Get authorization headers for private repos
  Future<Map<String, String>?> getAuthHeaders() async {
    final secureStorage = ref.read(secureStorageProvider);
    final token = await secureStorage.getToken();
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    return null;
  }
}

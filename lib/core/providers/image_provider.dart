import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_config.dart';
import '../services/dio_client.dart';
import '../services/github_upload_service.dart';
import '../services/image_service.dart';
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
  return GitHubUploadService(dio: ref.watch(apiClientProvider).dio);
}

/// Auth headers for loading raw.githubusercontent.com images in the
/// editor preview (private repos reject unauthenticated raw fetches).
/// Reads the token via the same source as the shared ApiClient.
@riverpod
Future<Map<String, String>?> imageAuthHeaders(Ref ref) {
  return ref.watch(apiClientProvider).authHeaders();
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

/// Notifier for managing media (image + video) operations
/// keepAlive so upload statuses survive while the editor preview
/// subscribes/unsubscribes (overlays keep updating mid-upload)
@Riverpod(keepAlive: true)
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

  /// Pick and process an image from gallery or camera
  /// Returns the filename for markdown insertion, or null if cancelled
  Future<String?> pickImage({bool fromCamera = false}) async {
    final imageService = ref.read(imageServiceProvider);
    final result = fromCamera
        ? await imageService.captureAndProcessImage()
        : await imageService.pickAndProcessImage();

    if (result == null) return null;

    return _registerAndUpload(result);
  }

  /// Pick a video from gallery, compress it (slow - [onCompressionStart]
  /// fires once the picker returns, before compression begins), and
  /// upload it. Returns the filename for embed insertion, or null if
  /// cancelled. Throws when compression fails or the result exceeds the
  /// upload size limit.
  Future<String?> pickVideo({void Function()? onCompressionStart}) async {
    final imageService = ref.read(imageServiceProvider);
    final pickedFile = await imageService.pickVideoFile();

    if (pickedFile == null) return null;

    onCompressionStart?.call();
    final result = await imageService.compressAndSaveVideo(pickedFile);

    return _registerAndUpload(result);
  }

  /// Track a processed media file locally and start its background upload
  Future<String> _registerAndUpload(ProcessedMedia result) async {
    // Save to local media map
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
    _uploadMediaInBackground(result.filename, result.file);

    return result.filename;
  }

  /// Upload a media file to GitHub in background
  Future<void> _uploadMediaInBackground(String filename, File file) async {
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
      commitMessage: filename.endsWith('.mp4')
          ? 'Add video: $filename'
          : 'Add image: $filename',
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

  /// Retry upload for a failed media file
  Future<void> retryUpload(String filename) async {
    final box = ref.read(localImageMapBoxProvider);
    final localPath = box.get(filename);

    if (localPath == null) return;

    final file = File(localPath);
    if (!await file.exists()) return;

    await _uploadMediaInBackground(filename, file);
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

  /// Generate markdown image syntax. The URL is root-relative and
  /// baseurl-aware: '/assets/images/x.jpg' on a root site,
  /// '/myrepo/assets/images/x.jpg' on a project site.
  String generateMarkdownImage(String filename, {String alt = 'image'}) {
    final config = _config;
    final assetsPath = config?.assetsPath ?? 'assets/images';
    final baseurl = normalizeBaseurl(config?.baseurl ?? '');
    // Clean path
    final cleanPath = assetsPath
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    return '![$alt]($baseurl/$cleanPath/$filename)';
  }

  /// Generate the raw-HTML video embed used in posts (kramdown with
  /// `input: GFM` passes it through). Same root-relative, baseurl-aware
  /// src shape as [generateMarkdownImage].
  String generateVideoEmbed(String filename) {
    final config = _config;
    final assetsPath = config?.assetsPath ?? 'assets/images';
    final baseurl = normalizeBaseurl(config?.baseurl ?? '');
    final cleanPath = assetsPath
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    return '<div style="text-align: center;">\n'
        '  <video autoplay loop muted playsinline controls '
        'style="max-width: 100%; border-radius: 12px;">\n'
        '    <source src="$baseurl/$cleanPath/$filename" type="video/mp4">\n'
        '  </video>\n'
        '</div>';
  }
}

/// URI scheme used to route video placeholders through the markdown
/// preview's image builder (`jekyllpress-video:/<filename>` - the
/// single-slash path form keeps the filename case intact, a '//' host
/// would be lowercased by Uri.parse)
const String videoPreviewScheme = 'jekyllpress-video';

/// Matches a raw HTML <video> block, optionally wrapped in a <div>
final RegExp _videoBlockPattern = RegExp(
  r'(?:<div[^>]*>\s*)?<video[^>]*>[\s\S]*?</video>(?:\s*</div>)?',
  caseSensitive: false,
);

/// flutter_markdown does not render raw HTML, so <video> embeds show as
/// literal text in the preview. Replace each block with a synthetic image
/// whose URI carries the video filename; the preview's image builder
/// renders it as a video placeholder card.
String preprocessPreviewMarkdown(String markdown) {
  return markdown.replaceAllMapped(_videoBlockPattern, (match) {
    final block = match.group(0)!;
    final src = RegExp(r'''src\s*=\s*["']([^"']+)["']''')
        .firstMatch(block)
        ?.group(1);
    final filename = src?.split('/').last ?? '';
    return '![video]($videoPreviewScheme:/$filename)';
  });
}

/// Normalize a configured baseurl to '' or '/segment[/…]' (leading slash,
/// no trailing slash), the shape Jekyll expects
String normalizeBaseurl(String baseurl) {
  var cleaned = baseurl.trim().replaceAll(RegExp(r'/+$'), '');
  if (cleaned.isEmpty || cleaned == '/') return '';
  if (!cleaned.startsWith('/')) cleaned = '/$cleaned';
  return cleaned;
}

/// Strip the site [baseurl] prefix from a root-relative markdown [path]
/// so it maps back to a repo-relative file path. '/myrepo/assets/x.jpg'
/// with baseurl '/myrepo' -> '/assets/x.jpg'; no-op when baseurl is ''.
String stripBaseurl(String path, String baseurl) {
  final prefix = normalizeBaseurl(baseurl);
  if (prefix.isEmpty) return path;
  if (path == prefix) return '/';
  if (path.startsWith('$prefix/')) return path.substring(prefix.length);
  return path;
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

      // Site URLs carry the baseurl prefix on project sites - strip it
      // before mapping to a repo-relative path
      String cleanPath = stripBaseurl(markdownPath, config.baseurl);
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
  /// (same token source as the shared ApiClient)
  Future<Map<String, String>?> getAuthHeaders() {
    return ref.read(apiClientProvider).authHeaders();
  }
}

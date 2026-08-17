import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';

/// Result of media processing (compressed image or video saved locally)
class ProcessedMedia {
  final String filename;
  final String localPath;
  final File file;

  const ProcessedMedia({
    required this.filename,
    required this.localPath,
    required this.file,
  });
}

/// Build a timestamped media filename with millisecond precision,
/// e.g. img_20260817_142530_123.jpg (fixes same-second overwrites)
String buildMediaFilename(String prefix, String extension, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final timestamp = '${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}_'
      '${now.millisecond.toString().padLeft(3, '0')}';
  return '${prefix}_$timestamp.$extension';
}

/// If [filename] is taken per [exists], append -2, -3, ... before the
/// extension until a free name is found (img_x.jpg -> img_x-2.jpg)
String deduplicateFilename(String filename, bool Function(String) exists) {
  if (!exists(filename)) return filename;
  final dot = filename.lastIndexOf('.');
  final stem = dot == -1 ? filename : filename.substring(0, dot);
  final ext = dot == -1 ? '' : filename.substring(dot);
  var suffix = 2;
  while (exists('$stem-$suffix$ext')) {
    suffix++;
  }
  return '$stem-$suffix$ext';
}

/// Service for picking, compressing, and managing media (images + videos)
class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Compressed videos larger than this would make the base64
  /// contents-API PUT slow/OOM-prone, so uploads are refused above it
  static const int maxVideoUploadBytes = 25 * 1024 * 1024;

  /// Directory for storing local media. The physical name stays
  /// 'local_images' so files from pre-video builds are still found.
  Future<Directory> get _localMediaDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(appDir.path, 'local_images'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Pick an image from gallery and process it
  /// Returns null if user cancels
  Future<ProcessedMedia?> pickAndProcessImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false, // Skip EXIF to improve privacy
    );

    if (pickedFile == null) return null;

    return await _processImage(File(pickedFile.path));
  }

  /// Pick an image from camera and process it
  Future<ProcessedMedia?> captureAndProcessImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );

    if (pickedFile == null) return null;

    return await _processImage(File(pickedFile.path));
  }

  /// Pick a video from gallery (no processing yet, so the caller can
  /// show a compression indicator before the slow part starts)
  /// Returns null if user cancels
  Future<XFile?> pickVideoFile() {
    return _picker.pickVideo(source: ImageSource.gallery);
  }

  /// Compress a picked video (720p-class H.264) and save it locally.
  /// Throws with a clear message when the compressed file still exceeds
  /// [maxVideoUploadBytes].
  Future<ProcessedMedia> compressAndSaveVideo(XFile pickedFile) async {
    final info = await VideoCompress.compressVideo(
      pickedFile.path,
      quality: VideoQuality.MediumQuality, // 720p-class
      deleteOrigin: false,
    );

    final compressed = info?.file;
    if (compressed == null) {
      throw Exception('Failed to compress video');
    }

    try {
      // Guard the base64 contents-API PUT: refuse oversized uploads
      final sizeBytes = await compressed.length();
      if (sizeBytes > maxVideoUploadBytes) {
        final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
        throw Exception(
            'Video is still ${sizeMb}MB after compression (limit 25MB). '
            'Try a shorter clip.');
      }

      final mediaDir = await _localMediaDir;
      final filename = deduplicateFilename(
        buildMediaFilename('vid', 'mp4', DateTime.now()),
        (name) => File(path.join(mediaDir.path, name)).existsSync(),
      );
      final destPath = path.join(mediaDir.path, filename);
      final destFile = await compressed.copy(destPath);

      return ProcessedMedia(
        filename: filename,
        localPath: destPath,
        file: destFile,
      );
    } finally {
      // Drop the plugin's cache copy; the original video is untouched
      await VideoCompress.deleteAllCache();
    }
  }

  /// Process image: compress and save locally
  Future<ProcessedMedia> _processImage(File sourceFile) async {
    final mediaDir = await _localMediaDir;

    // Millisecond timestamp + collision suffix so two picks in the same
    // second can't overwrite each other
    final filename = deduplicateFilename(
      buildMediaFilename('img', 'jpg', DateTime.now()),
      (name) => File(path.join(mediaDir.path, name)).existsSync(),
    );
    final destPath = path.join(mediaDir.path, filename);

    // Compress image
    // Max 1080px width, 85% quality, strip EXIF
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      sourceFile.absolute.path,
      minWidth: 1080,
      minHeight: 1080,
      quality: 85,
      keepExif: false, // Strip EXIF data
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null) {
      throw Exception('Failed to compress image');
    }

    // Save compressed image
    final destFile = File(destPath);
    await destFile.writeAsBytes(compressedBytes);

    return ProcessedMedia(
      filename: filename,
      localPath: destPath,
      file: destFile,
    );
  }

  /// Get local file path for a filename if it exists
  Future<String?> getLocalPath(String filename) async {
    final mediaDir = await _localMediaDir;
    final filePath = path.join(mediaDir.path, filename);
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  /// Delete a local media file
  Future<void> deleteLocalImage(String filename) async {
    final mediaDir = await _localMediaDir;
    final filePath = path.join(mediaDir.path, filename);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clear all local media (cleanup)
  Future<void> clearAllLocalImages() async {
    final mediaDir = await _localMediaDir;
    if (await mediaDir.exists()) {
      await mediaDir.delete(recursive: true);
    }
  }
}

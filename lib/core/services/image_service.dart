import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Result of image processing
class ProcessedImage {
  final String filename;
  final String localPath;
  final File file;

  const ProcessedImage({
    required this.filename,
    required this.localPath,
    required this.file,
  });
}

/// Service for picking, compressing, and managing images
class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Directory for storing local images
  Future<Directory> get _localImagesDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, 'local_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Pick an image from gallery and process it
  /// Returns null if user cancels
  Future<ProcessedImage?> pickAndProcessImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false, // Skip EXIF to improve privacy
    );

    if (pickedFile == null) return null;

    return await _processImage(File(pickedFile.path));
  }

  /// Pick an image from camera and process it
  Future<ProcessedImage?> captureAndProcessImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );

    if (pickedFile == null) return null;

    return await _processImage(File(pickedFile.path));
  }

  /// Process image: compress and save locally
  Future<ProcessedImage> _processImage(File sourceFile) async {
    // Generate timestamped filename
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final filename = 'img_$timestamp.jpg';

    // Get destination path
    final imagesDir = await _localImagesDir;
    final destPath = path.join(imagesDir.path, filename);

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

    return ProcessedImage(
      filename: filename,
      localPath: destPath,
      file: destFile,
    );
  }

  /// Get local file path for a filename if it exists
  Future<String?> getLocalPath(String filename) async {
    final imagesDir = await _localImagesDir;
    final filePath = path.join(imagesDir.path, filename);
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  /// Delete a local image
  Future<void> deleteLocalImage(String filename) async {
    final imagesDir = await _localImagesDir;
    final filePath = path.join(imagesDir.path, filename);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clear all local images (cleanup)
  Future<void> clearAllLocalImages() async {
    final imagesDir = await _localImagesDir;
    if (await imagesDir.exists()) {
      await imagesDir.delete(recursive: true);
    }
  }
}

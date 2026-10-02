import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';
import '../platform.dart';
import '../utils/mp4_metadata.dart';

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

  /// Longest edge of an uploaded image, in pixels.
  ///
  /// Applied by image_picker, whose maxWidth/maxHeight ARE a bounding box:
  /// the image is scaled so neither side exceeds them, preserving aspect
  /// ratio and honouring EXIF orientation on the platform side. Desktop
  /// image_picker ignores them, so [encodeJpeg] applies it there.
  ///
  /// flutter_image_compress cannot do this. Its minWidth/minHeight are
  /// MINIMUMS on both axes - it computes
  /// `scale = max(1, min(w / minWidth, h / minHeight))` - so passing the same
  /// number twice pins the SHORT edge, not the long one. That is why asking
  /// it for "1080" here used to emit images about 1620px on their long edge,
  /// and a workflow in the site repo was quietly resizing them afterwards.
  static const double maxImageEdge = 1600;

  /// Large enough that flutter_image_compress's scale factor stays at 1, so
  /// the compress pass only re-encodes and never resizes.
  static const int _noResize = 100000;

  /// False on desktop: image_picker_macos/linux have no camera.
  bool get canUseCamera => _picker.supportsImageSource(ImageSource.camera);

  /// Directory for storing local media. The physical name stays
  /// 'local_images' so files from pre-video builds are still found.
  Future<Directory> get _localMediaDir async {
    final appDir = await appDataDir();
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
      maxWidth: maxImageEdge,
      maxHeight: maxImageEdge,
      requestFullMetadata: false, // Skip EXIF to improve privacy
    );

    if (pickedFile == null) return null;

    return await _processImage(File(pickedFile.path));
  }

  /// Pick an image from camera and process it
  Future<ProcessedMedia?> captureAndProcessImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxImageEdge,
      maxHeight: maxImageEdge,
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

  /// Compress a picked video (H.264, short edge capped at 640px), blank its
  /// metadata and save it locally.
  /// Throws with a clear message when the compressed file still exceeds
  /// [maxVideoUploadBytes].
  Future<ProcessedMedia> compressAndSaveVideo(XFile pickedFile) async {
    final info = await VideoCompress.compressVideo(
      pickedFile.path,
      // MediumQuality maps to DefaultVideoStrategy.atMost(640) on Android:
      // the SHORT edge is capped at 640px, it is not 720p
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );

    // A cancelled export reports the SOURCE path: never take that as output
    final compressed = info?.file;
    if (compressed == null ||
        info!.isCancel == true ||
        !await compressed.exists()) {
      // Android reports a failed transcode as null and can leave a partial
      // file in its app-private video_compress folder. On macOS that folder
      // is $TMPDIR/video_compress, shared by every app using the plugin, so
      // it is never wiped there.
      if (!isDesktop) await VideoCompress.deleteAllCache();
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

      // The re-encode copies the source's metadata, GPS location included
      // (AVAssetExportSession translates it, MediaMuxer.setLocation
      // reproduces it): blank it in place
      if (await stripMp4Metadata(destFile) == null) {
        await destFile.delete();
        throw Exception(
            'Could not remove the metadata from the compressed video');
      }

      return ProcessedMedia(
        filename: filename,
        localPath: destPath,
        file: destFile,
      );
    } finally {
      // Only this call's output; the plugin's folder may hold another
      // app's in-progress export on macOS. The original video is untouched.
      try {
        await compressed.delete();
      } catch (_) {}
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

    if (isDesktop) {
      // package:image has no HEIC decoder; macOS has sips, Linux has nothing
      File? converted;
      if (isHeic(sourceFile.path)) {
        if (!isMacOS) {
          throw const FormatException(
              'HEIC is not supported on Linux - export the photo as JPEG first');
        }
        converted = await convertHeicWithSips(
            sourceFile.path, (await appCacheDir()).path);
      }
      try {
        final destFile = await encodeJpeg(
            (converted ?? sourceFile).path, destPath,
            maxEdge: maxImageEdge.toInt(), quality: 85);
        return ProcessedMedia(
            filename: filename, localPath: destPath, file: destFile);
      } finally {
        await converted?.delete();
      }
    }

    // Re-encode to JPEG at quality 85 and drop EXIF. The picker has already
    // bounded the dimensions, so this pass must NOT resize again - hence the
    // deliberately huge minWidth/minHeight, which keep the plugin's scale
    // factor pinned at 1.
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      sourceFile.absolute.path,
      minWidth: _noResize,
      minHeight: _noResize,
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

  /// Clear all local media (logout / repository-change cleanup)
  Future<void> clearAllLocalImages() async {
    final mediaDir = await _localMediaDir;
    if (await mediaDir.exists()) {
      await mediaDir.delete(recursive: true);
    }
  }
}

/// Apple's HEIF container: iPhone photos, Photos.app exports
bool isHeic(String file) =>
    const {'.heic', '.heif'}.contains(path.extension(file).toLowerCase());

/// macOS: decode a HEIC with the system's own `sips` (on every Mac) into a
/// near-lossless JPEG in [dir]; [encodeJpeg] then resizes it and drops the
/// metadata. The caller deletes the result.
Future<File> convertHeicWithSips(String source, String dir) async {
  final out = File(path.join(
      dir, 'heic_${DateTime.now().microsecondsSinceEpoch}.jpg'));
  final result = await Process.run('sips', [
    '-s', 'format', 'jpeg', '-s', 'formatOptions', 'best', // intermediate
    source, '--out', out.path,
  ]);
  if (result.exitCode != 0 || !out.existsSync()) {
    throw FormatException(
        'Could not convert the HEIC photo: ${result.stderr}'.trim());
  }
  return out;
}

/// JPEG at [target], long edge capped at [maxEdge] (never upscaled), EXIF
/// rotation applied and every other EXIF field (GPS) dropped. Pure Dart on a
/// background isolate (~1 s per 12 MP photo on an M2), for desktop, where
/// image_picker returns the untouched original. HEIC must be converted
/// first ([convertHeicWithSips]).
Future<File> encodeJpeg(String source, String target,
    {required int maxEdge, required int quality}) {
  return Isolate.run(() {
    // package:image's JPEG decoder applies the EXIF orientation itself.
    var image = img.decodeImage(File(source).readAsBytesSync());
    if (image == null) {
      throw const FormatException('Unsupported image - use JPEG, PNG or WebP');
    }
    final scale = maxEdge / math.max(image.width, image.height);
    if (scale < 1) {
      image = img.copyResize(image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.average);
    }
    // The decoder keeps GPS & co, and encodeJpg would write them back.
    image.exif = img.ExifData();
    return File(target)
      ..writeAsBytesSync(img.encodeJpg(image, quality: quality));
  });
}

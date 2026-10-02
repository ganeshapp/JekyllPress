import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jekyllpress/core/services/image_service.dart';

void main() {
  group('buildMediaFilename', () {
    test('formats prefix_YYYYMMDD_HHMMSS_mmm.ext with zero padding', () {
      expect(
        buildMediaFilename('img', 'jpg', DateTime(2026, 8, 7, 9, 5, 3, 42)),
        'img_20260807_090503_042.jpg',
      );
    });

    test('video prefix and extension', () {
      expect(
        buildMediaFilename(
            'vid', 'mp4', DateTime(2026, 12, 31, 23, 59, 59, 999)),
        'vid_20261231_235959_999.mp4',
      );
    });

    test('same-second picks differ by millisecond', () {
      final first =
          buildMediaFilename('img', 'jpg', DateTime(2026, 1, 1, 0, 0, 1, 1));
      final second =
          buildMediaFilename('img', 'jpg', DateTime(2026, 1, 1, 0, 0, 1, 2));
      expect(first, isNot(second));
    });
  });

  group('deduplicateFilename', () {
    test('returns the name unchanged when free', () {
      expect(deduplicateFilename('img_1.jpg', (_) => false), 'img_1.jpg');
    });

    test('appends -2 before the extension on collision', () {
      expect(
        deduplicateFilename('img_1.jpg', (name) => name == 'img_1.jpg'),
        'img_1-2.jpg',
      );
    });

    test('increments the suffix until a free name is found', () {
      const taken = {'vid_1.mp4', 'vid_1-2.mp4', 'vid_1-3.mp4'};
      expect(deduplicateFilename('vid_1.mp4', taken.contains), 'vid_1-4.mp4');
    });

    test('handles names without an extension', () {
      expect(deduplicateFilename('file', (name) => name == 'file'), 'file-2');
    });
  });

  group('encodeJpeg (desktop)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('encode_jpeg'));
    tearDown(() => dir.deleteSync(recursive: true));

    String write(String name, List<int> bytes) =>
        (File('${dir.path}/$name')..writeAsBytesSync(bytes)).path;
    Future<img.Image> encode(String source) async => img.decodeJpg(
        (await encodeJpeg(source, '${dir.path}/out.jpg',
                maxEdge: 160, quality: 85))
            .readAsBytesSync())!;

    test('applies EXIF rotation, caps the long edge, drops GPS', () async {
      final photo = img.Image(width: 400, height: 300);
      photo.exif.imageIfd.orientation = 6; // shot in portrait
      photo.exif.gpsIfd.setGpsLocation(latitude: 37.5, longitude: 127.0);

      final out = await encode(write('in.jpg', img.encodeJpg(photo)));

      expect([out.width, out.height], [120, 160]);
      expect(out.exif.isEmpty, isTrue);
    });

    test('never upscales a small image', () async {
      final out = await encode(
          write('in.png', img.encodePng(img.Image(width: 100, height: 50))));
      expect([out.width, out.height], [100, 50]);
    });

    test('rejects a file that is not an image', () {
      expect(encode(write('in.txt', 'not an image'.codeUnits)),
          throwsFormatException);
    });
  });

  group('HEIC on desktop', () {
    test('isHeic matches .heic and .heif in any case', () {
      expect(isHeic('IMG_0001.HEIC'), isTrue);
      expect(isHeic('export/photo.heif'), isTrue);
      expect(isHeic('photo.jpg'), isFalse);
      expect(isHeic('heic'), isFalse);
    });

    // sips ships with macOS only; CI's Linux runner skips these two
    final skip = !Platform.isMacOS;
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('heic'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('sips turns a HEIC into a JPEG that encodeJpeg accepts', () async {
      // A real HEIC, made the same way macOS makes them
      final png = File('${dir.path}/in.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 40, height: 30)));
      final made = Process.runSync(
          'sips', ['-s', 'format', 'heic', png.path, '--out', '${dir.path}/in.heic']);
      expect(made.exitCode, 0, reason: '${made.stderr}');

      final jpeg = await convertHeicWithSips('${dir.path}/in.heic', dir.path);
      final out = img.decodeJpg((await encodeJpeg(
              jpeg.path, '${dir.path}/out.jpg', maxEdge: 160, quality: 85))
          .readAsBytesSync())!;

      expect(jpeg.path, startsWith(dir.path));
      expect([out.width, out.height], [40, 30]);
    }, skip: skip);

    test('a file sips cannot read fails with a clear message', () async {
      final bogus = File('${dir.path}/in.heic')..writeAsStringSync('nope');
      expect(convertHeicWithSips(bogus.path, dir.path), throwsFormatException);
    }, skip: skip);
  });
}

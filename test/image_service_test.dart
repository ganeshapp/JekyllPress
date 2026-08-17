import 'package:flutter_test/flutter_test.dart';
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
}

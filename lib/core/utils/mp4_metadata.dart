import 'dart:io';
import 'dart:typed_data';

/// Blank an MP4's metadata in place: inside the top-level `moov` box, every
/// `udta` and `meta` child - where recorders keep the GPS location
/// (Android's `©xyz`, Apple's `com.apple.quicktime.location.ISO6709`) -
/// has its type overwritten with `free`, the box type players skip. Sizes
/// are untouched, so chunk offsets stay valid and nothing else moves.
///
/// Returns how many boxes were blanked, or null when the file could not be
/// parsed with confidence; it is then left untouched.
Future<int?> stripMp4Metadata(File file) async {
  final raf = await file.open(mode: FileMode.append); // read + write
  try {
    final end = await raf.length();
    // Walk everything first, patch after: a malformed file stays untouched
    final typeOffsets = <int>[];
    for (var at = 0; at < end;) {
      final box = await _header(raf, at, end);
      if (box == null) return null;
      if (box.type == 'moov') {
        for (var child = at + box.headerSize; child < at + box.size;) {
          final inner = await _header(raf, child, at + box.size);
          if (inner == null) return null;
          if (inner.type == 'udta' || inner.type == 'meta') {
            typeOffsets.add(child + 4);
          }
          child += inner.size;
        }
      }
      at += box.size;
    }
    for (final offset in typeOffsets) {
      await raf.setPosition(offset);
      await raf.writeFrom('free'.codeUnits);
    }
    return typeOffsets.length;
  } finally {
    await raf.close();
  }
}

class _Box {
  final String type;
  final int size;
  final int headerSize;
  const _Box(this.type, this.size, this.headerSize);
}

/// The box header at [at], or null when it does not fit before [end]
Future<_Box?> _header(RandomAccessFile raf, int at, int end) async {
  if (end - at < 8) return null;
  await raf.setPosition(at);
  final bytes = await raf.read(16);
  final data = ByteData.sublistView(bytes);
  var size = data.getUint32(0);
  var headerSize = 8;
  if (size == 1) {
    // 64-bit size follows the type
    if (bytes.length < 16) return null;
    size = data.getUint64(8);
    headerSize = 16;
  } else if (size == 0) {
    size = end - at; // runs to the end of the enclosing box
  }
  if (size < headerSize || size > end - at) return null;
  return _Box(String.fromCharCodes(bytes, 4, 8), size, headerSize);
}

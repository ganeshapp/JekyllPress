import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/utils/mp4_metadata.dart';

/// An ISO BMFF box: 32-bit size, 4-char type, payload. [large] writes the
/// 64-bit form (size field 1, then the real size after the type).
Uint8List box(String type, List<int> payload, {bool large = false}) {
  final header = large ? 16 : 8;
  final bytes = ByteData(header + payload.length);
  bytes.setUint32(0, large ? 1 : header + payload.length);
  for (var i = 0; i < 4; i++) {
    bytes.setUint8(4 + i, type.codeUnitAt(i));
  }
  if (large) bytes.setUint64(8, header + payload.length);
  return Uint8List.fromList(
      bytes.buffer.asUint8List().sublist(0, header) + payload);
}

final ftyp = box('ftyp', 'isom'.codeUnits + [0, 0, 2, 0] + 'isom'.codeUnits);
final mvhd = box('mvhd', List.filled(100, 7));
// '©xyz' holds the location: the first byte is 0xA9, not a 7-bit char
final xyz = box('©xyz', '+37.5665+126.9780/'.codeUnits);
final udta = box('udta', xyz);
final meta = box('meta', [0, 0, 0, 0] + box('hdlr', List.filled(24, 0)));
final mdat = box('mdat', List.filled(300, 0xAB));

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mp4_metadata'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(List<int> bytes) =>
      File('${dir.path}/clip.mp4')..writeAsBytesSync(bytes);

  /// [input] with the 4 type bytes at each of [typeOffsets] set to 'free'
  List<int> freed(List<int> input, List<int> typeOffsets) {
    final out = [...input];
    for (final at in typeOffsets) {
      out.setRange(at, at + 4, 'free'.codeUnits);
    }
    return out;
  }

  test('ftyp + moov{mvhd, udta{©xyz}} + mdat: udta becomes free, nothing '
      'else changes', () async {
    final moov = box('moov', mvhd + udta);
    final input = ftyp + moov + mdat;
    final file = write(input);

    expect(await stripMp4Metadata(file), 1);

    final udtaType = ftyp.length + 8 + mvhd.length + 4;
    expect(file.readAsBytesSync(), freed(input, [udtaType]));
  });

  test('moov/meta is blanked too; a top-level meta is not', () async {
    final moov = box('moov', mvhd + meta + udta);
    final input = ftyp + moov + meta + mdat;
    final file = write(input);

    expect(await stripMp4Metadata(file), 2);

    final metaType = ftyp.length + 8 + mvhd.length + 4;
    final udtaType = metaType - 4 + meta.length + 4;
    expect(file.readAsBytesSync(), freed(input, [metaType, udtaType]));
  });

  test('64-bit box sizes are followed', () async {
    final moov = box('moov', mvhd + udta, large: true);
    final input = ftyp + box('mdat', List.filled(300, 1), large: true) + moov;
    final file = write(input);

    expect(await stripMp4Metadata(file), 1);

    final udtaType = input.length - moov.length + 16 + mvhd.length + 4;
    expect(file.readAsBytesSync(), freed(input, [udtaType]));
  });

  test('a moov that is the last box with size 0 (to end of file)', () async {
    final moov = box('moov', mvhd + udta);
    moov.buffer.asByteData().setUint32(0, 0);
    final input = ftyp + mdat + moov;
    final file = write(input);

    expect(await stripMp4Metadata(file), 1);
  });

  test('no metadata boxes: nothing to do, file identical', () async {
    final input = ftyp + box('moov', mvhd) + mdat;
    final file = write(input);

    expect(await stripMp4Metadata(file), 0);
    expect(file.readAsBytesSync(), input);
  });

  test('a box that overruns the file: null, file untouched', () async {
    final input = ftyp + box('moov', mvhd + udta) + mdat.sublist(0, 20);
    final file = write(input);

    expect(await stripMp4Metadata(file), isNull);
    expect(file.readAsBytesSync(), input);
  });

  test('a child that overruns moov: null, file untouched', () async {
    final moov = box('moov', mvhd + udta);
    // Lie about mvhd's size so the next child header lands past moov
    moov.buffer.asByteData().setUint32(8, moov.length);
    final input = ftyp + moov + mdat;
    final file = write(input);

    expect(await stripMp4Metadata(file), isNull);
    expect(file.readAsBytesSync(), input);
  });

  test('not an MP4 at all: null, file untouched', () async {
    final input = List<int>.filled(5, 0);
    final file = write(input);

    expect(await stripMp4Metadata(file), isNull);
    expect(file.readAsBytesSync(), input);
  });
}

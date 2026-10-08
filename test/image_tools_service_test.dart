import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:campussetu/features/tools/services/image_tools_service.dart';

void main() {
  test('WebP selection produces an actual WebP file', () async {
    final source = Uint8List.fromList(
      img.encodePng(img.Image(width: 16, height: 16)),
    );

    final result = await ImageToolsService.convertImage(
      source,
      targetFormat: 'webp',
      quality: 80,
    );

    expect(result.format, 'webp');
    expect(result.bytes.length, greaterThan(12));
    expect(String.fromCharCodes(result.bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(result.bytes.sublist(8, 12)), 'WEBP');
    expect(img.decodeWebP(result.bytes), isNotNull);
  });

  test('unsupported image output formats fail clearly', () async {
    final source = Uint8List.fromList(
      img.encodePng(img.Image(width: 2, height: 2)),
    );

    await expectLater(
      ImageToolsService.convertImage(source, targetFormat: 'tiff'),
      throwsArgumentError,
    );
  });
}

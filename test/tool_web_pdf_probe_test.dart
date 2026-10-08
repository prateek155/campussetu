import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:campussetu/features/tools/services/pdf_tools_service.dart';

void main() {
  test('Pure-Dart PDF embedded image extractor handles empty streams safely', () {
    final emptyBytes = Uint8List(0);
    final images = PdfToolsService.extractEmbeddedImages(emptyBytes);
    expect(images, isEmpty);
  });

  test('extractOrRenderPdfImages completes without error on Web environment', () async {
    final emptyBytes = Uint8List(0);
    final images = await PdfToolsService.extractOrRenderPdfImages(emptyBytes);
    expect(images, isEmpty);
  });
}

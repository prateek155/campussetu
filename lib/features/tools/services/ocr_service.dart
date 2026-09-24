// lib/features/tools/services/ocr_service.dart
import 'dart:typed_data';
import 'pdf_tools_service.dart';

export 'ocr_service_mobile.dart' if (dart.library.html) 'ocr_service_web.dart';

class OcrService {
  static Uint8List exportToPdf(String text, {String title = 'Extracted Document'}) {
    return PdfToolsService.txtToPdf(text, title: title);
  }

  static Uint8List exportToDocx(String text) {
    return PdfToolsService.txtToDocx(text);
  }
}

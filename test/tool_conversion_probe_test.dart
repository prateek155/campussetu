import 'dart:typed_data';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campussetu/features/tools/services/pdf_tools_service.dart';

void main() {
  test('PDF with an explicit null outline converts to DOCX and PPTX', () async {
    final input = _minimalPdfWithNullOutlines();

    final word = await PdfToolsService.pdfToWordDocx(input);
    expect(word.pageCount, 1);
    final docxArchive = ZipDecoder().decodeBytes(word.docxBytes);
    expect(docxArchive.findFile('word/document.xml'), isNotNull);
    expect(docxArchive.findFile('[Content_Types].xml'), isNotNull);

    final pptx = await PdfToolsService.pdfToPptx(input);
    final pptxArchive = ZipDecoder().decodeBytes(pptx);
    expect(pptxArchive.findFile('ppt/presentation.xml'), isNotNull);
    expect(pptxArchive.findFile('ppt/slides/slide1.xml'), isNotNull);
    expect(pptxArchive.findFile('[Content_Types].xml'), isNotNull);
  });
}

Uint8List _minimalPdfWithNullOutlines() {
  const objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R /Outlines null >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << >> /Contents 4 0 R >>',
    '<< /Length 0 >>\nstream\n\nendstream',
  ];

  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(latin1.encode(pdf.toString()).length);
    pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }

  final xrefOffset = latin1.encode(pdf.toString()).length;
  pdf.write('xref\n0 ${objects.length + 1}\n');
  pdf.write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n');
  pdf.write('startxref\n$xrefOffset\n%%EOF');
  return Uint8List.fromList(latin1.encode(pdf.toString()));
}

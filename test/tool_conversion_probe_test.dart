import 'dart:typed_data';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campussetu/features/tools/services/pdf_tools_service.dart';

void main() {
  test('PDF with an explicit null outline converts to DOCX and PPTX', () async {
    final input = _minimalPdfWithNullOutlines();
    final wordProgress = <double>[];

    final word = await PdfToolsService.pdfToWordDocx(
      input,
      onProgress: (progress, _) => wordProgress.add(progress),
    );
    expect(word.pageCount, 1);
    final docxArchive = ZipDecoder().decodeBytes(word.docxBytes);
    final documentXml = utf8.decode(
      docxArchive.findFile('word/document.xml')!.content,
    );
    expect(documentXml, contains('Copyright © text'));
    expect(documentXml, endsWith('</w:document>'));
    expect(docxArchive.findFile('[Content_Types].xml'), isNotNull);
    expect(wordProgress.last, 1);

    final pptxProgress = <double>[];
    final pptx = await PdfToolsService.pdfToPptx(
      input,
      onProgress: (progress, _) => pptxProgress.add(progress),
    );
    final pptxArchive = ZipDecoder().decodeBytes(pptx);
    expect(pptxArchive.findFile('ppt/presentation.xml'), isNotNull);
    final slideXml = utf8.decode(
      pptxArchive.findFile('ppt/slides/slide1.xml')!.content,
    );
    expect(slideXml, contains('Copyright © text'));
    expect(slideXml, contains('txBox="1"'));
    expect(slideXml, isNot(contains('<p:pic>')));
    expect(slideXml.trim(), endsWith('</p:sld>'));
    expect(pptxArchive.findFile('[Content_Types].xml'), isNotNull);
    expect(pptxProgress.last, 1);
  });
}

Uint8List _minimalPdfWithNullOutlines() {
  const pageText = 'BT /F1 18 Tf 72 720 Td (Copyright \u00A9 text) Tj ET';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R /Outlines null >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length ${pageText.length} >>\nstream\n$pageText\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        '/Encoding /WinAnsiEncoding >>',
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

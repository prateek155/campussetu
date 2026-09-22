// lib/features/tools/services/pdf_tools_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractionResult {
  final String text;
  final Uint8List docxBytes;
  final int pageCount;

  PdfExtractionResult({
    required this.text,
    required this.docxBytes,
    required this.pageCount,
  });
}

class PdfToolsService {
  /// 1. PDF TO WORD (.docx)
  /// Extracts text from PDF and packages it into a valid OpenXML .docx file in pure memory.
  static Future<PdfExtractionResult> pdfToWordDocx(Uint8List pdfBytes) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    final pageCount = document.pages.count;
    
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();

    for (int i = 0; i < pageCount; i++) {
      final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
      if (i > 0) buffer.writeln('\n--- [Page ${i + 1}] ---\n');
      buffer.write(pageText);
    }
    document.dispose();

    final extractedText = buffer.toString().trim();
    final docxBytes = _createDocxFromText(extractedText);

    return PdfExtractionResult(
      text: extractedText,
      docxBytes: docxBytes,
      pageCount: pageCount,
    );
  }

  /// 2. PDF WATERMARK REMOVER
  /// Clears/overlays clean background box over watermark locations across pages.
  static Future<Uint8List> removePdfWatermark(
    Uint8List pdfBytes, {
    required Rect relativeArea, // Values 0.0 to 1.0 representing percentage of page
    List<int>? targetPages, // 1-indexed. If null, applies to all pages
    Color coverColor = Colors.white,
  }) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    final totalPages = document.pages.count;
    final pagesToProcess = targetPages ?? List.generate(totalPages, (i) => i + 1);

    final r = (coverColor.r * 255.0).round().clamp(0, 255);
    final g = (coverColor.g * 255.0).round().clamp(0, 255);
    final b = (coverColor.b * 255.0).round().clamp(0, 255);
    final brush = PdfSolidBrush(PdfColor(r, g, b));

    for (final pageNum in pagesToProcess) {
      if (pageNum < 1 || pageNum > totalPages) continue;
      final page = document.pages[pageNum - 1];
      final pageSize = page.size;

      final rect = Rect.fromLTWH(
        relativeArea.left * pageSize.width,
        relativeArea.top * pageSize.height,
        relativeArea.width * pageSize.width,
        relativeArea.height * pageSize.height,
      );

      page.graphics.drawRectangle(
        brush: brush,
        bounds: rect,
      );
    }

    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return outputBytes;
  }

  /// 3. WORD / TEXT TO PDF
  /// Takes editable text or docx contents and converts into a cleanly formatted PDF.
  static Future<Uint8List> wordToPdf(String text, {String title = 'Document'}) async {
    final document = PdfDocument();
    
    // Configure standard font and layout
    final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);

    PdfPage page = document.pages.add();
    double currentY = 0;

    if (title.isNotEmpty) {
      page.graphics.drawString(
        title,
        titleFont,
        bounds: Rect.fromLTWH(0, currentY, page.getClientSize().width, 30),
      );
      currentY += 40;
    }

    final textElement = PdfTextElement(
      text: text,
      font: font,
      format: PdfStringFormat(lineSpacing: 4),
    );

    final layoutFormat = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
    );

    textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, currentY, page.getClientSize().width, page.getClientSize().height - currentY),
      format: layoutFormat,
    );

    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return outputBytes;
  }

  /// 4. COMPRESS PDF
  /// Recompresses PDF document streams and fonts to reduce file size.
  static Future<Uint8List> compressPdf(Uint8List pdfBytes, {int qualityLevel = 2}) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    
    // Set maximum compression
    document.compressionLevel = PdfCompressionLevel.best;
    
    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return outputBytes;
  }

  /// 5. IMAGE TO PDF
  /// Converts single or multiple images into a multi-page PDF.
  static Future<Uint8List> imagesToPdf(
    List<Uint8List> imageBytesList, {
    bool fitToPage = true,
    double margin = 20,
  }) async {
    final document = PdfDocument();

    for (final bytes in imageBytesList) {
      final image = PdfBitmap(bytes);
      final page = document.pages.add();
      final clientSize = page.getClientSize();

      double drawWidth = image.width.toDouble();
      double drawHeight = image.height.toDouble();

      if (fitToPage) {
        final availableWidth = clientSize.width - (margin * 2);
        final availableHeight = clientSize.height - (margin * 2);

        final scale = (availableWidth / drawWidth < availableHeight / drawHeight)
            ? availableWidth / drawWidth
            : availableHeight / drawHeight;

        drawWidth *= scale;
        drawHeight *= scale;

        final x = margin + ((availableWidth - drawWidth) / 2);
        final y = margin + ((availableHeight - drawHeight) / 2);

        page.graphics.drawImage(
          image,
          Rect.fromLTWH(x, y, drawWidth, drawHeight),
        );
      } else {
        page.graphics.drawImage(
          image,
          Rect.fromLTWH(margin, margin, drawWidth, drawHeight),
        );
      }
    }

    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return outputBytes;
  }

  /// 6. DELETE SPECIFIC PAGES OF PDF
  /// Removes selected 1-indexed pages and returns updated PDF.
  static Future<Uint8List> deletePdfPages(
    Uint8List pdfBytes,
    List<int> pagesToDelete,
  ) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    
    // Sort descending so deleting earlier pages does not change later indexes
    final sortedUnique = pagesToDelete.toSet().toList()..sort((a, b) => b.compareTo(a));

    for (final pageNum in sortedUnique) {
      final index = pageNum - 1;
      if (index >= 0 && index < document.pages.count && document.pages.count > 1) {
        document.pages.removeAt(index);
      }
    }

    final outputBytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return outputBytes;
  }

  /// 7. ORGANIZE / REORDER PDF PAGES
  /// Reorders pages based on specified list of 1-indexed page numbers.
  static Future<Uint8List> reorderPdfPages(
    Uint8List pdfBytes,
    List<int> newOrder,
  ) async {
    final original = PdfDocument(inputBytes: pdfBytes);
    final reordered = PdfDocument();

    for (final pageNum in newOrder) {
      final index = pageNum - 1;
      if (index >= 0 && index < original.pages.count) {
        final template = original.pages[index].createTemplate();
        final newPage = reordered.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
    }

    final outputBytes = Uint8List.fromList(reordered.saveSync());
    original.dispose();
    reordered.dispose();
    return outputBytes;
  }

  /// Helper to get page count of a PDF
  static int getPageCount(Uint8List pdfBytes) {
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final count = document.pages.count;
      document.dispose();
      return count;
    } catch (_) {
      return 1;
    }
  }

  /// Helper: Constructs a standard OpenXML Microsoft Word .docx ZIP file
  static Uint8List _createDocxFromText(String text) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    // 3. word/document.xml with escaped XML paragraphs
    final lines = text.split('\n');
    final pBuffer = StringBuffer();
    for (final line in lines) {
      final escaped = _escapeXml(line);
      pBuffer.writeln('    <w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>');
    }

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
$pBuffer
    <w:sectPr/>
  </w:body>
</w:document>''';
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));

    // Encode ZIP archive to bytes
    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded);
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

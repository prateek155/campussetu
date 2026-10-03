// lib/features/tools/services/pdf_tools_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart' show Color, Offset, Rect;
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

enum WatermarkStyle {
  centerDiagonal,
  centerHorizontal,
  tiledDiagonal,
}

class PdfToolsService {
  static Future<Uint8List> mergePdfFiles(List<Uint8List> files) async {
    if (files.length < 2) {
      throw ArgumentError('Select at least two PDF files to merge.');
    }
    final output = PdfDocument();
    try {
      for (final bytes in files) {
        final source = PdfDocument(inputBytes: bytes);
        try {
          for (var i = 0; i < source.pages.count; i++) {
            final template = source.pages[i].createTemplate();
            final page = output.pages.add();
            page.graphics.drawPdfTemplate(template, Offset.zero);
          }
        } finally {
          source.dispose();
        }
      }
      return Uint8List.fromList(output.saveSync());
    } finally {
      output.dispose();
    }
  }

  static Future<Uint8List> extractPdfPages(
      Uint8List pdfBytes, List<int> pageNumbers) async {
    final source = PdfDocument(inputBytes: pdfBytes);
    final output = PdfDocument();
    try {
      final pages = pageNumbers.toSet().toList()..sort();
      if (pages.isEmpty || pages.any((p) => p < 1 || p > source.pages.count)) {
        throw ArgumentError('Select at least one valid page.');
      }
      for (final pageNumber in pages) {
        final template = source.pages[pageNumber - 1].createTemplate();
        output.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
      }
      return Uint8List.fromList(output.saveSync());
    } finally {
      source.dispose();
      output.dispose();
    }
  }

  static Future<Uint8List> htmlToPdf(String html, {String title = 'Document'}) async {
    var text = html
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<br\s*/?>|</(p|div|h[1-6]|li|tr|section|article)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (text.isEmpty) throw ArgumentError('The HTML has no readable text.');
    return wordToPdf(text, title: title);
  }

  /// 1. PDF TO WORD (.docx)
  /// Converts PDF pages into a valid OpenXML .docx Microsoft Word document in memory.
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

    var extractedText = buffer.toString().trim();
    if (extractedText.isEmpty) {
      extractedText = 'Document page content';
    }
    final docxBytes = _createDocxFromText(extractedText);

    return PdfExtractionResult(
      text: extractedText,
      docxBytes: docxBytes,
      pageCount: pageCount,
    );
  }

  /// 2. ADD PDF WATERMARK
  /// Adds a semi-transparent text watermark to every page.
  /// Options:
  /// - centerDiagonal: Large single diagonal watermark in center.
  /// - centerHorizontal: Straight horizontal centered watermark.
  /// - tiledDiagonal: Repeated diagonal pattern crossing corner-to-corner with word spacing.
  static Future<Uint8List> addPdfWatermark(
    Uint8List pdfBytes, {
    required String watermark,
    WatermarkStyle style = WatermarkStyle.centerDiagonal,
    double opacity = 0.22,
    int fontSize = 36,
    Color? color,
  }) async {
    final label = watermark.trim();
    if (label.isEmpty) throw ArgumentError('Enter watermark text.');
    final document = PdfDocument(inputBytes: pdfBytes);
    try {
      final wmColor = color != null
          ? PdfColor(
              (color.r * 255.0).round().clamp(0, 255),
              (color.g * 255.0).round().clamp(0, 255),
              (color.b * 255.0).round().clamp(0, 255),
            )
          : PdfColor(128, 128, 128);
      final brush = PdfSolidBrush(wmColor);

      for (var index = 0; index < document.pages.count; index++) {
        final page = document.pages[index];
        final graphics = page.graphics;
        final size = graphics.clientSize;
        final state = graphics.save();
        graphics.setTransparency(opacity);

        if (style == WatermarkStyle.centerDiagonal) {
          final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize.toDouble(), style: PdfFontStyle.bold);
          final textSize = font.measureString(label);
          graphics.translateTransform(size.width / 2, size.height / 2);
          graphics.rotateTransform(-40);
          graphics.drawString(
            label,
            font,
            brush: brush,
            bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width + 20, textSize.height + 10),
            format: PdfStringFormat(alignment: PdfTextAlignment.center),
          );
        } else if (style == WatermarkStyle.centerHorizontal) {
          final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize.toDouble(), style: PdfFontStyle.bold);
          final textSize = font.measureString(label);
          graphics.drawString(
            label,
            font,
            brush: brush,
            bounds: Rect.fromLTWH(0, (size.height - textSize.height) / 2, size.width, textSize.height + 10),
            format: PdfStringFormat(alignment: PdfTextAlignment.center),
          );
        } else if (style == WatermarkStyle.tiledDiagonal) {
          final tileFontSize = (fontSize * 0.48).clamp(14.0, 22.0);
          final font = PdfStandardFont(PdfFontFamily.helvetica, tileFontSize, style: PdfFontStyle.bold);
          final textWithSpace = '   $label   ';
          final textSize = font.measureString(textWithSpace);

          final blockWidth = textSize.width + 50;
          final rowHeight = textSize.height + 55;

          graphics.translateTransform(size.width / 2, size.height / 2);
          graphics.rotateTransform(-35);

          final diag = math.sqrt(size.width * size.width + size.height * size.height);
          final startX = -diag;
          final endX = diag;
          final startY = -diag;
          final endY = diag;

          int row = 0;
          for (double y = startY; y < endY; y += rowHeight) {
            final xOffset = (row % 2 == 0) ? 0.0 : (blockWidth / 2);
            for (double x = startX + xOffset; x < endX; x += blockWidth) {
              graphics.drawString(
                textWithSpace,
                font,
                brush: brush,
                bounds: Rect.fromLTWH(x, y, blockWidth, rowHeight),
                format: PdfStringFormat(alignment: PdfTextAlignment.center),
              );
            }
            row++;
          }
        }
        graphics.restore(state);
      }
      return Uint8List.fromList(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  /// 3. WORD / DOCX FILE TO PDF
  /// Takes a Word document (.docx or .doc) binary and converts it into a formatted multi-page PDF.
  static Future<Uint8List> docxToPdf(Uint8List docxBytes, {String title = 'Document'}) async {
    final pdfDoc = PdfDocument();
    pdfDoc.pageSettings.margins.all = 36;
    pdfDoc.pageSettings.size = PdfPageSize.a4;

    String docTitle = title;
    final paragraphs = <String>[];

    try {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      final docXmlFile = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
        orElse: () => throw Exception('Not a docx archive'),
      );
      final xmlStr = utf8.decode(docXmlFile.content as List<int>, allowMalformed: true);

      // Extract each <w:p>
      final pMatches = RegExp(r'<w:p\b[^>]*>(.*?)</w:p>', dotAll: true).allMatches(xmlStr);
      for (final pm in pMatches) {
        final pContent = pm.group(1) ?? '';
        final tMatches = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>', dotAll: true).allMatches(pContent);
        final fullPText = tMatches.map((m) => _unescapeXml(m.group(1) ?? '')).join('').trim();
        if (fullPText.isNotEmpty) {
          paragraphs.add(fullPText);
        }
      }
    } catch (_) {
      // Fallback: extract clean text strings from binary or text
      final rawStr = _extractReadableStrings(docxBytes);
      final lines = rawStr.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      paragraphs.addAll(lines);
    }

    if (paragraphs.isEmpty) {
      paragraphs.add('Empty Word document content');
    }

    if (docTitle == 'Document' && paragraphs.isNotEmpty && paragraphs.first.length < 60) {
      docTitle = paragraphs.first;
    }

    final page = pdfDoc.pages.add();
    final clientSize = page.getClientSize();

    // Title header
    page.graphics.drawString(
      docTitle,
      PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(0, 0, clientSize.width, 28),
    );
    page.graphics.drawLine(
      PdfPen(PdfColor(203, 213, 225), width: 1.5),
      const Offset(0, 32),
      Offset(clientSize.width, 32),
    );

    final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final textContent = paragraphs.join('\n\n');

    final textElement = PdfTextElement(
      text: textContent,
      font: font,
      format: PdfStringFormat(lineSpacing: 4),
    );

    textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 44, clientSize.width, clientSize.height - 44),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    final outputBytes = Uint8List.fromList(pdfDoc.saveSync());
    pdfDoc.dispose();
    return outputBytes;
  }

  /// Takes editable text contents and converts into a cleanly formatted PDF.
  static Future<Uint8List> wordToPdf(String text, {String title = 'Document'}) async {
    final document = PdfDocument();
    
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

  /// 8. PPT / PPTX TO PDF
  /// Parses PowerPoint presentation slides (.pptx or .ppt) and builds landscape presentation PDF slides.
  static Future<Uint8List> pptxToPdf(Uint8List pptxBytes) async {
    final pdfDoc = PdfDocument();
    pdfDoc.pageSettings.orientation = PdfPageOrientation.landscape;
    pdfDoc.pageSettings.size = PdfPageSize.a4;

    try {
      final archive = ZipDecoder().decodeBytes(pptxBytes);
      final slideFiles = archive.files
          .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml') && !f.name.contains('_rels'))
          .toList();

      slideFiles.sort((a, b) {
        final numA = int.tryParse(RegExp(r'slide(\d+)\.xml').firstMatch(a.name)?.group(1) ?? '0') ?? 0;
        final numB = int.tryParse(RegExp(r'slide(\d+)\.xml').firstMatch(b.name)?.group(1) ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

      if (slideFiles.isEmpty) {
        _buildSlideFromRawText(pdfDoc, pptxBytes);
      } else {
        final totalSlides = slideFiles.length;
        for (int i = 0; i < totalSlides; i++) {
          final file = slideFiles[i];
          final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
          
          final pMatches = RegExp(r'<a:p\b[^>]*>(.*?)</a:p>', dotAll: true).allMatches(xmlStr);
          final paragraphs = <String>[];
          for (final pm in pMatches) {
            final pXml = pm.group(1) ?? '';
            final tMatches = RegExp(r'<a:t\b[^>]*>(.*?)</a:t>', dotAll: true).allMatches(pXml);
            final pText = tMatches.map((m) => _unescapeXml(m.group(1) ?? '')).join('').trim();
            if (pText.isNotEmpty) {
              paragraphs.add(pText);
            }
          }

          final slideTitle = paragraphs.isNotEmpty ? paragraphs.first : 'Slide ${i + 1}';
          final bulletPoints = paragraphs.length > 1 ? paragraphs.sublist(1) : <String>[];

          _renderPdfSlide(pdfDoc, slideIndex: i + 1, totalSlides: totalSlides, title: slideTitle, bullets: bulletPoints);
        }
      }
    } catch (_) {
      _buildSlideFromRawText(pdfDoc, pptxBytes);
    }

    final output = Uint8List.fromList(pdfDoc.saveSync());
    pdfDoc.dispose();
    return output;
  }

  static void _renderPdfSlide(
    PdfDocument doc, {
    required int slideIndex,
    required int totalSlides,
    required String title,
    required List<String> bullets,
  }) {
    final page = doc.pages.add();
    final pageSize = page.getClientSize();

    // Top Header Banner
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(0, 0, pageSize.width, 58),
    );

    // Accent line below banner
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(56, 189, 248)),
      bounds: Rect.fromLTWH(0, 56, pageSize.width, 2.5),
    );

    // Slide Title
    page.graphics.drawString(
      title,
      PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(24, 16, pageSize.width - 48, 28),
      format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle),
    );

    // Bullets / Content
    double y = 80;
    final bulletFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final bulletBrush = PdfSolidBrush(PdfColor(30, 41, 59));

    if (bullets.isEmpty) {
      page.graphics.drawString(
        'Presentation slide content',
        bulletFont,
        brush: PdfSolidBrush(PdfColor(100, 116, 139)),
        bounds: Rect.fromLTWH(36, y, pageSize.width - 72, 26),
      );
    } else {
      for (final bullet in bullets) {
        if (y > pageSize.height - 45) break;
        final formattedText = '•  $bullet';
        page.graphics.drawString(
          formattedText,
          bulletFont,
          brush: bulletBrush,
          bounds: Rect.fromLTWH(36, y, pageSize.width - 72, 36),
          format: PdfStringFormat(wordWrap: PdfWordWrapType.word),
        );
        y += 24;
      }
    }

    // Bottom Footer with slide number
    page.graphics.drawLine(
      PdfPen(PdfColor(226, 232, 240), width: 1),
      Offset(24, pageSize.height - 28),
      Offset(pageSize.width - 24, pageSize.height - 28),
    );
    page.graphics.drawString(
      'Slide $slideIndex of $totalSlides',
      PdfStandardFont(PdfFontFamily.helvetica, 9),
      brush: PdfSolidBrush(PdfColor(148, 163, 184)),
      bounds: Rect.fromLTWH(24, pageSize.height - 22, pageSize.width - 48, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
  }

  static void _buildSlideFromRawText(PdfDocument doc, Uint8List rawBytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < rawBytes.length; i++) {
      final b = rawBytes[i];
      if ((b >= 32 && b <= 126) || b == 10 || b == 13) {
        buffer.writeCharCode(b);
      } else if (buffer.isNotEmpty && buffer.toString().endsWith(' ') == false) {
        buffer.write(' ');
      }
    }
    final text = buffer.toString();
    final chunks = text.split(RegExp(r'\s{4,}|\n{2,}')).where((s) => s.trim().length > 3).toList();
    if (chunks.isEmpty) {
      _renderPdfSlide(doc, slideIndex: 1, totalSlides: 1, title: 'PowerPoint Presentation', bullets: ['Imported presentation document']);
      return;
    }

    final slidesCount = (chunks.length / 5).ceil().clamp(1, 30);
    for (int s = 0; s < slidesCount; s++) {
      final start = s * 5;
      final end = (start + 5).clamp(0, chunks.length);
      final slideChunks = chunks.sublist(start, end);
      final title = slideChunks.isNotEmpty ? slideChunks.first : 'Slide ${s + 1}';
      final bullets = slideChunks.length > 1 ? slideChunks.sublist(1) : <String>[];
      _renderPdfSlide(doc, slideIndex: s + 1, totalSlides: slidesCount, title: title, bullets: bullets);
    }
  }

  /// 9. CSV TO EXCEL (.xlsx)
  static Uint8List csvToExcelXlsx(String csvText) {
    final rows = parseCsv(csvText);
    final archive = Archive();

    const ctXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', ctXml.length, utf8.encode(ctXml)));

    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRels.length, utf8.encode(rootRels)));

    const wbRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', wbRels.length, utf8.encode(wbRels)));

    const wbXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
    archive.addFile(ArchiveFile('xl/workbook.xml', wbXml.length, utf8.encode(wbXml)));

    final sheetBuffer = StringBuffer();
    sheetBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sheetBuffer.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sheetBuffer.writeln('  <sheetData>');

    for (int r = 0; r < rows.length; r++) {
      final rowNum = r + 1;
      final row = rows[r];
      sheetBuffer.writeln('    <row r="$rowNum">');
      for (int c = 0; c < row.length; c++) {
        final colLetter = _getExcelColumnName(c);
        final cellRef = '$colLetter$rowNum';
        final val = _escapeXml(row[c]);
        sheetBuffer.writeln('      <c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">$val</t></is></c>');
      }
      sheetBuffer.writeln('    </row>');
    }

    sheetBuffer.writeln('  </sheetData>');
    sheetBuffer.writeln('</worksheet>');
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetBuffer.length, utf8.encode(sheetBuffer.toString())));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// 10. CSV TO PDF TABLE
  static Uint8List csvToPdf(String csvText, {String title = 'Data Table'}) {
    final rows = parseCsv(csvText);
    final doc = PdfDocument();
    doc.pageSettings.margins.all = 24;

    final colsCount = rows.isNotEmpty ? rows.first.length : 1;
    if (colsCount > 5) {
      doc.pageSettings.orientation = PdfPageOrientation.landscape;
    }

    final page = doc.pages.add();
    final clientSize = page.getClientSize();

    page.graphics.drawString(
      title,
      PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(0, 0, clientSize.width, 26),
    );

    if (rows.isNotEmpty) {
      final grid = PdfGrid();
      grid.columns.add(count: colsCount);

      final header = grid.headers.add(1)[0];
      final headerRow = rows.first;
      for (int c = 0; c < colsCount; c++) {
        header.cells[c].value = c < headerRow.length ? headerRow[c] : '';
        header.cells[c].style.backgroundBrush = PdfSolidBrush(PdfColor(15, 23, 42));
        header.cells[c].style.textBrush = PdfSolidBrush(PdfColor(255, 255, 255));
        header.cells[c].style.font = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
      }

      for (int r = 1; r < rows.length; r++) {
        final dataRow = rows[r];
        final row = grid.rows.add();
        final isEven = r % 2 == 0;
        final bgBrush = isEven ? PdfSolidBrush(PdfColor(248, 250, 252)) : PdfSolidBrush(PdfColor(255, 255, 255));

        for (int c = 0; c < colsCount; c++) {
          row.cells[c].value = c < dataRow.length ? dataRow[c] : '';
          row.cells[c].style.backgroundBrush = bgBrush;
          row.cells[c].style.font = PdfStandardFont(PdfFontFamily.helvetica, 9);
        }
      }

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
        borderOverlapStyle: PdfBorderOverlapStyle.inside,
      );

      grid.draw(page: page, bounds: Rect.fromLTWH(0, 36, clientSize.width, clientSize.height - 40));
    }

    final output = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return output;
  }

  /// 11. TXT TO WORD (.docx)
  static Uint8List txtToDocx(String text) {
    return _createDocxFromText(text);
  }

  /// 12. TXT TO PDF
  static Uint8List txtToPdf(String text, {String title = 'Document'}) {
    final doc = PdfDocument();
    doc.pageSettings.margins.all = 36;
    final page = doc.pages.add();
    final clientSize = page.getClientSize();

    page.graphics.drawString(
      title,
      PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(0, 0, clientSize.width, 24),
    );
    page.graphics.drawLine(
      PdfPen(PdfColor(226, 232, 240), width: 1),
      const Offset(0, 28),
      Offset(clientSize.width, 28),
    );

    final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final textElement = PdfTextElement(text: text, font: font);
    textElement.brush = PdfSolidBrush(PdfColor(30, 41, 59));
    textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 38, clientSize.width, clientSize.height - 48),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    final output = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return output;
  }

  /// 13. PDF TO POWERPOINT (.pptx)
  /// Converts PDF pages into a standard, fully compliant Microsoft PowerPoint presentation (.pptx).
  static Future<Uint8List> pdfToPptx(Uint8List pdfBytes, {String title = 'Presentation'}) async {
    final pdfDoc = PdfDocument(inputBytes: pdfBytes);
    final totalPages = pdfDoc.pages.count;
    final extractor = PdfTextExtractor(pdfDoc);

    final archive = Archive();

    // 1. [Content_Types].xml
    final ctBuffer = StringBuffer();
    ctBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    ctBuffer.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    ctBuffer.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    ctBuffer.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    ctBuffer.writeln('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
    ctBuffer.writeln('  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>');
    ctBuffer.writeln('  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>');
    for (int i = 1; i <= totalPages; i++) {
      ctBuffer.writeln('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    ctBuffer.writeln('</Types>');
    archive.addFile(ArchiveFile('[Content_Types].xml', ctBuffer.length, utf8.encode(ctBuffer.toString())));

    // 2. _rels/.rels
    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRels.length, utf8.encode(rootRels)));

    // 3. ppt/_rels/presentation.xml.rels
    final presRelsBuffer = StringBuffer();
    presRelsBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presRelsBuffer.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    presRelsBuffer.writeln('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>');
    for (int i = 1; i <= totalPages; i++) {
      presRelsBuffer.writeln('  <Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
    }
    presRelsBuffer.writeln('</Relationships>');
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsBuffer.length, utf8.encode(presRelsBuffer.toString())));

    // 4. ppt/presentation.xml
    final presBuffer = StringBuffer();
    presBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presBuffer.writeln('<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">');
    presBuffer.writeln('  <p:sldMasterIdLst>');
    presBuffer.writeln('    <p:sldMasterId id="2147483648" r:id="rId1"/>');
    presBuffer.writeln('  </p:sldMasterIdLst>');
    presBuffer.writeln('  <p:sldIdLst>');
    for (int i = 1; i <= totalPages; i++) {
      presBuffer.writeln('    <p:sldId id="${255 + i}" r:id="rId${i + 1}"/>');
    }
    presBuffer.writeln('  </p:sldIdLst>');
    presBuffer.writeln('  <p:sldSz cx="9144000" cy="5143500" type="screen16x9"/>');
    presBuffer.writeln('  <p:notesSz cx="6858000" cy="9144000"/>');
    presBuffer.writeln('</p:presentation>');
    archive.addFile(ArchiveFile('ppt/presentation.xml', presBuffer.length, utf8.encode(presBuffer.toString())));

    // 5. ppt/slideMasters/slideMaster1.xml & rels
    const masterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:grpSpPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
    </p:spTree>
  </p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst>
    <p:sldLayoutId id="2147483649" r:id="rId1"/>
  </p:sldLayoutIdLst>
  <p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>
</p:sldMaster>''';
    archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', masterXml.length, utf8.encode(masterXml)));

    const masterRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', masterRels.length, utf8.encode(masterRels)));

    // 6. ppt/slideLayouts/slideLayout1.xml & rels
    const layoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank">
  <p:cSld name="Blank">
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:grpSpPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>''';
    archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', layoutXml.length, utf8.encode(layoutXml)));

    const layoutRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', layoutRels.length, utf8.encode(layoutRels)));

    // 7. For each slide: slide$i.xml & slide$i.xml.rels
    const slideCommonRel = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';

    for (int i = 0; i < totalPages; i++) {
      final pageNum = i + 1;
      archive.addFile(ArchiveFile('ppt/slides/_rels/slide$pageNum.xml.rels', slideCommonRel.length, utf8.encode(slideCommonRel)));

      final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
      final rawLines = pageText.split(RegExp(r'\r?\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final slideTitle = rawLines.isNotEmpty ? _escapeXml(rawLines.first) : 'Page $pageNum';
      final bodyLines = rawLines.length > 1
          ? rawLines.sublist(1)
          : <String>['Presentation slide content from page $pageNum'];

      final pBuffer = StringBuffer();
      for (final b in bodyLines.take(14)) {
        pBuffer.writeln('            <a:p><a:pPr lvl="0"/><a:r><a:rPr lang="en-US" sz="1500"/><a:t>${_escapeXml(b)}</a:t></a:r></a:p>');
      }

      final slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:grpSpPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Slide Header"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="457200" y="365760"/><a:ext cx="8229600" cy="822960"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" b="1" sz="2200"/><a:t>$slideTitle</a:t></a:r></a:p></p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content Body"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="457200" y="1371600"/><a:ext cx="8229600" cy="3429000"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/>
$pBuffer
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
      archive.addFile(ArchiveFile('ppt/slides/slide$pageNum.xml', slideXml.length, utf8.encode(slideXml)));
    }

    pdfDoc.dispose();
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Parses CSV text handling quotes, commas, tabs, and semicolons
  static List<List<String>> parseCsv(String input) {
    final rows = <List<String>>[];
    final lines = input.split(RegExp(r'\r?\n'));
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      final row = <String>[];
      final buffer = StringBuffer();
      bool insideQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final ch = line[i];
        if (ch == '"') {
          if (insideQuotes && i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            insideQuotes = !insideQuotes;
          }
        } else if ((ch == ',' || ch == ';' || ch == '\t') && !insideQuotes) {
          row.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(ch);
        }
      }
      row.add(buffer.toString().trim());
      if (row.any((cell) => cell.isNotEmpty)) {
        rows.add(row);
      }
    }
    return rows;
  }

  static String _getExcelColumnName(int colIndex) {
    String name = '';
    int col = colIndex;
    while (col >= 0) {
      name = String.fromCharCode((col % 26) + 65) + name;
      col = (col ~/ 26) - 1;
    }
    return name;
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
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRels.length, utf8.encode(rootRels)));

    // 3. word/_rels/document.xml.rels
    const docRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRels.length, utf8.encode(docRels)));

    // 4. word/styles.xml
    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
        <w:sz w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
  </w:style>
</w:styles>''';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 5. word/document.xml
    final lines = text.split(RegExp(r'\r?\n'));
    final pBuffer = StringBuffer();
    for (final line in lines) {
      if (line.startsWith('--- [Page ') && line.endsWith('] ---')) {
        pBuffer.writeln('    <w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      } else {
        final escaped = _escapeXml(line);
        pBuffer.writeln('    <w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>');
      }
    }

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
$pBuffer
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''';
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded);
  }

  static String _extractReadableStrings(Uint8List rawBytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < rawBytes.length; i++) {
      final b = rawBytes[i];
      if ((b >= 32 && b <= 126) || b == 10 || b == 13) {
        buffer.writeCharCode(b);
      } else if (buffer.isNotEmpty && !buffer.toString().endsWith(' ')) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}

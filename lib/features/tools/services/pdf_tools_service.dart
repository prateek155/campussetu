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

  /// 8. PPT / PPTX TO PDF
  /// Parses PowerPoint presentation slides (.pptx or .ppt) and builds landscape presentation PDF slides.
  static Future<Uint8List> pptxToPdf(Uint8List pptxBytes) async {
    final pdfDoc = PdfDocument();
    pdfDoc.pageSettings.orientation = PdfPageOrientation.landscape;
    pdfDoc.pageSettings.size = PdfPageSize.a4;

    try {
      final archive = ZipDecoder().decodeBytes(pptxBytes);
      final slideFiles = archive.files
          .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
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
          final matches = RegExp(r'<a:t[^>]*>(.*?)</a:t>', dotAll: true).allMatches(xmlStr);
          final textElements = matches.map((m) => m.group(1) ?? '').where((s) => s.trim().isNotEmpty).toList();

          final slideTitle = textElements.isNotEmpty ? textElements.first : 'Slide ${i + 1}';
          final bulletPoints = textElements.length > 1 ? textElements.sublist(1) : <String>[];

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
  /// Converts CSV data to an OpenXML .xlsx spreadsheet in memory.
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
  /// Renders a CSV into a formatted tabular PDF with headers and alternating row colors.
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
  static Future<Uint8List> pdfToPptx(Uint8List pdfBytes, {String title = 'Presentation'}) async {
    final pdfDoc = PdfDocument(inputBytes: pdfBytes);
    final totalPages = pdfDoc.pages.count;
    final extractor = PdfTextExtractor(pdfDoc);

    final archive = Archive();

    final ctBuffer = StringBuffer();
    ctBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    ctBuffer.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    ctBuffer.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    ctBuffer.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    ctBuffer.writeln('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
    for (int i = 1; i <= totalPages; i++) {
      ctBuffer.writeln('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    ctBuffer.writeln('</Types>');
    archive.addFile(ArchiveFile('[Content_Types].xml', ctBuffer.length, utf8.encode(ctBuffer.toString())));

    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRels.length, utf8.encode(rootRels)));

    final presRelsBuffer = StringBuffer();
    presRelsBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presRelsBuffer.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (int i = 1; i <= totalPages; i++) {
      presRelsBuffer.writeln('  <Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
    }
    presRelsBuffer.writeln('</Relationships>');
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsBuffer.length, utf8.encode(presRelsBuffer.toString())));

    final presBuffer = StringBuffer();
    presBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presBuffer.writeln('<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">');
    presBuffer.writeln('  <p:sldIdLst>');
    for (int i = 1; i <= totalPages; i++) {
      presBuffer.writeln('    <p:sldId id="${255 + i}" r:id="rId$i"/>');
    }
    presBuffer.writeln('  </p:sldIdLst>');
    presBuffer.writeln('  <p:sldSz cx="9144000" cy="5143500"/>');
    presBuffer.writeln('</p:presentation>');
    archive.addFile(ArchiveFile('ppt/presentation.xml', presBuffer.length, utf8.encode(presBuffer.toString())));

    for (int i = 0; i < totalPages; i++) {
      final pageNum = i + 1;
      final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
      final rawLines = pageText.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final slideTitle = rawLines.isNotEmpty ? _escapeXml(rawLines.first) : 'Page $pageNum';
      final bodyLines = rawLines.length > 1 ? rawLines.sublist(1) : <String>['(Document content)'];

      final pBuffer = StringBuffer();
      for (final b in bodyLines.take(12)) {
        pBuffer.writeln('            <a:p><a:r><a:rPr lang="en-US" sz="1600"/><a:t>${_escapeXml(b)}</a:t></a:r></a:p>');
      }

      final slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:grpSpPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="457200" y="274320"/><a:ext cx="8229600" cy="914400"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" b="1" sz="2400"/><a:t>$slideTitle</a:t></a:r></a:p></p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
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

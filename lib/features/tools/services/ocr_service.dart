// lib/features/tools/services/ocr_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart' show Rect;
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'pdf_tools_service.dart';

export 'ocr_service_mobile.dart' if (dart.library.html) 'ocr_service_web.dart';

enum OcrLineAlignment {
  left,
  center,
  right,
}

class OcrLine {
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;
  final OcrLineAlignment alignment;
  final bool isHeading;
  final double fontSize;
  final int indentTwips;

  const OcrLine({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.alignment,
    this.isHeading = false,
    this.fontSize = 11.0,
    this.indentTwips = 0,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'alignment': alignment.name,
    'isHeading': isHeading,
    'fontSize': fontSize,
    'indentTwips': indentTwips,
  };
}

class OcrDocumentResult {
  final String fullText;
  final double imageWidth;
  final double imageHeight;
  final List<OcrLine> lines;

  const OcrDocumentResult({
    required this.fullText,
    required this.imageWidth,
    required this.imageHeight,
    required this.lines,
  });

  factory OcrDocumentResult.fromText(String text) {
    final rawLines = text.split(RegExp(r'\r?\n'));
    final list = <OcrLine>[];
    for (int i = 0; i < rawLines.length; i++) {
      final t = rawLines[i].trim();
      if (t.isNotEmpty) {
        list.add(OcrLine(
          text: t,
          x: 0,
          y: i * 20.0,
          width: 200,
          height: 18,
          alignment: OcrLineAlignment.left,
        ));
      }
    }
    return OcrDocumentResult(
      fullText: text,
      imageWidth: 800,
      imageHeight: 1100,
      lines: list,
    );
  }
}

class OcrService {
  /// Detects whether a line should be aligned center, right, or left
  static OcrLineAlignment detectAlignment({
    required double x,
    required double width,
    required double imageWidth,
  }) {
    if (imageWidth <= 0 || width <= 0) return OcrLineAlignment.left;

    final lineCenter = x + (width / 2.0);
    final imgCenter = imageWidth / 2.0;
    final centerDiff = (lineCenter - imgCenter).abs();

    // If line center is within 13% of the image center and not spanning entire page
    if (centerDiff <= (imageWidth * 0.13) && width <= (imageWidth * 0.82)) {
      return OcrLineAlignment.center;
    }

    // If line ends near right edge and starts past 38% of image width
    final rightEdge = x + width;
    if (rightEdge >= (imageWidth * 0.78) && x >= (imageWidth * 0.35)) {
      return OcrLineAlignment.right;
    }

    return OcrLineAlignment.left;
  }

  /// Exports OCR text to Microsoft Word (.docx) preserving exact alignment (Center, Right, Left, Indentation)
  static Uint8List exportToDocx(
    String text, {
    OcrDocumentResult? ocrResult,
    bool preserveLayout = true,
  }) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const ctXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', ctXml.length, utf8.encode(ctXml)));

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
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="24"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
  </w:style>
</w:styles>''';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, utf8.encode(stylesXml)));

    // 5. word/document.xml
    final pBuffer = StringBuffer();
    final linesToExport = _buildLinesFromText(text, ocrResult: preserveLayout ? ocrResult : null);

    double lastY = -1;
    for (final line in linesToExport) {
      final escaped = _escapeXml(line.text);
      if (escaped.trim().isEmpty) {
        pBuffer.writeln('    <w:p/>');
        continue;
      }

      int spaceBefore = 60; // 3 pt in twips
      if (lastY >= 0 && (line.y - lastY) > (line.height * 1.6)) {
        spaceBefore = 240; // 12 pt extra paragraph gap
      }
      lastY = line.y + line.height;

      final alignVal = switch (line.alignment) {
        OcrLineAlignment.center => 'center',
        OcrLineAlignment.right => 'right',
        OcrLineAlignment.left => 'left',
      };

      pBuffer.writeln('    <w:p>');
      pBuffer.writeln('      <w:pPr>');
      pBuffer.writeln('        <w:jc w:val="$alignVal"/>');
      if (line.alignment == OcrLineAlignment.left && line.indentTwips > 0) {
        pBuffer.writeln('        <w:ind w:left="${line.indentTwips}"/>');
      }
      pBuffer.writeln('        <w:spacing w:before="$spaceBefore" w:after="60" w:line="276" w:lineRule="auto"/>');
      pBuffer.writeln('      </w:pPr>');
      pBuffer.writeln('      <w:r>');
      if (line.isHeading || line.fontSize >= 13.5) {
        final halfPts = (line.fontSize * 2).round();
        pBuffer.writeln('        <w:rPr>');
        pBuffer.writeln('          <w:b/>');
        pBuffer.writeln('          <w:sz w:val="$halfPts"/>');
        pBuffer.writeln('        </w:rPr>');
      }
      pBuffer.writeln('        <w:t xml:space="preserve">$escaped</w:t>');
      pBuffer.writeln('      </w:r>');
      pBuffer.writeln('    </w:p>');
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

  /// Exports OCR text to PDF preserving exact visual layout and alignment
  static Uint8List exportToPdf(
    String text, {
    OcrDocumentResult? ocrResult,
    bool preserveLayout = true,
    String title = 'Extracted Document',
  }) {
    if (!preserveLayout || ocrResult == null) {
      return PdfToolsService.txtToPdf(text, title: title);
    }

    final doc = PdfDocument();
    doc.pageSettings.margins.all = 36; // 0.5 inch margins

    final linesToExport = _buildLinesFromText(text, ocrResult: ocrResult);

    PdfPage page = doc.pages.add();
    final pageSize = page.getClientSize();
    final pageWidth = pageSize.width;
    final pageHeight = pageSize.height;

    final regularFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final boldFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final brush = PdfSolidBrush(PdfColor(20, 24, 33));

    double currentY = 10;
    double lastOrigY = -1;

    for (final line in linesToExport) {
      if (line.text.trim().isEmpty) {
        currentY += 14;
        continue;
      }

      if (lastOrigY >= 0 && (line.y - lastOrigY) > (line.height * 1.6)) {
        currentY += 10;
      }
      lastOrigY = line.y + line.height;

      final font = line.fontSize >= 16.0
          ? titleFont
          : line.fontSize >= 13.0
              ? subtitleFont
              : line.isHeading
                  ? boldFont
                  : regularFont;

      final lineSize = font.measureString(line.text);

      if (currentY + lineSize.height > pageHeight - 20) {
        page = doc.pages.add();
        currentY = 10;
      }

      double x = 0;
      switch (line.alignment) {
        case OcrLineAlignment.center:
          x = ((pageWidth - lineSize.width) / 2).clamp(0.0, pageWidth - 10);
          break;
        case OcrLineAlignment.right:
          x = (pageWidth - lineSize.width).clamp(0.0, pageWidth - 10);
          break;
        case OcrLineAlignment.left:
          final indent = (line.indentTwips / 20.0).clamp(0.0, pageWidth * 0.4);
          x = indent;
          break;
      }

      page.graphics.drawString(
        line.text,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(x, currentY, lineSize.width + 10, lineSize.height + 4),
      );

      currentY += lineSize.height + 4;
    }

    final output = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return output;
  }

  static List<OcrLine> _buildLinesFromText(String text, {OcrDocumentResult? ocrResult}) {
    final rawLines = text.split(RegExp(r'\r?\n'));
    if (ocrResult != null && ocrResult.lines.isNotEmpty) {
      // If line counts match, preserve original line positioning and layout!
      if (rawLines.length == ocrResult.lines.length) {
        final mapped = <OcrLine>[];
        for (int i = 0; i < rawLines.length; i++) {
          final orig = ocrResult.lines[i];
          mapped.add(OcrLine(
            text: rawLines[i],
            x: orig.x,
            y: orig.y,
            width: orig.width,
            height: orig.height,
            alignment: orig.alignment,
            isHeading: orig.isHeading,
            fontSize: orig.fontSize,
            indentTwips: orig.indentTwips,
          ));
        }
        return mapped;
      }
      return ocrResult.lines;
    }

    final list = <OcrLine>[];
    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        list.add(OcrLine(
          text: '',
          x: 0,
          y: i * 20.0,
          width: 0,
          height: 16,
          alignment: OcrLineAlignment.left,
        ));
        continue;
      }

      int leadingSpaces = line.length - line.trimLeft().length;
      int indentTwips = leadingSpaces > 2 ? (leadingSpaces * 140).clamp(0, 4000) : 0;
      OcrLineAlignment alignment = OcrLineAlignment.left;
      if (leadingSpaces >= 15) {
        alignment = OcrLineAlignment.center;
        indentTwips = 0;
      }

      list.add(OcrLine(
        text: trimmed,
        x: indentTwips.toDouble(),
        y: i * 20.0,
        width: trimmed.length * 8.0,
        height: 16,
        alignment: alignment,
        indentTwips: indentTwips,
      ));
    }
    return list;
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

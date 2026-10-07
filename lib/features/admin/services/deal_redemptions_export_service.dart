import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../tools/utils/file_saver.dart';

enum DealExportFormat { excel, pdf }

class DealRedemptionsExportService {
  static String _sanitizeFileName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateVal.toString();
    }
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _getExcelColumnName(int colIndex) {
    int dividend = colIndex + 1;
    String colName = '';
    while (dividend > 0) {
      final modulo = (dividend - 1) % 26;
      colName = String.fromCharCode(65 + modulo) + colName;
      dividend = (dividend - modulo) ~/ 26;
    }
    return colName;
  }

  /// Generates a valid OpenXML .xlsx document from deal redemptions.
  static Uint8List generateExcel({
    required String dealTitle,
    required String discountCode,
    required List<Map<String, dynamic>> redemptions,
  }) {
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
    <sheet name="Redemptions" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
    archive.addFile(ArchiveFile('xl/workbook.xml', wbXml.length, utf8.encode(wbXml)));

    final headers = [
      'S.No',
      'Student Name',
      'Campus ID',
      'Redeemed Code',
      'Email',
      'College',
      'Branch',
      'Redeemed At',
    ];

    final sheetBuffer = StringBuffer();
    sheetBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sheetBuffer.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sheetBuffer.writeln('  <sheetData>');

    // Row 1: Deal Title
    sheetBuffer.writeln('    <row r="1">');
    final codePart = discountCode.isNotEmpty ? ' (Code: $discountCode)' : '';
    sheetBuffer.writeln('      <c r="A1" t="inlineStr"><is><t xml:space="preserve">${_escapeXml('CampusSetu — Deal Redemptions: $dealTitle$codePart')}</t></is></c>');
    sheetBuffer.writeln('    </row>');

    // Row 2: Metadata (Export time, Total redemptions)
    sheetBuffer.writeln('    <row r="2">');
    final metaText = 'Exported: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())} | Total Students Redeemed: ${redemptions.length}';
    sheetBuffer.writeln('      <c r="A2" t="inlineStr"><is><t xml:space="preserve">${_escapeXml(metaText)}</t></is></c>');
    sheetBuffer.writeln('    </row>');

    // Row 3: Blank spacing row
    sheetBuffer.writeln('    <row r="3"></row>');

    // Row 4: Column Headers
    sheetBuffer.writeln('    <row r="4">');
    for (int c = 0; c < headers.length; c++) {
      final cellRef = '${_getExcelColumnName(c)}4';
      sheetBuffer.writeln('      <c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">${_escapeXml(headers[c])}</t></is></c>');
    }
    sheetBuffer.writeln('    </row>');

    // Data rows start at row 5
    for (int r = 0; r < redemptions.length; r++) {
      final rowNum = r + 5;
      final item = redemptions[r];
      final rowValues = [
        '${r + 1}',
        (item['name'] ?? '').toString(),
        (item['campus_id'] ?? '').toString(),
        (item['deal_code'] ?? '').toString(),
        (item['email'] ?? '').toString(),
        (item['college'] ?? '').toString(),
        (item['branch'] ?? '').toString(),
        _formatDate(item['redeemed_at']),
      ];

      sheetBuffer.writeln('    <row r="$rowNum">');
      for (int c = 0; c < rowValues.length; c++) {
        final cellRef = '${_getExcelColumnName(c)}$rowNum';
        final val = _escapeXml(rowValues[c]);
        sheetBuffer.writeln('      <c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">$val</t></is></c>');
      }
      sheetBuffer.writeln('    </row>');
    }

    sheetBuffer.writeln('  </sheetData>');
    sheetBuffer.writeln('</worksheet>');

    archive.addFile(
      ArchiveFile('xl/worksheets/sheet1.xml', sheetBuffer.length, utf8.encode(sheetBuffer.toString())),
    );

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Generates a styled, multi-page landscape PDF document using syncfusion_flutter_pdf.
  static Uint8List generatePdf({
    required String dealTitle,
    required String discountCode,
    required List<Map<String, dynamic>> redemptions,
  }) {
    final doc = PdfDocument();
    doc.pageSettings.orientation = PdfPageOrientation.landscape;
    doc.pageSettings.margins.all = 20;

    final page = doc.pages.add();
    final clientSize = page.getClientSize();

    // Document Header
    page.graphics.drawString(
      'CAMPUSSETU — DEAL REDEMPTIONS REPORT',
      PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(0, 0, clientSize.width, 18),
    );

    final codePart = discountCode.isNotEmpty ? '  ·  Promo Code: $discountCode' : '';
    page.graphics.drawString(
      'Deal: $dealTitle$codePart',
      PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(245, 158, 11)), // Orange accent for deals
      bounds: Rect.fromLTWH(0, 20, clientSize.width, 16),
    );

    final exportInfo = 'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}   |   Total Students Redeemed: ${redemptions.length}';
    page.graphics.drawString(
      exportInfo,
      PdfStandardFont(PdfFontFamily.helvetica, 9),
      brush: PdfSolidBrush(PdfColor(100, 116, 139)),
      bounds: Rect.fromLTWH(0, 36, clientSize.width, 14),
    );

    final headers = [
      '#',
      'Student Name',
      'Campus ID',
      'Redeemed Code',
      'Email',
      'College',
      'Branch',
      'Redeemed At',
    ];

    final grid = PdfGrid();
    grid.columns.add(count: headers.length);

    // Column widths in points
    grid.columns[0].width = 24;  // #
    grid.columns[1].width = 95;  // Name
    grid.columns[2].width = 75;  // Campus ID
    grid.columns[3].width = 80;  // Deal Code
    grid.columns[4].width = 120; // Email
    grid.columns[5].width = 110; // College
    grid.columns[6].width = 75;  // Branch
    grid.columns[7].width = 100; // Redeemed At

    final headerRow = grid.headers.add(1)[0];
    for (int c = 0; c < headers.length; c++) {
      headerRow.cells[c].value = headers[c];
      headerRow.cells[c].style.backgroundBrush = PdfSolidBrush(PdfColor(20, 23, 40));
      headerRow.cells[c].style.textBrush = PdfSolidBrush(PdfColor(255, 255, 255));
      headerRow.cells[c].style.font = PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold);
      headerRow.cells[c].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle);
    }

    for (int r = 0; r < redemptions.length; r++) {
      final item = redemptions[r];
      final row = grid.rows.add();
      final isEven = r % 2 == 0;
      final bgBrush = isEven ? PdfSolidBrush(PdfColor(248, 250, 252)) : PdfSolidBrush(PdfColor(255, 255, 255));

      final rowValues = [
        '${r + 1}',
        (item['name'] ?? '').toString(),
        (item['campus_id'] ?? '').toString().isNotEmpty ? item['campus_id'].toString() : '-',
        (item['deal_code'] ?? '').toString().isNotEmpty ? item['deal_code'].toString() : '-',
        (item['email'] ?? '').toString(),
        (item['college'] ?? '').toString().isNotEmpty ? item['college'].toString() : '-',
        (item['branch'] ?? '').toString().isNotEmpty ? item['branch'].toString() : '-',
        _formatDate(item['redeemed_at']),
      ];

      for (int c = 0; c < headers.length; c++) {
        row.cells[c].value = rowValues[c];
        row.cells[c].style.backgroundBrush = bgBrush;
        row.cells[c].style.font = PdfStandardFont(PdfFontFamily.helvetica, 7.5);
        row.cells[c].stringFormat = PdfStringFormat(
          alignment: (c == 0 || c == 2 || c == 3) ? PdfTextAlignment.center : PdfTextAlignment.left,
          lineAlignment: PdfVerticalAlignment.middle,
        );
      }
    }

    grid.style = PdfGridStyle(
      cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4),
      borderOverlapStyle: PdfBorderOverlapStyle.inside,
    );

    final format = PdfLayoutFormat(layoutType: PdfLayoutType.paginate);
    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 56, clientSize.width, clientSize.height - 60),
      format: format,
    );

    final output = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return output;
  }

  /// Exports and triggers download on device or browser.
  static Future<String> exportAndDownload({
    required String dealTitle,
    required String discountCode,
    required List<Map<String, dynamic>> redemptions,
    required DealExportFormat format,
  }) async {
    final cleanName = _sanitizeFileName(dealTitle.isEmpty ? 'Deal' : dealTitle);
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    if (format == DealExportFormat.excel) {
      final fileName = '${cleanName}_redemptions_$timestamp.xlsx';
      final bytes = generateExcel(
        dealTitle: dealTitle,
        discountCode: discountCode,
        redemptions: redemptions,
      );
      await saveAndDownloadFile(bytes, fileName);
      return fileName;
    } else {
      final fileName = '${cleanName}_redemptions_$timestamp.pdf';
      final bytes = generatePdf(
        dealTitle: dealTitle,
        discountCode: discountCode,
        redemptions: redemptions,
      );
      await saveAndDownloadFile(bytes, fileName);
      return fileName;
    }
  }
}

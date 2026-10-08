import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'services/pdf_tools_service.dart';
import 'services/image_tools_service.dart';
import 'services/ocr_service.dart';
import 'tools_category_screen.dart';
import 'utils/file_saver.dart';

class ProcessedFileItem {
  final String fileName;
  final String timeAgo;
  final String sizeStr;
  final Uint8List bytes;
  final bool isPdf;

  ProcessedFileItem({
    required this.fileName,
    required this.timeAgo,
    required this.sizeStr,
    required this.bytes,
    required this.isPdf,
  });
}

final recentProcessedFilesProvider = StateProvider<List<ProcessedFileItem>>((ref) => []);

class ToolWorkspaceScreen extends ConsumerStatefulWidget {
  final String toolId;
  const ToolWorkspaceScreen({super.key, required this.toolId});

  @override
  ConsumerState<ToolWorkspaceScreen> createState() => _ToolWorkspaceScreenState();
}

class _ToolWorkspaceScreenState extends ConsumerState<ToolWorkspaceScreen> {
  // General state
  bool _isProcessing = false;
  String? _selectedFileName;
  int _selectedFileSize = 0;
  Uint8List? _selectedFileBytes;

  // Image Converter state
  String _targetFormat = 'png';

  // Compress Image state
  double _imageQuality = 65;
  int? _maxDimension;
  double _backgroundTolerance = 36;
  Uint8List? _backgroundRemovedBytes;

  // Image Watermark state
  String _imageWatermarkPreset = 'bottomRight';

  // QR state
  int _qrMode = 0; // 0 = text, 1 = image
  final TextEditingController _qrTextCtrl = TextEditingController(text: 'https://campussetu.in');
  String? _qrImagePayload;

  // Barcode state
  final TextEditingController _barcodeCtrl = TextEditingController(text: 'CAMPUS2026');

  // PDF to Word state
  PdfExtractionResult? _pdfToWordResult;

  // PDF watermark state
  final TextEditingController _pdfWatermarkCtrl = TextEditingController(text: 'CONFIDENTIAL');
  int _pdfTotalPages = 0;
  WatermarkStyle _pdfWatermarkStyle = WatermarkStyle.centerDiagonal;
  Color _pdfWatermarkColor = const Color(0xFF6B7280);
  double _pdfWatermarkOpacity = 0.22;
  Uint8List? _pdfWatermarkedBytes;

  // Compress PDF state
  int _pdfCompressQuality = 2;
  Uint8List? _compressedPdfResultBytes;

  // Word to PDF state
  final TextEditingController _wordTitleCtrl = TextEditingController(text: 'CampusSetu Document');
  final TextEditingController _wordTextCtrl = TextEditingController();
  bool _isWordTextMode = false;
  Uint8List? _wordConvertedPdfBytes;

  // TXT to Word & PDF state
  final TextEditingController _txtInputCtrl = TextEditingController();

  // CSV to Excel & PDF state
  List<List<String>> _csvParsedRows = [];
  String _csvRawText = '';

  // PPT / PPTX to PDF state
  Uint8List? _convertedPptPdfBytes;

  // PDF to PPTX state
  Uint8List? _convertedPptxBytes;

  // Image OCR state
  final TextEditingController _ocrTextCtrl = TextEditingController();
  bool _ocrDone = false;
  OcrDocumentResult? _ocrResult;
  bool _preserveLayout = true;

  // Image to PDF state
  final List<Uint8List> _imagesForPdf = [];
  ImagePdfMargin _imagePdfMargin = ImagePdfMargin.none;
  ImagePdfPageFit _imagePdfPageFit = ImagePdfPageFit.fitImage;
  final List<Uint8List> _pdfsToMerge = [];
  final List<String> _pdfNamesToMerge = [];
  final TextEditingController _htmlSourceCtrl = TextEditingController();

  // Delete PDF Pages state
  final Set<int> _pagesToDelete = {};

  // Organize PDF state
  List<int> _pageOrder = [];

  @override
  void dispose() {
    _qrTextCtrl.dispose();
    _barcodeCtrl.dispose();
    _wordTitleCtrl.dispose();
    _wordTextCtrl.dispose();
    _txtInputCtrl.dispose();
    _ocrTextCtrl.dispose();
    _htmlSourceCtrl.dispose();
    _pdfWatermarkCtrl.dispose();
    super.dispose();
  }

  void _recordRecentFile(String name, Uint8List bytes, bool isPdf) {
    final sizeKb = (bytes.lengthInBytes / 1024).toStringAsFixed(1);
    final sizeStr = bytes.lengthInBytes > 1024 * 1024
        ? '${(bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(2)} MB'
        : '$sizeKb KB';

    final newItem = ProcessedFileItem(
      fileName: name,
      timeAgo: 'Just now',
      sizeStr: sizeStr,
      bytes: bytes,
      isPdf: isPdf,
    );

    ref.read(recentProcessedFilesProvider.notifier).update((list) => [newItem, ...list]);
  }

  Future<void> _pickSingleFile({List<String>? extensions, bool isImage = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: isImage ? FileType.image : (extensions != null ? FileType.custom : FileType.any),
      allowedExtensions: extensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    setState(() {
      _selectedFileName = file.name;
      _selectedFileSize = bytes!.lengthInBytes;
      _selectedFileBytes = bytes;
      _backgroundRemovedBytes = null;
      _pdfToWordResult = null;
      _pagesToDelete.clear();
      _convertedPptPdfBytes = null;
      _convertedPptxBytes = null;

      if (widget.toolId == 'csv_to_excel_pdf') {
        _csvRawText = utf8.decode(bytes, allowMalformed: true);
        _csvParsedRows = PdfToolsService.parseCsv(_csvRawText);
      } else if (widget.toolId == 'txt_to_word_pdf') {
        _txtInputCtrl.text = utf8.decode(bytes, allowMalformed: true);
      } else if (widget.toolId == 'image_ocr_to_pdf_word') {
        _ocrDone = false;
        _ocrResult = null;
        _ocrTextCtrl.clear();
      }

      if (widget.toolId.contains('pdf') || widget.toolId == 'delete_pages' || widget.toolId == 'organize_pdf') {
        _pdfTotalPages = PdfToolsService.getPageCount(bytes);
        _pageOrder = List.generate(_pdfTotalPages, (i) => i + 1);
      }
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final tool = ToolsData.findById(widget.toolId);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark ||
        Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F111A) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF1A1D2B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF282D42) : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);
    final textMuted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final recentFiles = ref.watch(recentProcessedFilesProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bgColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          tool?.name ?? 'Tool Workspace',
          style: AppTypography.soraHeading2().copyWith(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // ── Central Workspace Card (Matching Screenshot 2) ─
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top Circular Icon Container
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark ? (tool?.iconBgColor ?? const Color(0xFF1E3A8A)) : (tool?.iconBgColor ?? const Color(0xFF1E3A8A)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          tool?.icon ?? Icons.auto_fix_high_rounded,
                          color: isDark ? (tool?.iconColor ?? const Color(0xFF60A5FA)) : (tool?.iconBgColor ?? const Color(0xFF1E3A8A)),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Tool Title
                      Text(
                        tool?.name ?? 'Tool',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tool Description
                      Text(
                        tool?.description ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),

                      // Info Badge (Matching Screenshot 2)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131D30) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E3354) : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Free & 100% Client-Side: Zero server upload',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Tool Specific Controls / Selector ─────
                      _buildToolWorkspaceBody(isDark, textColor, textMuted),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ── Recent Files Section (Matching Screenshot 2) ──
                Row(
                  children: [
                    Icon(Icons.history_rounded, size: 20, color: textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Recent files',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (recentFiles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Center(
                      child: Text(
                        'No processed files yet in this session.\nFiles you download will appear here.',
                        style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...recentFiles.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7F1D1D).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.description_rounded,
                              color: Color(0xFFF87171),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.fileName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.timeAgo} • ${item.sizeStr}',
                                  style: TextStyle(fontSize: 11, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_rounded, color: Color(0xFF38BDF8), size: 20),
                            tooltip: 'Download again',
                            onPressed: () => saveAndDownloadFile(item.bytes, item.fileName),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Builds the exact tool interactive interface ───────────────
  Widget _buildToolWorkspaceBody(bool isDark, Color textColor, Color textMuted) {
    switch (widget.toolId) {
      case 'image_convert':
        return _buildImageConverter(isDark, textColor, textMuted);
      case 'compress_image':
        return _buildCompressImage(isDark, textColor, textMuted);
      case 'background_remover':
        return _buildBackgroundRemover(textColor, textMuted);
      case 'image_watermark':
        return _buildImageWatermark(isDark, textColor, textMuted);
      case 'qr_generator':
        return _buildQrGenerator(isDark, textColor, textMuted);
      case 'barcode_generator':
        return _buildBarcodeGenerator(isDark, textColor, textMuted);
      case 'image_ocr_to_pdf_word':
        return _buildImageOcrToPdfWord(isDark, textColor, textMuted);
      case 'merge_pdf':
        return _buildMergePdfs(textColor, textMuted);
      case 'split_pdf':
      case 'extract_pdf_pages':
        return _buildExtractPdf(textColor, textMuted);
      case 'html_to_pdf':
        return _buildHtmlToPdf(textColor, textMuted);
      case 'pdf_to_jpg':
        return _buildPdfToImages(textColor, textMuted);
      case 'pdf_to_word':
        return _buildPdfToWord(isDark, textColor, textMuted);
      case 'add_pdf_watermark':
        return _buildPdfWatermark(isDark, textColor, textMuted);
      case 'word_to_pdf':
        return _buildWordToPdf(isDark, textColor, textMuted);
      case 'compress_pdf':
        return _buildCompressPdf(isDark, textColor, textMuted);
      case 'image_to_pdf':
        return _buildImageToPdf(isDark, textColor, textMuted);
      case 'scan_to_pdf':
        return _buildScanToPdf(textColor, textMuted);
      case 'delete_pages':
        return _buildDeletePdfPages(isDark, textColor, textMuted);
      case 'organize_pdf':
        return _buildOrganizePdf(isDark, textColor, textMuted);
      case 'ppt_to_pdf':
      case 'pptx_to_pdf':
        return _buildPptToPdf(isDark, textColor, textMuted);
      case 'csv_to_excel_pdf':
        return _buildCsvToExcelPdf(isDark, textColor, textMuted);
      case 'txt_to_word_pdf':
        return _buildTxtToWordPdf(isDark, textColor, textMuted);
      case 'pdf_to_pptx':
        return _buildPdfToPptx(isDark, textColor, textMuted);
      default:
        return _buildDefaultFilePicker('+ Select File');
    }
  }

  Widget _buildMergePdfs(Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: '+ Add PDF files',
          onTap: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['pdf'],
              allowMultiple: true,
              withData: true,
            );
            if (result == null) return;
            for (final file in result.files) {
              Uint8List? bytes = file.bytes;
              if (bytes == null && !kIsWeb && file.path != null) {
                bytes = await File(file.path!).readAsBytes();
              }
              if (bytes != null) {
                _pdfsToMerge.add(bytes);
                _pdfNamesToMerge.add(file.name);
              }
            }
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 10),
        Text('Files are read into memory and never uploaded.', style: TextStyle(color: textMuted, fontSize: 12)),
        for (var i = 0; i < _pdfNamesToMerge.length; i++)
          ListTile(
            dense: true,
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF38BDF8)),
            title: Text(_pdfNamesToMerge[i], style: TextStyle(color: textColor)),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _pdfNamesToMerge.removeAt(i);
                _pdfsToMerge.removeAt(i);
              }),
            ),
          ),
        const SizedBox(height: 12),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          _buildActionExecuteButton(
            label: 'Merge and download PDFs',
            icon: Icons.merge_rounded,
            onTap: _pdfsToMerge.length < 2
                ? null
                : () async {
                    setState(() => _isProcessing = true);
                    try {
                      final merged = await PdfToolsService.mergePdfFiles(_pdfsToMerge);
                      await saveAndDownloadFile(merged, 'merged_document.pdf');
                      _recordRecentFile('merged_document.pdf', merged, true);
                    } catch (error) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not merge these PDFs: $error')));
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
          ),
      ],
    );
  }

  Widget _buildExtractPdf(Color textColor, Color textMuted) {
    final isSplit = widget.toolId == 'split_pdf';
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF file' : 'Change PDF',
          onTap: () => _pickSingleFile(extensions: const ['pdf']),
        ),
        if (_selectedFileBytes != null && _pdfTotalPages > 0) ...[
          const SizedBox(height: 12),
          Text(
            isSplit ? 'Select the pages for this output part:' : 'Select the pages to keep:',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_pdfTotalPages, (index) {
              final page = index + 1;
              final selected = _pagesToDelete.contains(page);
              return FilterChip(
                label: Text(page.toString()),
                selected: selected,
                onSelected: (value) => setState(() {
                  if (value) {
                    _pagesToDelete.add(page);
                  } else {
                    _pagesToDelete.remove(page);
                  }
                }),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text('Selected pages: ' + _pagesToDelete.length.toString(), style: TextStyle(color: textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Export selected pages',
              icon: Icons.file_download_outlined,
              onTap: _pagesToDelete.isEmpty
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      try {
                        final extracted = await PdfToolsService.extractPdfPages(_selectedFileBytes!, _pagesToDelete.toList());
                        final outputName = isSplit ? 'split_pages.pdf' : 'extracted_pages.pdf';
                        await saveAndDownloadFile(extracted, outputName);
                        _recordRecentFile(outputName, extracted, true);
                      } catch (error) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export selected pages: $error')));
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
            ),
        ],
      ],
    );
  }

  Widget _buildHtmlToPdf(Color textColor, Color textMuted) {
    return Column(
      children: [
        TextField(
          controller: _htmlSourceCtrl,
          minLines: 8,
          maxLines: 14,
          style: TextStyle(color: textColor, fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Paste HTML',
            hintText: '<h1>My document</h1><p>Content…</p>',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Runs on this device with no AI or server upload. Text and basic HTML line breaks are preserved; external CSS and scripts are ignored.',
          style: TextStyle(color: textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          _buildActionExecuteButton(
            label: 'Create and download PDF',
            icon: Icons.picture_as_pdf_rounded,
            onTap: _htmlSourceCtrl.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => _isProcessing = true);
                    try {
                      final output = await PdfToolsService.htmlToPdf(_htmlSourceCtrl.text);
                      await saveAndDownloadFile(output, 'html_document.pdf');
                      _recordRecentFile('html_document.pdf', output, true);
                    } catch (error) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not convert HTML: $error')));
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
          ),
      ],
    );
  }

  Widget _buildPdfToImages(Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF file' : 'Change PDF',
          onTap: () => _pickSingleFile(extensions: const ['pdf']),
        ),
        if (_selectedFileBytes != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('$_pdfTotalPages page(s) • ${_formatSize(_selectedFileSize)}', style: TextStyle(color: textMuted, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          _buildActionExecuteButton(
            label: 'Render pages and download images',
            icon: Icons.image_outlined,
            onTap: _selectedFileBytes == null
                ? null
                : () async {
                    setState(() => _isProcessing = true);
                    try {
                      var pageIndex = 0;
                      await for (final raster in Printing.raster(_selectedFileBytes!, dpi: 144)) {
                        final rendered = await raster.toPng();
                        final converted = await ImageToolsService.convertImage(
                          rendered,
                          targetFormat: 'jpg',
                          quality: 90,
                        );
                        final jpgBytes = converted.bytes;
                        final name = 'pdf_page_' + (pageIndex + 1).toString() + '.jpg';
                        await saveAndDownloadFile(jpgBytes, name);
                        _recordRecentFile(name, jpgBytes, false);
                        pageIndex++;
                      }
                      if (mounted && pageIndex == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This PDF has no pages to export.')));
                      }
                    } catch (error) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not render this PDF: $error')));
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
          ),
        const SizedBox(height: 8),
        Text('Page images are generated in memory and saved only when you download them.', style: TextStyle(color: textMuted, fontSize: 12)),
      ],
    );
  }

  // 1. IMAGE CONVERTER
  Widget _buildImageConverter(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select Image' : 'Change Image',
          onTap: () => _pickSingleFile(extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'svg']),
        ),
        const SizedBox(height: 6),
        Text('Supports PNG, JPG, WEBP, BMP, GIF, and SVG', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (_selectedFileName?.toLowerCase().endsWith('.svg') == true)
                    ? Container(
                        width: 70,
                        height: 70,
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                        child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF60A5FA), size: 30),
                      )
                    : Image.memory(_selectedFileBytes!, width: 70, height: 70, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedFileName ?? 'image', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    Text('Size: ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Convert To Format:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['png', 'jpg', 'webp', 'bmp', 'gif', 'svg'].map((fmt) {
              final isSel = _targetFormat == fmt;
              return ChoiceChip(
                label: Text(fmt.toUpperCase()),
                selected: isSel,
                selectedColor: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _targetFormat = fmt),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Convert & Download ${_targetFormat.toUpperCase()}',
              icon: Icons.download_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final res = await ImageToolsService.convertImage(
                    _selectedFileBytes!,
                    targetFormat: _targetFormat,
                  );
                  final base = (_selectedFileName ?? 'image').split('.').first;
                  final outName = '$base.$_targetFormat';
                  await saveAndDownloadFile(res.bytes, outName);
                  _recordRecentFile(outName, res.bytes, false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Image converted and downloaded!'),
                      backgroundColor: AppColors.success,
                    ));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
        ],
      ],
    );
  }

  // 1A. IMAGE TO PDF & WORD (OCR EXTRACTOR)
  Widget _buildImageOcrToPdfWord(bool isDark, Color textColor, Color textMuted) {
    final baseName = (_selectedFileName ?? 'document').split('.').first;
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select Image for OCR' : 'Change Image',
          onTap: () => _pickSingleFile(extensions: ['jpg', 'jpeg', 'png', 'webp']),
        ),
        const SizedBox(height: 6),
        Text('Extracts text from photos, scans, receipts or notes', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_selectedFileBytes!, width: 64, height: 64, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedFileName ?? 'image', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    Text('Size: ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isProcessing)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text('Extracting text with OCR...', style: TextStyle(fontSize: 12, color: textMuted)),
              ],
            )
          else if (!_ocrDone)
            _buildActionExecuteButton(
              label: 'Extract Text (OCR)',
              icon: Icons.document_scanner_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final result = await performImageOcr(
                    _selectedFileBytes!,
                    fileName: _selectedFileName,
                  );
                  setState(() {
                    _ocrResult = result;
                    _ocrTextCtrl.text = result.fullText;
                    _ocrDone = true;
                  });
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x1F0284C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x4D0284C7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Layout Detected: ${_ocrResult?.lines.length ?? 0} lines. Centers, margins & side text preserved.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF38BDF8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preserve exact visual alignment in Word & PDF',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                ),
                Switch(
                  value: _preserveLayout,
                  activeThumbColor: const Color(0xFF38BDF8),
                  onChanged: (v) => setState(() => _preserveLayout = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Extracted Text (Editable):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _ocrTextCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text copied to clipboard!')));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF38BDF8)),
                    label: const Text('Copy', style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141724) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF282D42) : Colors.grey.shade300),
              ),
              child: TextField(
                controller: _ocrTextCtrl,
                maxLines: 7,
                style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Extracted text will appear here...',
                  hintStyle: TextStyle(color: textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildActionExecuteButton(
                    label: 'Export PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    onTap: _ocrTextCtrl.text.trim().isEmpty ? null : () async {
                      setState(() => _isProcessing = true);
                      try {
                        final pdf = OcrService.exportToPdf(
                          _ocrTextCtrl.text,
                          ocrResult: _ocrResult,
                          preserveLayout: _preserveLayout,
                          title: baseName,
                        );
                        final outName = '${baseName}_ocr.pdf';
                        await saveAndDownloadFile(pdf, outName);
                        _recordRecentFile(outName, pdf, true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('OCR PDF downloaded!'),
                            backgroundColor: AppColors.success,
                          ));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionExecuteButton(
                    label: 'Export Word (.docx)',
                    icon: Icons.description_rounded,
                    onTap: _ocrTextCtrl.text.trim().isEmpty ? null : () async {
                      setState(() => _isProcessing = true);
                      try {
                        final docx = OcrService.exportToDocx(
                          _ocrTextCtrl.text,
                          ocrResult: _ocrResult,
                          preserveLayout: _preserveLayout,
                        );
                        final outName = '${baseName}_ocr.docx';
                        await saveAndDownloadFile(docx, outName);
                        _recordRecentFile(outName, docx, false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('OCR Word document downloaded!'),
                            backgroundColor: AppColors.success,
                          ));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  // PPT / PPTX TO PDF
  Widget _buildPptToPdf(bool isDark, Color textColor, Color textMuted) {
    final baseName = (_selectedFileName ?? 'presentation').replaceAll(RegExp(r'\.(pptx|ppt)$', caseSensitive: false), '');
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PowerPoint File' : 'Change Presentation',
          onTap: () => _pickSingleFile(extensions: ['pptx', 'ppt']),
        ),
        const SizedBox(height: 6),
        Text('Supports .pptx and .ppt presentations', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFB45309).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.slideshow_rounded, color: Color(0xFFFBBF24), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedFileName ?? 'presentation.pptx', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    Text('Size: ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else if (_convertedPptPdfBytes == null)
            _buildActionExecuteButton(
              label: 'Convert to PDF',
              icon: Icons.picture_as_pdf_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final pdf = await PdfToolsService.pptxToPdf(_selectedFileBytes!);
                  setState(() => _convertedPptPdfBytes = pdf);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Presentation converted to landscape PDF slides!',
                      style: TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildActionExecuteButton(
              label: 'Download PDF (${_formatSize(_convertedPptPdfBytes!.lengthInBytes)})',
              icon: Icons.download_rounded,
              onTap: () async {
                final outName = '${baseName}_slides.pdf';
                await saveAndDownloadFile(_convertedPptPdfBytes!, outName);
                _recordRecentFile(outName, _convertedPptPdfBytes!, true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Presentation PDF downloaded!'),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
            ),
          ],
        ],
      ],
    );
  }

  // CSV TO EXCEL & PDF
  Widget _buildCsvToExcelPdf(bool isDark, Color textColor, Color textMuted) {
    final baseName = (_selectedFileName ?? 'data').replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
    final totalRows = _csvParsedRows.length;
    final totalCols = _csvParsedRows.isNotEmpty ? _csvParsedRows.first.length : 0;

    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select CSV File' : 'Change CSV File',
          onTap: () => _pickSingleFile(extensions: ['csv', 'txt']),
        ),
        const SizedBox(height: 6),
        Text('Upload comma, semicolon, or tab-delimited CSV', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart_rounded, color: Color(0xFF34D399), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedFileName ?? 'data.csv', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    Text('Rows: $totalRows • Columns: $totalCols • ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (_csvParsedRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141724) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF282D42) : Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 34,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 34,
                    columnSpacing: 18,
                    columns: List.generate(
                      totalCols,
                      (colIdx) => DataColumn(
                        label: Text(
                          colIdx < _csvParsedRows.first.length ? _csvParsedRows.first[colIdx] : 'Col ${colIdx + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor),
                        ),
                      ),
                    ),
                    rows: _csvParsedRows.skip(1).take(5).map((row) {
                      return DataRow(
                        cells: List.generate(
                          totalCols,
                          (c) => DataCell(
                            Text(c < row.length ? row[c] : '', style: TextStyle(fontSize: 11, color: textMuted)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            Row(
              children: [
                Expanded(
                  child: _buildActionExecuteButton(
                    label: 'Excel (.xlsx)',
                    icon: Icons.table_view_rounded,
                    onTap: () async {
                      setState(() => _isProcessing = true);
                      try {
                        final xlsxBytes = PdfToolsService.csvToExcelXlsx(_csvRawText);
                        final outName = '$baseName.xlsx';
                        await saveAndDownloadFile(xlsxBytes, outName);
                        _recordRecentFile(outName, xlsxBytes, false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Excel spreadsheet downloaded!'),
                            backgroundColor: AppColors.success,
                          ));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionExecuteButton(
                    label: 'PDF Table',
                    icon: Icons.picture_as_pdf_rounded,
                    onTap: () async {
                      setState(() => _isProcessing = true);
                      try {
                        final pdfBytes = PdfToolsService.csvToPdf(_csvRawText, title: baseName);
                        final outName = '${baseName}_table.pdf';
                        await saveAndDownloadFile(pdfBytes, outName);
                        _recordRecentFile(outName, pdfBytes, true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('PDF table document downloaded!'),
                            backgroundColor: AppColors.success,
                          ));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  // TXT TO WORD & PDF
  Widget _buildTxtToWordPdf(bool isDark, Color textColor, Color textMuted) {
    final baseName = (_selectedFileName ?? 'document').replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select .txt File' : 'Change .txt File',
          onTap: () => _pickSingleFile(extensions: ['txt', 'text']),
        ),
        const SizedBox(height: 6),
        Text('or type / paste your text below', style: TextStyle(fontSize: 12, color: textMuted)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141724) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF282D42) : Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _txtInputCtrl,
                maxLines: 7,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Paste or enter text here to convert into Word or PDF...',
                  hintStyle: TextStyle(color: textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_txtInputCtrl.text.length} chars • ${_txtInputCtrl.text.trim().isEmpty ? 0 : _txtInputCtrl.text.trim().split(RegExp(r'\s+')).length} words',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                  if (_txtInputCtrl.text.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() => _txtInputCtrl.clear()),
                      child: Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          Row(
            children: [
              Expanded(
                child: _buildActionExecuteButton(
                  label: 'Word (.docx)',
                  icon: Icons.description_rounded,
                  onTap: _txtInputCtrl.text.trim().isEmpty ? null : () async {
                    setState(() => _isProcessing = true);
                    try {
                      final docx = PdfToolsService.txtToDocx(_txtInputCtrl.text);
                      final outName = '$baseName.docx';
                      await saveAndDownloadFile(docx, outName);
                      _recordRecentFile(outName, docx, false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Word document downloaded!'),
                          backgroundColor: AppColors.success,
                        ));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionExecuteButton(
                  label: 'PDF Document',
                  icon: Icons.picture_as_pdf_rounded,
                  onTap: _txtInputCtrl.text.trim().isEmpty ? null : () async {
                    setState(() => _isProcessing = true);
                    try {
                      final pdf = PdfToolsService.txtToPdf(_txtInputCtrl.text, title: baseName);
                      final outName = '$baseName.pdf';
                      await saveAndDownloadFile(pdf, outName);
                      _recordRecentFile(outName, pdf, true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('PDF document downloaded!'),
                          backgroundColor: AppColors.success,
                        ));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  // PDF TO POWERPOINT (.pptx)
  Widget _buildPdfToPptx(bool isDark, Color textColor, Color textMuted) {
    final baseName = (_selectedFileName ?? 'presentation').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF File' : 'Change PDF File',
          onTap: () => _pickSingleFile(extensions: ['pdf']),
        ),
        const SizedBox(height: 6),
        Text('Convert PDF pages into editable PowerPoint slides', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C2D12).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.co_present_rounded, color: Color(0xFFFB923C), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedFileName ?? 'document.pdf', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    Text('$_pdfTotalPages page(s) • ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Rendering slides & creating PowerPoint (.pptx)...'),
              ],
            )
          else if (_convertedPptxBytes == null)
            _buildActionExecuteButton(
              label: 'Convert to PowerPoint (.pptx)',
              icon: Icons.slideshow_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final pptx = await PdfToolsService.pdfToPptx(_selectedFileBytes!, title: baseName);
                  setState(() => _convertedPptxBytes = pptx);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'PowerPoint (.pptx) created with $_pdfTotalPages slides!',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildActionExecuteButton(
              label: 'Download PowerPoint (.pptx)',
              icon: Icons.download_rounded,
              onTap: () async {
                final outName = '${baseName}_presentation.pptx';
                await saveAndDownloadFile(_convertedPptxBytes!, outName);
                _recordRecentFile(outName, _convertedPptxBytes!, false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('PowerPoint file downloaded!'),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
            ),
          ],
        ],
      ],
    );
  }

  // 2. COMPRESS IMAGE
  Widget _buildCompressImage(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select Image' : 'Change Image',
          onTap: () => _pickSingleFile(isImage: true),
        ),
        const SizedBox(height: 6),
        Text('or drag and drop files here', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Compression Quality: ${_imageQuality.toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text(_imageQuality < 50 ? 'High Compression' : 'High Quality', style: TextStyle(fontSize: 12, color: textMuted)),
            ],
          ),
          Slider(
            value: _imageQuality,
            min: 10,
            max: 95,
            divisions: 17,
            activeColor: const Color(0xFF38BDF8),
            onChanged: (v) => setState(() => _imageQuality = v),
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Compress & Download Image',
              icon: Icons.compress_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final res = await ImageToolsService.compressImage(
                    _selectedFileBytes!,
                    quality: _imageQuality.toInt(),
                    maxDimension: _maxDimension,
                  );
                  final base = (_selectedFileName ?? 'image').split('.').first;
                  final outName = '${base}_compressed.jpg';
                  await saveAndDownloadFile(res.bytes, outName);
                  _recordRecentFile(outName, res.bytes, false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Compressed from ${_formatSize(res.originalSize)} to ${_formatSize(res.newSize)} (Saved ${res.savingsPercent.toStringAsFixed(0)}%)!'),
                      backgroundColor: AppColors.success,
                    ));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
        ],
      ],
    );
  }

  Widget _buildBackgroundRemover(Color textColor, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select Image' : 'Change Image',
          onTap: () => _pickSingleFile(
            extensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'],
            isImage: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Runs offline on this device. Best results come from a plain or near-uniform background.',
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _backgroundRemovedBytes ?? _selectedFileBytes!,
              height: 220,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Background tolerance', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              ),
              Text(_backgroundTolerance.round().toString(), style: TextStyle(color: textMuted)),
            ],
          ),
          Slider(
            value: _backgroundTolerance,
            min: 8,
            max: 110,
            divisions: 102,
            onChanged: _isProcessing
                ? null
                : (value) => setState(() {
                      _backgroundTolerance = value;
                      _backgroundRemovedBytes = null;
                    }),
          ),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            _buildActionExecuteButton(
              label: _backgroundRemovedBytes == null ? 'Remove Background' : 'Retry with Current Tolerance',
              icon: Icons.auto_awesome_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final result = await ImageToolsService.removeBackground(
                    _selectedFileBytes!,
                    tolerance: _backgroundTolerance.round(),
                  );
                  if (mounted) setState(() => _backgroundRemovedBytes = result);
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Background removal failed: $error')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
          if (_backgroundRemovedBytes != null) ...[
            const SizedBox(height: 10),
            _buildActionExecuteButton(
              label: 'Download transparent PNG',
              icon: Icons.download_rounded,
              onTap: () async {
                final base = (_selectedFileName ?? 'image').split('.').first;
                final name = '${base}_no_background.png';
                await saveAndDownloadFile(_backgroundRemovedBytes!, name);
                _recordRecentFile(name, _backgroundRemovedBytes!, false);
              },
            ),
          ],
        ],
      ],
    );
  }

  // 3. IMAGE WATERMARK REMOVER
  Widget _buildImageWatermark(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select Image' : 'Change Image',
          onTap: () => _pickSingleFile(isImage: true),
        ),
        const SizedBox(height: 6),
        Text('or drag and drop files here', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Watermark Position:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _presetChip('Bottom Right', 'bottomRight', _imageWatermarkPreset, (v) => setState(() => _imageWatermarkPreset = v)),
              _presetChip('Bottom Left', 'bottomLeft', _imageWatermarkPreset, (v) => setState(() => _imageWatermarkPreset = v)),
              _presetChip('Top Right', 'topRight', _imageWatermarkPreset, (v) => setState(() => _imageWatermarkPreset = v)),
              _presetChip('Center Stamp', 'center', _imageWatermarkPreset, (v) => setState(() => _imageWatermarkPreset = v)),
            ],
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Erase Watermark & Download',
              icon: Icons.cleaning_services_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                Rect area;
                switch (_imageWatermarkPreset) {
                  case 'bottomRight': area = const Rect.fromLTWH(0.65, 0.82, 0.33, 0.16); break;
                  case 'bottomLeft': area = const Rect.fromLTWH(0.02, 0.82, 0.33, 0.16); break;
                  case 'topRight': area = const Rect.fromLTWH(0.65, 0.02, 0.33, 0.16); break;
                  default: area = const Rect.fromLTWH(0.25, 0.35, 0.50, 0.30); break;
                }
                try {
                  final cleaned = await ImageToolsService.removeWatermark(_selectedFileBytes!, relativeArea: area);
                  final base = (_selectedFileName ?? 'image').split('.').first;
                  final outName = '${base}_clean.png';
                  await saveAndDownloadFile(cleaned, outName);
                  _recordRecentFile(outName, cleaned, false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Watermark erased & downloaded!'), backgroundColor: AppColors.success));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
        ],
      ],
    );
  }

  // 4. QR GENERATOR
  Widget _buildQrGenerator(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Text / URL to QR'),
              selected: _qrMode == 0,
              onSelected: (_) => setState(() => _qrMode = 0),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('Image to QR'),
              selected: _qrMode == 1,
              onSelected: (_) => setState(() => _qrMode = 1),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_qrMode == 0) ...[
          TextField(
            controller: _qrTextCtrl,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Enter text, URL, roll number...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          if (_qrTextCtrl.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: _qrTextCtrl.text, version: QrVersions.auto, size: 180),
            ),
            const SizedBox(height: 18),
            _buildActionExecuteButton(
              label: 'Download QR Code (PNG)',
              icon: Icons.download_rounded,
              onTap: () async {
                final png = await ImageToolsService.generateQrPng(_qrTextCtrl.text);
                await saveAndDownloadFile(png, 'qr_code.png');
                _recordRecentFile('qr_code.png', png, false);
              },
            ),
          ],
        ] else ...[
          _buildPrimarySelectButton(
            label: _selectedFileName == null ? '+ Select Image for QR' : 'Change Image',
            onTap: () async {
              await _pickSingleFile(isImage: true);
              if (_selectedFileBytes != null) {
                final payload = await ImageToolsService.prepareImageForQr(_selectedFileBytes!);
                setState(() => _qrImagePayload = payload);
              }
            },
          ),
          if (_qrImagePayload != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: _qrImagePayload!, version: QrVersions.auto, size: 180),
            ),
            const SizedBox(height: 18),
            _buildActionExecuteButton(
              label: 'Download Image QR (PNG)',
              icon: Icons.download_rounded,
              onTap: () async {
                final png = await ImageToolsService.generateQrPng(_qrImagePayload!);
                await saveAndDownloadFile(png, 'image_qr.png');
                _recordRecentFile('image_qr.png', png, false);
              },
            ),
          ],
        ],
      ],
    );
  }

  // 5. BARCODE GENERATOR
  Widget _buildBarcodeGenerator(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        TextField(
          controller: _barcodeCtrl,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Enter text, ID, or Roll Number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        if (_barcodeCtrl.text.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: BarcodeWidget(
              barcode: Barcode.code128(),
              data: _barcodeCtrl.text,
              width: 250,
              height: 85,
              drawText: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 18),
          _buildActionExecuteButton(
            label: 'Download Barcode (PNG)',
            icon: Icons.download_rounded,
            onTap: () async {
              final png = await ImageToolsService.generateBarcodePng(_barcodeCtrl.text);
              final outName = 'barcode_${_barcodeCtrl.text}.png';
              await saveAndDownloadFile(png, outName);
              _recordRecentFile(outName, png, false);
            },
          ),
        ],
      ],
    );
  }

  // 6. PDF TO WORD (.docx)
  Widget _buildPdfToWord(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF File' : 'Change PDF',
          onTap: () => _pickSingleFile(extensions: ['pdf']),
        ),
        const SizedBox(height: 6),
        Text('Convert PDF document into editable Microsoft Word (.docx)', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Text(_selectedFileName ?? 'document.pdf', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          Text('$_pdfTotalPages page(s) • ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
          const SizedBox(height: 18),
          if (_isProcessing)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Preserving layout & creating Word document (.docx)...'),
              ],
            )
          else if (_pdfToWordResult == null)
            _buildActionExecuteButton(
              label: 'Convert to Word (.docx)',
              icon: Icons.transform_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final res = await PdfToolsService.pdfToWordDocx(_selectedFileBytes!);
                  setState(() => _pdfToWordResult = res);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Conversion Complete!',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Your Word document (.docx) with ${_pdfToWordResult!.pageCount} page(s) is ready.',
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildActionExecuteButton(
              label: 'Download Word (.docx)',
              icon: Icons.download_rounded,
              onTap: () async {
                final base = (_selectedFileName ?? 'doc').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                final outName = '$base.docx';
                await saveAndDownloadFile(_pdfToWordResult!.docxBytes, outName);
                _recordRecentFile(outName, _pdfToWordResult!.docxBytes, false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Word document (.docx) downloaded successfully!'),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
            ),
          ],
        ],
      ],
    );
  }

  // 7. ADD WATERMARK TO PDF
  Widget _buildPdfWatermark(bool isDark, Color textColor, Color textMuted) {
    final canApply = _selectedFileBytes != null && _pdfWatermarkCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. PDF File Selector (Can pick first or after typing text)
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF File' : 'Change PDF (${_selectedFileName!})',
          onTap: () => _pickSingleFile(extensions: ['pdf']),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _selectedFileBytes != null
                ? '$_pdfTotalPages page(s) selected • ${_formatSize(_selectedFileSize)}'
                : 'Select PDF to watermark (or enter text below first)',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Watermark Text Field (Always accessible!)
        TextField(
          controller: _pdfWatermarkCtrl,
          maxLength: 60,
          style: TextStyle(color: textColor),
          onChanged: (_) => setState(() => _pdfWatermarkedBytes = null),
          decoration: InputDecoration(
            labelText: 'Watermark Text',
            hintText: 'e.g. CONFIDENTIAL, DRAFT, DO NOT COPY',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            isDense: true,
            prefixIcon: const Icon(Icons.branding_watermark_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 10),

        // 3. Placement Style Selector
        Text('Watermark Style & Direction:', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Center Diagonal (Cross)'),
              avatar: const Icon(Icons.trending_up_rounded, size: 16),
              selected: _pdfWatermarkStyle == WatermarkStyle.centerDiagonal,
              onSelected: (val) {
                if (val) setState(() { _pdfWatermarkStyle = WatermarkStyle.centerDiagonal; _pdfWatermarkedBytes = null; });
              },
            ),
            ChoiceChip(
              label: const Text('Repeated Pattern (Corner to Corner)'),
              avatar: const Icon(Icons.grid_4x4_rounded, size: 16),
              selected: _pdfWatermarkStyle == WatermarkStyle.tiledDiagonal,
              onSelected: (val) {
                if (val) setState(() { _pdfWatermarkStyle = WatermarkStyle.tiledDiagonal; _pdfWatermarkedBytes = null; });
              },
            ),
            ChoiceChip(
              label: const Text('Center Horizontal'),
              avatar: const Icon(Icons.horizontal_rule_rounded, size: 16),
              selected: _pdfWatermarkStyle == WatermarkStyle.centerHorizontal,
              onSelected: (val) {
                if (val) setState(() { _pdfWatermarkStyle = WatermarkStyle.centerHorizontal; _pdfWatermarkedBytes = null; });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4. Color & Intensity
        Row(
          children: [
            Text('Color: ', style: TextStyle(fontSize: 12, color: textMuted)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() { _pdfWatermarkColor = const Color(0xFF6B7280); _pdfWatermarkedBytes = null; }),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF6B7280),
                child: _pdfWatermarkColor == const Color(0xFF6B7280) ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() { _pdfWatermarkColor = const Color(0xFFEF4444); _pdfWatermarkedBytes = null; }),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFEF4444),
                child: _pdfWatermarkColor == const Color(0xFFEF4444) ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() { _pdfWatermarkColor = const Color(0xFF3B82F6); _pdfWatermarkedBytes = null; }),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF3B82F6),
                child: _pdfWatermarkColor == const Color(0xFF3B82F6) ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            const Spacer(),
            Text('Intensity: ', style: TextStyle(fontSize: 12, color: textMuted)),
            DropdownButton<double>(
              value: _pdfWatermarkOpacity,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 0.15, child: Text('Light (15%)')),
                DropdownMenuItem(value: 0.22, child: Text('Standard (22%)')),
                DropdownMenuItem(value: 0.38, child: Text('Bold (38%)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() { _pdfWatermarkOpacity = val; _pdfWatermarkedBytes = null; });
              },
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (_isProcessing)
          const Center(child: CircularProgressIndicator())
        else if (_pdfWatermarkedBytes == null)
          _buildActionExecuteButton(
            label: canApply
                ? 'Apply Watermark to PDF'
                : (_selectedFileBytes == null ? 'Select PDF to Continue' : 'Enter Watermark Text'),
            icon: Icons.branding_watermark_rounded,
            onTap: canApply
                ? () async {
                    setState(() => _isProcessing = true);
                    try {
                      final watermarked = await PdfToolsService.addPdfWatermark(
                        _selectedFileBytes!,
                        watermark: _pdfWatermarkCtrl.text.trim(),
                        style: _pdfWatermarkStyle,
                        opacity: _pdfWatermarkOpacity,
                        color: _pdfWatermarkColor,
                      );
                      setState(() => _pdfWatermarkedBytes = watermarked);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  }
                : null,
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Watermark Applied Successfully!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Applied across all $_pdfTotalPages page(s)',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildActionExecuteButton(
            label: 'Download Watermarked PDF',
            icon: Icons.download_rounded,
            onTap: () async {
              final base = (_selectedFileName ?? 'document').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
              final outName = '${base}_watermarked.pdf';
              await saveAndDownloadFile(_pdfWatermarkedBytes!, outName);
              _recordRecentFile(outName, _pdfWatermarkedBytes!, true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Watermarked PDF downloaded successfully!'),
                  backgroundColor: AppColors.success,
                ));
              }
            },
          ),
        ],
      ],
    );
  }

  // 8. WORD TO PDF
  Widget _buildWordToPdf(bool isDark, Color textColor, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.description_rounded, size: 18),
                label: const Text('Upload Word File'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: !_isWordTextMode ? AppColors.cyanDeep.withValues(alpha: 0.1) : null,
                  side: BorderSide(color: !_isWordTextMode ? AppColors.cyanDeep : Colors.grey.shade300),
                ),
                onPressed: () => setState(() => _isWordTextMode = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Type Text Directly'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _isWordTextMode ? AppColors.cyanDeep.withValues(alpha: 0.1) : null,
                  side: BorderSide(color: _isWordTextMode ? AppColors.cyanDeep : Colors.grey.shade300),
                ),
                onPressed: () => setState(() => _isWordTextMode = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (!_isWordTextMode) ...[
          _buildPrimarySelectButton(
            label: _selectedFileName == null ? '+ Select Word File (.docx, .doc)' : 'Change Word File',
            onTap: () => _pickSingleFile(extensions: ['docx', 'doc', 'txt']),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _selectedFileBytes != null
                  ? 'Selected: ${_selectedFileName ?? 'document'} • ${_formatSize(_selectedFileSize)}'
                  : 'Convert Microsoft Word documents directly into PDF',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
        ] else ...[
          TextField(
            controller: _wordTitleCtrl,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Document Title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _wordTextCtrl,
            style: TextStyle(color: textColor),
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'Type, paste or write document text here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],

        const SizedBox(height: 18),
        if (_isProcessing)
          const Center(child: CircularProgressIndicator())
        else if (_wordConvertedPdfBytes == null)
          _buildActionExecuteButton(
            label: _isWordTextMode ? 'Convert Text to PDF' : 'Convert Word to PDF',
            icon: Icons.picture_as_pdf_rounded,
            onTap: (!_isWordTextMode && _selectedFileBytes == null)
                ? null
                : () async {
                    setState(() => _isProcessing = true);
                    try {
                      Uint8List pdf;
                      if (_isWordTextMode) {
                        if (_wordTextCtrl.text.trim().isEmpty) return;
                        pdf = await PdfToolsService.wordToPdf(_wordTextCtrl.text.trim(), title: _wordTitleCtrl.text.trim());
                      } else {
                        pdf = await PdfToolsService.docxToPdf(_selectedFileBytes!, title: _selectedFileName?.split('.').first ?? 'Document');
                      }
                      setState(() => _wordConvertedPdfBytes = pdf);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PDF Converted Successfully!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Size: ${_formatSize(_wordConvertedPdfBytes!.lengthInBytes)}',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildActionExecuteButton(
            label: 'Download Converted PDF',
            icon: Icons.download_rounded,
            onTap: () async {
              final base = (_selectedFileName ?? _wordTitleCtrl.text).replaceAll(RegExp(r'\.(docx|doc|txt)$', caseSensitive: false), '');
              final outName = '$base.pdf';
              await saveAndDownloadFile(_wordConvertedPdfBytes!, outName);
              _recordRecentFile(outName, _wordConvertedPdfBytes!, true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('PDF downloaded successfully!'),
                  backgroundColor: AppColors.success,
                ));
              }
            },
          ),
        ],
      ],
    );
  }

  // 9. COMPRESS PDF
  Widget _buildCompressPdf(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF File' : 'Change PDF',
          onTap: () {
            setState(() => _compressedPdfResultBytes = null);
            _pickSingleFile(extensions: ['pdf']);
          },
        ),
        const SizedBox(height: 6),
        Text('or drag and drop files here', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Text(_selectedFileName ?? 'document.pdf', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          Text('Original Size: ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Compression Level:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Balanced', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  selected: _pdfCompressQuality == 2,
                  onSelected: (sel) => setState(() => _pdfCompressQuality = 2),
                  selectedColor: AppColors.cyanDeep.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Maximum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  selected: _pdfCompressQuality == 3,
                  onSelected: (sel) => setState(() => _pdfCompressQuality = 3),
                  selectedColor: Colors.purple.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('High Quality', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  selected: _pdfCompressQuality == 1,
                  onSelected: (sel) => setState(() => _pdfCompressQuality = 1),
                  selectedColor: Colors.blue.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Optimizing & compressing PDF pages...'),
              ],
            )
          else if (_compressedPdfResultBytes == null)
            _buildActionExecuteButton(
              label: 'Compress PDF Now',
              icon: Icons.bolt_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final compressed = await PdfToolsService.compressPdf(_selectedFileBytes!, qualityLevel: _pdfCompressQuality);
                  setState(() => _compressedPdfResultBytes = compressed);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            )
          else ...[
            Builder(
              builder: (context) {
                final orig = _selectedFileBytes!.lengthInBytes;
                final comp = _compressedPdfResultBytes!.lengthInBytes;
                final double savedPct = orig > 0 ? ((orig - comp) / orig * 100).clamp(0.0, 99.9) : 0.0;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compressed: ${_formatSize(comp)} (${savedPct.toStringAsFixed(1)}% saved!)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                            ),
                            Text(
                              'Original: ${_formatSize(orig)} • All pages & content intact',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildActionExecuteButton(
              label: 'Download Compressed PDF',
              icon: Icons.download_rounded,
              onTap: () async {
                final base = (_selectedFileName ?? 'doc').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                final outName = '${base}_compressed.pdf';
                await saveAndDownloadFile(_compressedPdfResultBytes!, outName);
                _recordRecentFile(outName, _compressedPdfResultBytes!, true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Compressed PDF downloaded!'),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
            ),
          ],
        ],
      ],
    );
  }

  // 10. IMAGE TO PDF
  Widget _buildImageToPdf(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: '+ Add Images',
          onTap: () async {
            final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
            if (res == null || res.files.isEmpty) return;
            for (final f in res.files) {
              Uint8List? b = f.bytes;
              if (b == null && !kIsWeb && f.path != null) b = await File(f.path!).readAsBytes();
              if (b != null) _imagesForPdf.add(b);
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 6),
        Text('select multiple images to bundle', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_imagesForPdf.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('${_imagesForPdf.length} images selected', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imagesForPdf.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_imagesForPdf[i], width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2, right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _imagesForPdf.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Page Fit:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor)),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Fit Image (Zero white space)'),
                  selected: _imagePdfPageFit == ImagePdfPageFit.fitImage,
                  onSelected: (val) {
                    if (val) setState(() => _imagePdfPageFit = ImagePdfPageFit.fitImage);
                  },
                ),
                ChoiceChip(
                  label: const Text('Standard A4'),
                  selected: _imagePdfPageFit == ImagePdfPageFit.a4,
                  onSelected: (val) {
                    if (val) setState(() => _imagePdfPageFit = ImagePdfPageFit.a4);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Margin / Border Space:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor)),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('No Margin (0mm)'),
                  selected: _imagePdfMargin == ImagePdfMargin.none,
                  onSelected: (val) {
                    if (val) setState(() => _imagePdfMargin = ImagePdfMargin.none);
                  },
                ),
                ChoiceChip(
                  label: const Text('Narrow (~2mm)'),
                  selected: _imagePdfMargin == ImagePdfMargin.narrow,
                  onSelected: (val) {
                    if (val) setState(() => _imagePdfMargin = ImagePdfMargin.narrow);
                  },
                ),
                ChoiceChip(
                  label: const Text('Normal (~6mm)'),
                  selected: _imagePdfMargin == ImagePdfMargin.standard,
                  onSelected: (val) {
                    if (val) setState(() => _imagePdfMargin = ImagePdfMargin.standard);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Convert ${_imagesForPdf.length} Images to PDF',
              icon: Icons.picture_as_pdf_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final pdf = await PdfToolsService.imagesToPdf(
                    _imagesForPdf,
                    marginOption: _imagePdfMargin,
                    pageFit: _imagePdfPageFit,
                  );
                  await saveAndDownloadFile(pdf, 'images_bundle.pdf');
                  _recordRecentFile('images_bundle.pdf', pdf, true);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
        ],
      ],
    );
  }

  Widget _buildScanToPdf(Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: 'Open camera and scan a page',
          onTap: () async {
            final photo = await ImagePicker().pickImage(
              source: ImageSource.camera,
              imageQuality: 92,
            );
            if (photo == null) return;
            final bytes = await photo.readAsBytes();
            if (!mounted) return;
            setState(() {
              _imagesForPdf
                ..clear()
                ..add(bytes);
              _selectedFileName = photo.name;
              _selectedFileSize = bytes.lengthInBytes;
            });
          },
        ),
        const SizedBox(height: 10),
        Text('Camera image stays on your device and is packaged into a PDF locally.', style: TextStyle(color: textMuted, fontSize: 12)),
        if (_imagesForPdf.isNotEmpty) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_imagesForPdf.first, height: 190, fit: BoxFit.contain),
          ),
          const SizedBox(height: 14),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Create and download scanned PDF',
              icon: Icons.picture_as_pdf_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final output = await PdfToolsService.imagesToPdf(
                    _imagesForPdf,
                    marginOption: ImagePdfMargin.none,
                    pageFit: ImagePdfPageFit.fitImage,
                  );
                  await saveAndDownloadFile(output, 'scanned_page.pdf');
                  _recordRecentFile('scanned_page.pdf', output, true);
                } catch (error) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create the scanned PDF: $error')));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
        ],
      ],
    );
  }

  // 11. DELETE PDF PAGES
  Widget _buildDeletePdfPages(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF File' : 'Change PDF',
          onTap: () => _pickSingleFile(extensions: ['pdf']),
        ),
        const SizedBox(height: 6),
        Text('or drag and drop files here', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null && _pdfTotalPages > 0) ...[
          const SizedBox(height: 18),
          Text('Tap pages to remove (turns red):', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_pdfTotalPages, (i) {
              final pNum = i + 1;
              final isDel = _pagesToDelete.contains(pNum);
              return FilterChip(
                label: Text('Page $pNum'),
                selected: isDel,
                selectedColor: Colors.red.withValues(alpha: 0.25),
                checkmarkColor: Colors.red,
                labelStyle: TextStyle(color: isDel ? Colors.red : textColor, fontWeight: isDel ? FontWeight.bold : FontWeight.normal),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _pagesToDelete.add(pNum);
                    } else {
                      _pagesToDelete.remove(pNum);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Delete ${_pagesToDelete.length} Pages & Download',
              icon: Icons.delete_sweep_rounded,
              onTap: _pagesToDelete.isEmpty ? null : () async {
                setState(() => _isProcessing = true);
                try {
                  final updated = await PdfToolsService.deletePdfPages(_selectedFileBytes!, _pagesToDelete.toList());
                  final base = (_selectedFileName ?? 'document').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                  final outName = '${base}_updated.pdf';
                  await saveAndDownloadFile(updated, outName);
                  _recordRecentFile(outName, updated, true);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
        ],
      ],
    );
  }

  // 12. ORGANIZE PDF
  Widget _buildOrganizePdf(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF File' : 'Change PDF',
          onTap: () => _pickSingleFile(extensions: ['pdf']),
        ),
        const SizedBox(height: 6),
        Text('or drag and drop files here', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null && _pageOrder.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Drag to change page sequence:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pageOrder.length,
            // ignore: deprecated_member_use
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = _pageOrder.removeAt(oldIdx);
                _pageOrder.insert(newIdx, item);
              });
            },
            itemBuilder: (ctx, i) => Container(
              key: ValueKey('page_${_pageOrder[i]}_$i'),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF24293D) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text('Page ${_pageOrder[i]}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  const Spacer(),
                  Text('Position #${i + 1}', style: TextStyle(fontSize: 12, color: textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Save & Download Reordered PDF',
              icon: Icons.download_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final reordered = await PdfToolsService.reorderPdfPages(_selectedFileBytes!, _pageOrder);
                  final base = (_selectedFileName ?? 'reordered').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                  final outName = '${base}_reorganized.pdf';
                  await saveAndDownloadFile(reordered, outName);
                  _recordRecentFile(outName, reordered, true);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
            ),
        ],
      ],
    );
  }

  Widget _buildDefaultFilePicker(String label) {
    return _buildPrimarySelectButton(
      label: label,
      onTap: () => _pickSingleFile(),
    );
  }

  // ── Primary Big Action Button (Matching Screenshot 2) ────────
  Widget _buildPrimarySelectButton({required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7DD3FC),
          foregroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Action Execution Button (Convert / Download) ──────────────
  Widget _buildActionExecuteButton({required String label, required IconData icon, required VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _presetChip(String label, String value, String current, Function(String) onSel) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      selectedColor: const Color(0xFF38BDF8).withValues(alpha: 0.25),
      onSelected: (_) => onSel(value),
    );
  }
}

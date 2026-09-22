// lib/features/tools/tool_workspace_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'services/pdf_tools_service.dart';
import 'services/image_tools_service.dart';
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

  // PDF Watermark state
  String _pdfWatermarkPreset = 'center';
  int _pdfTotalPages = 0;

  // Word to PDF state
  final TextEditingController _wordTitleCtrl = TextEditingController(text: 'CampusSetu Document');
  final TextEditingController _wordTextCtrl = TextEditingController();

  // Image to PDF state
  final List<Uint8List> _imagesForPdf = [];

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
      _pdfToWordResult = null;
      _pagesToDelete.clear();

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
      case 'image_watermark':
        return _buildImageWatermark(isDark, textColor, textMuted);
      case 'qr_generator':
        return _buildQrGenerator(isDark, textColor, textMuted);
      case 'barcode_generator':
        return _buildBarcodeGenerator(isDark, textColor, textMuted);
      case 'pdf_to_word':
        return _buildPdfToWord(isDark, textColor, textMuted);
      case 'pdf_watermark':
        return _buildPdfWatermark(isDark, textColor, textMuted);
      case 'word_to_pdf':
        return _buildWordToPdf(isDark, textColor, textMuted);
      case 'compress_pdf':
        return _buildCompressPdf(isDark, textColor, textMuted);
      case 'image_to_pdf':
        return _buildImageToPdf(isDark, textColor, textMuted);
      case 'delete_pages':
        return _buildDeletePdfPages(isDark, textColor, textMuted);
      case 'organize_pdf':
        return _buildOrganizePdf(isDark, textColor, textMuted);
      default:
        return _buildDefaultFilePicker('+ Select File');
    }
  }

  // 1. IMAGE CONVERTER
  Widget _buildImageConverter(bool isDark, Color textColor, Color textMuted) {
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
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_selectedFileBytes!, width: 70, height: 70, fit: BoxFit.cover),
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
            children: ['png', 'jpg', 'webp', 'bmp', 'gif'].map((fmt) {
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
        Text('or drag and drop files here', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Text(_selectedFileName ?? 'document.pdf', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          Text('$_pdfTotalPages page(s) • ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
          const SizedBox(height: 18),
          if (_isProcessing)
            const CircularProgressIndicator()
          else if (_pdfToWordResult == null)
            _buildActionExecuteButton(
              label: 'Extract Text & Convert to Word',
              icon: Icons.bolt_rounded,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Extracted ${_pdfToWordResult!.pageCount} pages (${_pdfToWordResult!.text.length} characters)',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
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
              },
            ),
          ],
        ],
      ],
    );
  }

  // 7. PDF WATERMARK REMOVER
  Widget _buildPdfWatermark(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF File' : 'Change PDF',
          onTap: () => _pickSingleFile(extensions: ['pdf']),
        ),
        const SizedBox(height: 6),
        Text('or drag and drop files here', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Watermark Location:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _presetChip('Center Diagonal', 'center', _pdfWatermarkPreset, (v) => setState(() => _pdfWatermarkPreset = v)),
              _presetChip('Header Area', 'header', _pdfWatermarkPreset, (v) => setState(() => _pdfWatermarkPreset = v)),
              _presetChip('Footer Area', 'footer', _pdfWatermarkPreset, (v) => setState(() => _pdfWatermarkPreset = v)),
            ],
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Clean Watermark & Download PDF',
              icon: Icons.cleaning_services_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                Rect area;
                switch (_pdfWatermarkPreset) {
                  case 'header': area = const Rect.fromLTWH(0.05, 0.02, 0.90, 0.12); break;
                  case 'footer': area = const Rect.fromLTWH(0.05, 0.88, 0.90, 0.10); break;
                  default: area = const Rect.fromLTWH(0.15, 0.35, 0.70, 0.30); break;
                }
                try {
                  final cleaned = await PdfToolsService.removePdfWatermark(_selectedFileBytes!, relativeArea: area);
                  final base = (_selectedFileName ?? 'document').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                  final outName = '${base}_clean.pdf';
                  await saveAndDownloadFile(cleaned, outName);
                  _recordRecentFile(outName, cleaned, true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleaned PDF downloaded!'), backgroundColor: AppColors.success));
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

  // 8. WORD TO PDF
  Widget _buildWordToPdf(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
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
        const SizedBox(height: 18),
        if (_isProcessing)
          const CircularProgressIndicator()
        else
          _buildActionExecuteButton(
            label: 'Generate & Download PDF',
            icon: Icons.picture_as_pdf_rounded,
            onTap: () async {
              if (_wordTextCtrl.text.trim().isEmpty) return;
              setState(() => _isProcessing = true);
              try {
                final pdf = await PdfToolsService.wordToPdf(_wordTextCtrl.text.trim(), title: _wordTitleCtrl.text.trim());
                final outName = '${_wordTitleCtrl.text.replaceAll(' ', '_')}.pdf';
                await saveAndDownloadFile(pdf, outName);
                _recordRecentFile(outName, pdf, true);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
          ),
      ],
    );
  }

  // 9. COMPRESS PDF
  Widget _buildCompressPdf(bool isDark, Color textColor, Color textMuted) {
    return Column(
      children: [
        _buildPrimarySelectButton(
          label: _selectedFileName == null ? '+ Select PDF File' : 'Change PDF',
          onTap: () => _pickSingleFile(extensions: ['pdf']),
        ),
        const SizedBox(height: 6),
        Text('or drag and drop files here', style: TextStyle(fontSize: 12, color: textMuted)),
        if (_selectedFileBytes != null) ...[
          const SizedBox(height: 20),
          Text(_selectedFileName ?? 'document.pdf', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          Text('Original Size: ${_formatSize(_selectedFileSize)}', style: TextStyle(fontSize: 12, color: textMuted)),
          const SizedBox(height: 20),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            _buildActionExecuteButton(
              label: 'Compress & Download PDF',
              icon: Icons.bolt_rounded,
              onTap: () async {
                setState(() => _isProcessing = true);
                try {
                  final compressed = await PdfToolsService.compressPdf(_selectedFileBytes!);
                  final base = (_selectedFileName ?? 'doc').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                  final outName = '${base}_compressed.pdf';
                  await saveAndDownloadFile(compressed, outName);
                  _recordRecentFile(outName, compressed, true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Compressed to ${_formatSize(compressed.lengthInBytes)}!'),
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
                  final pdf = await PdfToolsService.imagesToPdf(_imagesForPdf);
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

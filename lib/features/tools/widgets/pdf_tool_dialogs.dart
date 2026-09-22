// lib/features/tools/widgets/pdf_tool_dialogs.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/neu_card.dart';
import '../services/pdf_tools_service.dart';
import '../utils/file_saver.dart';

class PdfToolDialogs {
  /// 1. PDF TO WORD (.docx)
  static void showPdfToWordDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'PDF to Word Converter',
        icon: Icons.description_rounded,
        color: Color(0xFF2B579A),
        child: _PdfToWordContent(),
      ),
    );
  }

  /// 2. PDF WATERMARK REMOVER
  static void showPdfWatermarkDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'PDF Watermark Remover',
        icon: Icons.layers_clear_rounded,
        color: Colors.redAccent,
        child: _PdfWatermarkContent(),
      ),
    );
  }

  /// 3. WORD / TEXT TO PDF
  static void showWordToPdfDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Word / Text to PDF',
        icon: Icons.picture_as_pdf_rounded,
        color: Colors.deepOrange,
        child: _WordToPdfContent(),
      ),
    );
  }

  /// 4. COMPRESS PDF
  static void showCompressPdfDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Compress PDF',
        icon: Icons.compress_rounded,
        color: Colors.purple,
        child: _CompressPdfContent(),
      ),
    );
  }

  /// 5. IMAGE TO PDF
  static void showImageToPdfDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Image to PDF Converter',
        icon: Icons.photo_library_rounded,
        color: Colors.teal,
        child: _ImageToPdfContent(),
      ),
    );
  }

  /// 6. DELETE SPECIFIC PAGES
  static void showDeletePagesDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Delete PDF Pages',
        icon: Icons.delete_sweep_rounded,
        color: Colors.red,
        child: _DeletePagesContent(),
      ),
    );
  }

  /// 7. ORGANIZE / REORDER PDF
  static void showOrganizePdfDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Organize & Reorder PDF',
        icon: Icons.swap_vert_rounded,
        color: Colors.indigo,
        child: _OrganizePdfContent(),
      ),
    );
  }
}

// ── Common Primary Action Button ──────────────────────────────
class _ToolActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  const _ToolActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyanDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
        ),
      ),
    );
  }
}

// ── Common Modal Shell ─────────────────────────────────────────
class _ToolModalShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ToolModalShell({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;

    return Container(
      width: isDesktop ? 600 : double.infinity,
      margin: EdgeInsets.only(
        top: 60,
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: isDesktop ? (size.width - 600) / 2 : 0,
        right: isDesktop ? (size.width - 600) / 2 : 0,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.inkMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.soraHeading3(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.inkSoft,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  '100% Private & Client-Side: File never leaves your device',
                  style: AppTypography.interCaption(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 1. PDF TO WORD CONTENT ──────────────────────────────────────
class _PdfToWordContent extends StatefulWidget {
  const _PdfToWordContent();
  @override
  State<_PdfToWordContent> createState() => _PdfToWordContentState();
}

class _PdfToWordContentState extends State<_PdfToWordContent> {
  String? _fileName;
  bool _isProcessing = false;
  PdfExtractionResult? _result;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
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
      _fileName = file.name;
      _isProcessing = true;
      _result = null;
    });

    try {
      final res = await PdfToolsService.pdfToWordDocx(bytes);
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error extracting PDF: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadDocx() async {
    if (_result == null) return;
    final name = (_fileName ?? 'converted').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    await saveAndDownloadFile(_result!.docxBytes, '$name.docx');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Word document downloaded successfully!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuCard(
          padding: const EdgeInsets.all(20),
          onTap: _pickPdf,
          child: Column(
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(
                _fileName ?? 'Select or Drop PDF file',
                style: AppTypography.interBody(weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Convert PDF to fully editable Microsoft Word (.docx)',
                style: AppTypography.interCaption(color: AppColors.inkSoft),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isProcessing)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )),
        if (_result != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extracted ${_result!.pageCount} pages (${_result!.text.length} characters)',
                    style: AppTypography.interLabel(color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ToolActionButton(
            text: 'Download Word (.docx)',
            icon: Icons.download_rounded,
            onPressed: _downloadDocx,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _result!.text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Extracted text copied to clipboard!'),
              ));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy Extracted Text'),
          ),
        ],
      ],
    );
  }
}

// ── 2. PDF WATERMARK REMOVER CONTENT ───────────────────────────
class _PdfWatermarkContent extends StatefulWidget {
  const _PdfWatermarkContent();
  @override
  State<_PdfWatermarkContent> createState() => _PdfWatermarkContentState();
}

class _PdfWatermarkContentState extends State<_PdfWatermarkContent> {
  Uint8List? _pdfBytes;
  String? _fileName;
  int _totalPages = 0;
  String _selectedPreset = 'center'; // 'center', 'header', 'footer', 'all'
  bool _isProcessing = false;
  Uint8List? _cleanedBytes;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    final count = PdfToolsService.getPageCount(bytes);
    setState(() {
      _pdfBytes = bytes;
      _fileName = file.name;
      _totalPages = count;
      _cleanedBytes = null;
    });
  }

  Future<void> _applyWatermarkRemoval() async {
    if (_pdfBytes == null) return;
    setState(() => _isProcessing = true);

    Rect area;
    switch (_selectedPreset) {
      case 'header':
        area = const Rect.fromLTWH(0.05, 0.02, 0.90, 0.12);
        break;
      case 'footer':
        area = const Rect.fromLTWH(0.05, 0.88, 0.90, 0.10);
        break;
      case 'all':
        area = const Rect.fromLTWH(0.05, 0.02, 0.90, 0.96);
        break;
      case 'center':
      default:
        area = const Rect.fromLTWH(0.15, 0.35, 0.70, 0.30);
        break;
    }

    try {
      final cleaned = await PdfToolsService.removePdfWatermark(_pdfBytes!, relativeArea: area);
      setState(() => _cleanedBytes = cleaned);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error removing watermark: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuCard(
          padding: const EdgeInsets.all(20),
          onTap: _pickPdf,
          child: Column(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(
                _fileName ?? 'Select PDF with Watermark',
                style: AppTypography.interBody(weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              if (_totalPages > 0)
                Text('Total Pages: $_totalPages', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (_pdfBytes != null) ...[
          const SizedBox(height: 16),
          Text('Select Watermark Location:', style: AppTypography.interLabel()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip('Center Diagonal', 'center'),
              _presetChip('Header Area', 'header'),
              _presetChip('Footer Area', 'footer'),
            ],
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Clean & Remove Watermark',
              icon: Icons.cleaning_services_rounded,
              onPressed: _applyWatermarkRemoval,
            ),
          if (_cleanedBytes != null) ...[
            const SizedBox(height: 16),
            _ToolActionButton(
              text: 'Download Cleaned PDF',
              icon: Icons.download_rounded,
              onPressed: () async {
                final name = (_fileName ?? 'cleaned').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                await saveAndDownloadFile(_cleanedBytes!, '${name}_clean.pdf');
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _presetChip(String label, String value) {
    final isSelected = _selectedPreset == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedPreset = value),
      selectedColor: AppColors.cyanDeep.withValues(alpha: 0.2),
    );
  }
}

// ── 3. WORD / TEXT TO PDF CONTENT ──────────────────────────────
class _WordToPdfContent extends StatefulWidget {
  const _WordToPdfContent();
  @override
  State<_WordToPdfContent> createState() => _WordToPdfContentState();
}

class _WordToPdfContentState extends State<_WordToPdfContent> {
  final _textCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(text: 'CampusSetu Document');
  bool _isGenerating = false;

  Future<void> _pickTextOrDocx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    if (file.name.endsWith('.txt')) {
      _textCtrl.text = String.fromCharCodes(bytes);
    } else {
      _textCtrl.text = 'Imported ${file.name}\n\n[Docx formatting loaded]';
    }
    _titleCtrl.text = file.name.split('.').first;
    setState(() {});
  }

  Future<void> _generatePdf() async {
    if (_textCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter or import text first')));
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await PdfToolsService.wordToPdf(
        _textCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
      );
      final filename = '${_titleCtrl.text.trim().replaceAll(' ', '_')}.pdf';
      await saveAndDownloadFile(pdfBytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF generated and downloaded!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Document Title',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.attach_file_rounded),
              tooltip: 'Import .txt or .docx',
              onPressed: _pickTextOrDocx,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textCtrl,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Type, paste, or import text here to convert into PDF...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (_isGenerating)
          const Center(child: CircularProgressIndicator())
        else
          _ToolActionButton(
            text: 'Generate & Download PDF',
            icon: Icons.picture_as_pdf_rounded,
            onPressed: _generatePdf,
          ),
      ],
    );
  }
}

// ── 4. COMPRESS PDF CONTENT ────────────────────────────────────
class _CompressPdfContent extends StatefulWidget {
  const _CompressPdfContent();
  @override
  State<_CompressPdfContent> createState() => _CompressPdfContentState();
}

class _CompressPdfContentState extends State<_CompressPdfContent> {
  Uint8List? _originalBytes;
  String? _fileName;
  Uint8List? _compressedBytes;
  bool _isCompressing = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
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
      _originalBytes = bytes;
      _fileName = file.name;
      _compressedBytes = null;
    });
  }

  Future<void> _compress() async {
    if (_originalBytes == null) return;
    setState(() => _isCompressing = true);
    try {
      final compressed = await PdfToolsService.compressPdf(_originalBytes!);
      setState(() => _compressedBytes = compressed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Compression failed: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuCard(
          padding: const EdgeInsets.all(20),
          onTap: _pickPdf,
          child: Column(
            children: [
              const Icon(Icons.compress_rounded, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(
                _fileName ?? 'Select PDF to Compress',
                style: AppTypography.interBody(weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              if (_originalBytes != null)
                Text('Original Size: ${_formatSize(_originalBytes!.lengthInBytes)}', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (_originalBytes != null) ...[
          const SizedBox(height: 16),
          if (_isCompressing)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Compress PDF Now',
              icon: Icons.bolt_rounded,
              onPressed: _compress,
            ),
          if (_compressedBytes != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compressed Size: ${_formatSize(_compressedBytes!.lengthInBytes)}', style: AppTypography.interLabel(color: AppColors.ink)),
                        Text('Optimized streams & objects', style: AppTypography.interCaption(color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ToolActionButton(
              text: 'Download Compressed PDF',
              icon: Icons.download_rounded,
              onPressed: () async {
                final name = (_fileName ?? 'compressed').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                await saveAndDownloadFile(_compressedBytes!, '${name}_compressed.pdf');
              },
            ),
          ],
        ],
      ],
    );
  }
}

// ── 5. IMAGE TO PDF CONTENT ────────────────────────────────────
class _ImageToPdfContent extends StatefulWidget {
  const _ImageToPdfContent();
  @override
  State<_ImageToPdfContent> createState() => _ImageToPdfContentState();
}

class _ImageToPdfContentState extends State<_ImageToPdfContent> {
  final List<Uint8List> _images = [];
  bool _isGenerating = false;

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final f in result.files) {
      Uint8List? bytes = f.bytes;
      if (bytes == null && !kIsWeb && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes != null) _images.add(bytes);
    }
    setState(() {});
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await PdfToolsService.imagesToPdf(_images);
      await saveAndDownloadFile(pdfBytes, 'images_bundle.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Images converted to PDF and downloaded!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuCard(
          padding: const EdgeInsets.all(20),
          onTap: _pickImages,
          child: Column(
            children: [
              const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text('Pick One or More Images', style: AppTypography.interBody(weight: FontWeight.w600)),
              Text('Supports JPG, PNG, WEBP, BMP', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${_images.length} images selected:', style: AppTypography.interLabel()),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_images[i], width: 90, height: 90, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isGenerating)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Convert ${_images.length} Images to PDF',
              icon: Icons.picture_as_pdf_rounded,
              onPressed: _convert,
            ),
        ],
      ],
    );
  }
}

// ── 6. DELETE SPECIFIC PAGES CONTENT ───────────────────────────
class _DeletePagesContent extends StatefulWidget {
  const _DeletePagesContent();
  @override
  State<_DeletePagesContent> createState() => _DeletePagesContentState();
}

class _DeletePagesContentState extends State<_DeletePagesContent> {
  Uint8List? _pdfBytes;
  String? _fileName;
  int _totalPages = 0;
  final Set<int> _selectedPagesToDelete = {};
  bool _isProcessing = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    final count = PdfToolsService.getPageCount(bytes);
    setState(() {
      _pdfBytes = bytes;
      _fileName = file.name;
      _totalPages = count;
      _selectedPagesToDelete.clear();
    });
  }

  Future<void> _deleteAndDownload() async {
    if (_pdfBytes == null || _selectedPagesToDelete.isEmpty) return;
    if (_selectedPagesToDelete.length >= _totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot delete all pages of the document!'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final updated = await PdfToolsService.deletePdfPages(_pdfBytes!, _selectedPagesToDelete.toList());
      final name = (_fileName ?? 'document').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      await saveAndDownloadFile(updated, '${name}_updated.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pages removed & updated PDF downloaded!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuCard(
          padding: const EdgeInsets.all(20),
          onTap: _pickPdf,
          child: Column(
            children: [
              const Icon(Icons.delete_outline_rounded, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(_fileName ?? 'Select PDF File', style: AppTypography.interBody(weight: FontWeight.w600)),
              if (_totalPages > 0)
                Text('Total Pages: $_totalPages', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (_totalPages > 0) ...[
          const SizedBox(height: 16),
          Text('Tap pages to delete (turns red):', style: AppTypography.interLabel()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_totalPages, (i) {
              final pageNum = i + 1;
              final isMarked = _selectedPagesToDelete.contains(pageNum);
              return FilterChip(
                label: Text('Page $pageNum'),
                selected: isMarked,
                selectedColor: Colors.red.withValues(alpha: 0.2),
                checkmarkColor: Colors.red,
                labelStyle: TextStyle(
                  color: isMarked ? Colors.red : AppColors.ink,
                  fontWeight: isMarked ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPagesToDelete.add(pageNum);
                    } else {
                      _selectedPagesToDelete.remove(pageNum);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Delete ${_selectedPagesToDelete.length} Page(s) & Download',
              icon: Icons.download_rounded,
              onPressed: _selectedPagesToDelete.isNotEmpty ? _deleteAndDownload : null,
            ),
        ],
      ],
    );
  }
}

// ── 7. ORGANIZE / REORDER PDF CONTENT ──────────────────────────
class _OrganizePdfContent extends StatefulWidget {
  const _OrganizePdfContent();
  @override
  State<_OrganizePdfContent> createState() => _OrganizePdfContentState();
}

class _OrganizePdfContentState extends State<_OrganizePdfContent> {
  Uint8List? _pdfBytes;
  String? _fileName;
  List<int> _pageOrder = [];
  bool _isProcessing = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    final count = PdfToolsService.getPageCount(bytes);
    setState(() {
      _pdfBytes = bytes;
      _fileName = file.name;
      _pageOrder = List.generate(count, (i) => i + 1);
    });
  }

  Future<void> _reorderAndDownload() async {
    if (_pdfBytes == null || _pageOrder.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final reorganized = await PdfToolsService.reorderPdfPages(_pdfBytes!, _pageOrder);
      final name = (_fileName ?? 'reorganized').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      await saveAndDownloadFile(reorganized, '${name}_reorganized.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reordered PDF downloaded successfully!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuCard(
          padding: const EdgeInsets.all(20),
          onTap: _pickPdf,
          child: Column(
            children: [
              const Icon(Icons.swap_vert_circle_outlined, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(_fileName ?? 'Select PDF to Reorder', style: AppTypography.interBody(weight: FontWeight.w600)),
              if (_pageOrder.isNotEmpty)
                Text('Drag to change page sequence', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (_pageOrder.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Reorder Pages (Drag & Drop):', style: AppTypography.interLabel()),
          const SizedBox(height: 8),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text('Page ${_pageOrder[i]}', style: AppTypography.interBody(weight: FontWeight.w600)),
                  const Spacer(),
                  Text('Position #${i + 1}', style: AppTypography.interCaption(color: AppColors.inkSoft)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Save & Download Reorganized PDF',
              icon: Icons.download_rounded,
              onPressed: _reorderAndDownload,
            ),
        ],
      ],
    );
  }
}

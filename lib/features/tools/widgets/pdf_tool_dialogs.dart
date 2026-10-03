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

  /// 2. ADD A TEXT WATERMARK
  static void showPdfWatermarkDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Add PDF Watermark',
        icon: Icons.branding_watermark_rounded,
        color: Colors.blueAccent,
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
  Uint8List? _pdfBytes;
  int _totalPages = 0;
  int _fileSize = 0;
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

    final count = PdfToolsService.getPageCount(bytes);
    setState(() {
      _fileName = file.name;
      _pdfBytes = bytes;
      _totalPages = count;
      _fileSize = bytes!.lengthInBytes;
      _isProcessing = false;
      _result = null;
    });
  }

  Future<void> _convertToWord() async {
    if (_pdfBytes == null) return;
    setState(() => _isProcessing = true);
    try {
      final res = await PdfToolsService.pdfToWordDocx(_pdfBytes!);
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error converting PDF to Word: $e'),
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
        content: Text('Word document (.docx) downloaded successfully!'),
        backgroundColor: AppColors.success,
      ));
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
              const Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(
                _fileName ?? 'Select or Drop PDF file',
                style: AppTypography.interBody(weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _pdfBytes != null
                    ? '$_totalPages page(s) • ${_formatSize(_fileSize)}'
                    : 'Convert PDF document into editable Microsoft Word (.docx)',
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
          ))
        else if (_pdfBytes != null && _result == null) ...[
          _ToolActionButton(
            text: 'Convert to Word (.docx)',
            icon: Icons.transform_rounded,
            onPressed: _convertToWord,
          ),
        ] else if (_result != null) ...[
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
                      Text(
                        'Conversion Complete!',
                        style: AppTypography.interLabel(color: Colors.blue.shade900),
                      ),
                      Text(
                        'Your Word document (.docx) with ${_result!.pageCount} page(s) is ready',
                        style: AppTypography.interCaption(color: AppColors.inkSoft),
                      ),
                    ],
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
        ],
      ],
    );
  }
}

// ── 2. ADD PDF WATERMARK CONTENT ───────────────────────────────
class _PdfWatermarkContent extends StatefulWidget {
  const _PdfWatermarkContent();
  @override
  State<_PdfWatermarkContent> createState() => _PdfWatermarkContentState();
}

class _PdfWatermarkContentState extends State<_PdfWatermarkContent> {
  Uint8List? _pdfBytes;
  String? _fileName;
  int _totalPages = 0;
  final TextEditingController _watermarkCtrl = TextEditingController(text: 'CONFIDENTIAL');
  WatermarkStyle _selectedStyle = WatermarkStyle.centerDiagonal;
  Color _selectedColor = const Color(0xFF6B7280);
  double _opacity = 0.22;
  bool _isProcessing = false;
  Uint8List? _watermarkedBytes;

  @override
  void dispose() {
    _watermarkCtrl.dispose();
    super.dispose();
  }

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
      _watermarkedBytes = null;
    });
  }

  Future<void> _applyWatermark() async {
    if (_pdfBytes == null || _watermarkCtrl.text.trim().isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final watermarked = await PdfToolsService.addPdfWatermark(
        _pdfBytes!,
        watermark: _watermarkCtrl.text.trim(),
        style: _selectedStyle,
        opacity: _opacity,
        color: _selectedColor,
      );
      setState(() => _watermarkedBytes = watermarked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not add the watermark: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _pdfBytes != null && _watermarkCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. PDF File Selector Card (Can be selected first or after text)
        NeuCard(
          padding: const EdgeInsets.all(20),
          onTap: _pickPdf,
          child: Column(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(
                _fileName ?? 'Select or Drop PDF file',
                style: AppTypography.interBody(weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _pdfBytes != null
                    ? '$_totalPages page(s) ready for watermark'
                    : 'Tap to select PDF (or type text below first)',
                style: AppTypography.interCaption(color: AppColors.inkSoft),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Watermark Text Input (Always available!)
        TextField(
          controller: _watermarkCtrl,
          maxLength: 60,
          onChanged: (_) => setState(() {
            _watermarkedBytes = null;
          }),
          decoration: InputDecoration(
            labelText: 'Watermark Text',
            hintText: 'e.g. CONFIDENTIAL, DRAFT, DO NOT COPY',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
            prefixIcon: const Icon(Icons.branding_watermark_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Watermark Placement Style Selector
        Text('Watermark Style & Direction:', style: AppTypography.interLabel()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Center Diagonal (Cross)'),
              avatar: const Icon(Icons.trending_up_rounded, size: 16),
              selected: _selectedStyle == WatermarkStyle.centerDiagonal,
              onSelected: (val) {
                if (val) setState(() { _selectedStyle = WatermarkStyle.centerDiagonal; _watermarkedBytes = null; });
              },
            ),
            ChoiceChip(
              label: const Text('Repeated Pattern (Corner to Corner)'),
              avatar: const Icon(Icons.grid_4x4_rounded, size: 16),
              selected: _selectedStyle == WatermarkStyle.tiledDiagonal,
              onSelected: (val) {
                if (val) setState(() { _selectedStyle = WatermarkStyle.tiledDiagonal; _watermarkedBytes = null; });
              },
            ),
            ChoiceChip(
              label: const Text('Center Horizontal'),
              avatar: const Icon(Icons.horizontal_rule_rounded, size: 16),
              selected: _selectedStyle == WatermarkStyle.centerHorizontal,
              onSelected: (val) {
                if (val) setState(() { _selectedStyle = WatermarkStyle.centerHorizontal; _watermarkedBytes = null; });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4. Color & Opacity
        Row(
          children: [
            Text('Color: ', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() { _selectedColor = const Color(0xFF6B7280); _watermarkedBytes = null; }),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF6B7280),
                child: _selectedColor == const Color(0xFF6B7280) ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() { _selectedColor = const Color(0xFFEF4444); _watermarkedBytes = null; }),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFEF4444),
                child: _selectedColor == const Color(0xFFEF4444) ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() { _selectedColor = const Color(0xFF3B82F6); _watermarkedBytes = null; }),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF3B82F6),
                child: _selectedColor == const Color(0xFF3B82F6) ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            const Spacer(),
            Text('Intensity: ', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            DropdownButton<double>(
              value: _opacity,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 0.15, child: Text('Light (15%)')),
                DropdownMenuItem(value: 0.22, child: Text('Standard (22%)')),
                DropdownMenuItem(value: 0.38, child: Text('Bold (38%)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() { _opacity = val; _watermarkedBytes = null; });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isProcessing)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ))
        else if (_watermarkedBytes == null)
          _ToolActionButton(
            text: canApply
                ? 'Apply Watermark to PDF'
                : (_pdfBytes == null ? 'Select PDF to Continue' : 'Enter Watermark Text'),
            icon: Icons.branding_watermark_rounded,
            onPressed: canApply ? _applyWatermark : null,
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
                      Text(
                        'Watermark Applied Successfully!',
                        style: AppTypography.interLabel(color: Colors.green.shade900),
                      ),
                      Text(
                        'Styled on all $_totalPages page(s)',
                        style: AppTypography.interCaption(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ToolActionButton(
            text: 'Download Watermarked PDF',
            icon: Icons.download_rounded,
            onPressed: () async {
              final name = (_fileName ?? 'document').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
              await saveAndDownloadFile(_watermarkedBytes!, '${name}_watermarked.pdf');
            },
          ),
        ],
      ],
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
  Uint8List? _wordBytes;
  String? _fileName;
  int _fileSize = 0;
  final _textCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(text: 'CampusSetu Document');
  bool _isDirectTextMode = false;
  bool _isGenerating = false;
  Uint8List? _generatedPdfBytes;

  Future<void> _pickWordFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'doc', 'txt'],
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
      _wordBytes = bytes;
      _fileName = file.name;
      _fileSize = bytes!.lengthInBytes;
      _generatedPdfBytes = null;
      _isDirectTextMode = false;
    });
  }

  Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);
    try {
      Uint8List pdfBytes;
      if (_isDirectTextMode || _wordBytes == null) {
        if (_textCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter text first')));
          return;
        }
        pdfBytes = await PdfToolsService.wordToPdf(_textCtrl.text.trim(), title: _titleCtrl.text.trim());
      } else {
        pdfBytes = await PdfToolsService.docxToPdf(_wordBytes!, title: _fileName?.split('.').first ?? 'Document');
      }

      setState(() => _generatedPdfBytes = pdfBytes);
      final filename = '${(_fileName ?? _titleCtrl.text).replaceAll(RegExp(r'\.(docx|doc|txt)$', caseSensitive: false), '')}.pdf';
      await saveAndDownloadFile(pdfBytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF converted and downloaded successfully!'),
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
        // Mode Selector: Word File vs Type Text
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.description_rounded, size: 18),
                label: const Text('Upload Word File'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: !_isDirectTextMode ? AppColors.cyanDeep.withValues(alpha: 0.1) : null,
                  side: BorderSide(color: !_isDirectTextMode ? AppColors.cyanDeep : Colors.grey.shade300),
                ),
                onPressed: () => setState(() => _isDirectTextMode = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Type Text Directly'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _isDirectTextMode ? AppColors.cyanDeep.withValues(alpha: 0.1) : null,
                  side: BorderSide(color: _isDirectTextMode ? AppColors.cyanDeep : Colors.grey.shade300),
                ),
                onPressed: () => setState(() => _isDirectTextMode = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (!_isDirectTextMode) ...[
          NeuCard(
            padding: const EdgeInsets.all(20),
            onTap: _pickWordFile,
            child: Column(
              children: [
                const Icon(Icons.file_present_rounded, size: 40, color: AppColors.cyanDeep),
                const SizedBox(height: 8),
                Text(
                  _fileName ?? 'Select Microsoft Word (.docx, .doc)',
                  style: AppTypography.interBody(weight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _wordBytes != null
                      ? 'Size: ${_formatSize(_fileSize)} • Ready to convert'
                      : 'Convert Word document into standard PDF',
                  style: AppTypography.interCaption(color: AppColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Document Title',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl,
            maxLines: 7,
            decoration: const InputDecoration(
              hintText: 'Type, paste, or write text here to convert into PDF...',
              border: OutlineInputBorder(),
            ),
          ),
        ],

        const SizedBox(height: 16),
        if (_isGenerating)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ))
        else
          _ToolActionButton(
            text: _isDirectTextMode ? 'Convert Text to PDF' : 'Convert Word to PDF',
            icon: Icons.picture_as_pdf_rounded,
            onPressed: (!_isDirectTextMode && _wordBytes == null) ? null : _generatePdf,
          ),

        if (_generatedPdfBytes != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('PDF converted and saved to your device!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
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
  ImagePdfMargin _margin = ImagePdfMargin.none;
  ImagePdfPageFit _pageFit = ImagePdfPageFit.fitImage;

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
      final pdfBytes = await PdfToolsService.imagesToPdf(
        _images,
        marginOption: _margin,
        pageFit: _pageFit,
      );
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
          const SizedBox(height: 14),
          Text('Page Fit:', style: AppTypography.interLabel()),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Fit Image (Zero white space)'),
                selected: _pageFit == ImagePdfPageFit.fitImage,
                onSelected: (val) {
                  if (val) setState(() => _pageFit = ImagePdfPageFit.fitImage);
                },
              ),
              ChoiceChip(
                label: const Text('Standard A4'),
                selected: _pageFit == ImagePdfPageFit.a4,
                onSelected: (val) {
                  if (val) setState(() => _pageFit = ImagePdfPageFit.a4);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Margin / Border Space:', style: AppTypography.interLabel()),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('No Margin (0mm)'),
                selected: _margin == ImagePdfMargin.none,
                onSelected: (val) {
                  if (val) setState(() => _margin = ImagePdfMargin.none);
                },
              ),
              ChoiceChip(
                label: const Text('Narrow (~2mm)'),
                selected: _margin == ImagePdfMargin.narrow,
                onSelected: (val) {
                  if (val) setState(() => _margin = ImagePdfMargin.narrow);
                },
              ),
              ChoiceChip(
                label: const Text('Normal (~6mm)'),
                selected: _margin == ImagePdfMargin.standard,
                onSelected: (val) {
                  if (val) setState(() => _margin = ImagePdfMargin.standard);
                },
              ),
            ],
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

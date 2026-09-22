// lib/features/tools/widgets/image_tool_dialogs.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/neu_card.dart';
import '../services/image_tools_service.dart';
import '../utils/file_saver.dart';

class ImageToolDialogs {
  /// 1. IMAGE CONVERTER
  static void showImageConverterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Image Format Converter',
        icon: Icons.transform_rounded,
        color: Colors.blueAccent,
        child: _ImageConverterContent(),
      ),
    );
  }

  /// 2. COMPRESS IMAGE
  static void showCompressImageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Compress Image',
        icon: Icons.photo_size_select_small_rounded,
        color: Colors.orange,
        child: _CompressImageContent(),
      ),
    );
  }

  /// 3. WATERMARK REMOVER
  static void showWatermarkRemoverDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Image Watermark Eraser',
        icon: Icons.auto_fix_high_rounded,
        color: Colors.pinkAccent,
        child: _WatermarkRemoverContent(),
      ),
    );
  }

  /// 4. QR GENERATOR
  static void showQrGeneratorDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'QR Code Generator',
        icon: Icons.qr_code_2_rounded,
        color: Color(0xFF6C63FF),
        child: _QrGeneratorContent(),
      ),
    );
  }

  /// 5. BARCODE GENERATOR
  static void showBarcodeGeneratorDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ToolModalShell(
        title: 'Barcode Generator',
        icon: Icons.view_column_rounded,
        color: Colors.deepPurple,
        child: _BarcodeGeneratorContent(),
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

// ── 1. IMAGE CONVERTER CONTENT ─────────────────────────────────
class _ImageConverterContent extends StatefulWidget {
  const _ImageConverterContent();
  @override
  State<_ImageConverterContent> createState() => _ImageConverterContentState();
}

class _ImageConverterContentState extends State<_ImageConverterContent> {
  Uint8List? _inputBytes;
  String? _fileName;
  String _targetFormat = 'png';
  bool _isConverting = false;
  ConvertedImageResult? _result;

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    setState(() {
      _inputBytes = bytes;
      _fileName = file.name;
      _result = null;
    });
  }

  Future<void> _convert() async {
    if (_inputBytes == null) return;
    setState(() => _isConverting = true);
    try {
      final res = await ImageToolsService.convertImage(_inputBytes!, targetFormat: _targetFormat);
      setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conversion error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuCard(
          padding: const EdgeInsets.all(20),
          onTap: _pickImage,
          child: Column(
            children: [
              const Icon(Icons.photo_outlined, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(_fileName ?? 'Select or Drop Image', style: AppTypography.interBody(weight: FontWeight.w600)),
              Text('Supports PNG, JPG, JPEG, WEBP, BMP, GIF', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (_inputBytes != null) ...[
          const SizedBox(height: 16),
          Text('Select Target Format:', style: AppTypography.interLabel()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['png', 'jpg', 'bmp', 'gif'].map((fmt) {
              return ChoiceChip(
                label: Text(fmt.toUpperCase()),
                selected: _targetFormat == fmt,
                selectedColor: AppColors.cyanDeep.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _targetFormat = fmt),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_isConverting)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Convert to ${_targetFormat.toUpperCase()}',
              icon: Icons.change_circle_rounded,
              onPressed: _convert,
            ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_result!.bytes, height: 160, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            _ToolActionButton(
              text: 'Download ${_targetFormat.toUpperCase()}',
              icon: Icons.download_rounded,
              onPressed: () async {
                final base = (_fileName ?? 'image').split('.').first;
                await saveAndDownloadFile(_result!.bytes, '$base.$_targetFormat');
              },
            ),
          ],
        ],
      ],
    );
  }
}

// ── 2. COMPRESS IMAGE CONTENT ──────────────────────────────────
class _CompressImageContent extends StatefulWidget {
  const _CompressImageContent();
  @override
  State<_CompressImageContent> createState() => _CompressImageContentState();
}

class _CompressImageContentState extends State<_CompressImageContent> {
  Uint8List? _inputBytes;
  String? _fileName;
  double _quality = 65;
  int? _maxDimension;
  bool _isCompressing = false;
  ConvertedImageResult? _result;

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    setState(() {
      _inputBytes = bytes;
      _fileName = file.name;
      _result = null;
    });
  }

  Future<void> _compress() async {
    if (_inputBytes == null) return;
    setState(() => _isCompressing = true);
    try {
      final res = await ImageToolsService.compressImage(
        _inputBytes!,
        quality: _quality.toInt(),
        maxDimension: _maxDimension,
      );
      setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
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
          onTap: _pickImage,
          child: Column(
            children: [
              const Icon(Icons.compress_rounded, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(_fileName ?? 'Select Image to Compress', style: AppTypography.interBody(weight: FontWeight.w600)),
              if (_inputBytes != null)
                Text('Original Size: ${_formatSize(_inputBytes!.lengthInBytes)}', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (_inputBytes != null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Compression Quality: ${_quality.toInt()}%', style: AppTypography.interLabel()),
              Text(_quality < 50 ? 'High Compression' : 'High Quality', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
          Slider(
            value: _quality,
            min: 10,
            max: 95,
            divisions: 17,
            onChanged: (v) => setState(() => _quality = v),
          ),
          const SizedBox(height: 8),
          Text('Max Resolution:', style: AppTypography.interLabel()),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _dimChip('Original', null),
              _dimChip('1920 px', 1920),
              _dimChip('1280 px', 1280),
              _dimChip('800 px', 800),
            ],
          ),
          const SizedBox(height: 16),
          if (_isCompressing)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Compress Image Now',
              icon: Icons.bolt_rounded,
              onPressed: _compress,
            ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_formatSize(_result!.originalSize)} ➔ ${_formatSize(_result!.newSize)} (Saved ${_result!.savingsPercent.toStringAsFixed(0)}%)',
                      style: AppTypography.interLabel(color: Colors.green.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ToolActionButton(
              text: 'Download Compressed Image',
              icon: Icons.download_rounded,
              onPressed: () async {
                final base = (_fileName ?? 'image').split('.').first;
                await saveAndDownloadFile(_result!.bytes, '${base}_compressed.jpg');
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _dimChip(String label, int? val) {
    return ChoiceChip(
      label: Text(label),
      selected: _maxDimension == val,
      selectedColor: AppColors.cyanDeep.withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _maxDimension = val),
    );
  }
}

// ── 3. IMAGE WATERMARK REMOVER CONTENT ─────────────────────────
class _WatermarkRemoverContent extends StatefulWidget {
  const _WatermarkRemoverContent();
  @override
  State<_WatermarkRemoverContent> createState() => _WatermarkRemoverContentState();
}

class _WatermarkRemoverContentState extends State<_WatermarkRemoverContent> {
  Uint8List? _inputBytes;
  String? _fileName;
  String _areaPreset = 'bottomRight'; // 'bottomRight', 'bottomLeft', 'topRight', 'center'
  bool _isProcessing = false;
  Uint8List? _cleanedBytes;

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    setState(() {
      _inputBytes = bytes;
      _fileName = file.name;
      _cleanedBytes = null;
    });
  }

  Future<void> _remove() async {
    if (_inputBytes == null) return;
    setState(() => _isProcessing = true);

    Rect area;
    switch (_areaPreset) {
      case 'bottomRight':
        area = const Rect.fromLTWH(0.65, 0.82, 0.33, 0.16);
        break;
      case 'bottomLeft':
        area = const Rect.fromLTWH(0.02, 0.82, 0.33, 0.16);
        break;
      case 'topRight':
        area = const Rect.fromLTWH(0.65, 0.02, 0.33, 0.16);
        break;
      case 'center':
      default:
        area = const Rect.fromLTWH(0.25, 0.35, 0.50, 0.30);
        break;
    }

    try {
      final res = await ImageToolsService.removeWatermark(_inputBytes!, relativeArea: area);
      setState(() => _cleanedBytes = res);
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
          onTap: _pickImage,
          child: Column(
            children: [
              const Icon(Icons.photo_filter_rounded, size: 40, color: AppColors.cyanDeep),
              const SizedBox(height: 8),
              Text(_fileName ?? 'Select Image with Watermark', style: AppTypography.interBody(weight: FontWeight.w600)),
              Text('Removes stamps, logos, and watermark text', style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (_inputBytes != null) ...[
          const SizedBox(height: 16),
          Text('Watermark Position:', style: AppTypography.interLabel()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _chip('Bottom Right', 'bottomRight'),
              _chip('Bottom Left', 'bottomLeft'),
              _chip('Top Right', 'topRight'),
              _chip('Center Stamp', 'center'),
            ],
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Erase Watermark',
              icon: Icons.cleaning_services_rounded,
              onPressed: _remove,
            ),
          if (_cleanedBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_cleanedBytes!, height: 160, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            _ToolActionButton(
              text: 'Download Cleaned Image',
              icon: Icons.download_rounded,
              onPressed: () async {
                final base = (_fileName ?? 'image').split('.').first;
                await saveAndDownloadFile(_cleanedBytes!, '${base}_clean.png');
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _chip(String label, String val) {
    return ChoiceChip(
      label: Text(label),
      selected: _areaPreset == val,
      selectedColor: AppColors.cyanDeep.withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _areaPreset = val),
    );
  }
}

// ── 4. QR GENERATOR CONTENT ────────────────────────────────────
class _QrGeneratorContent extends StatefulWidget {
  const _QrGeneratorContent();
  @override
  State<_QrGeneratorContent> createState() => _QrGeneratorContentState();
}

class _QrGeneratorContentState extends State<_QrGeneratorContent> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _textCtrl = TextEditingController(text: 'https://campussetu.in');
  String? _imageQrPayload;
  String? _selectedImageName;
  bool _isEncodingImage = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImageForQr() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    setState(() {
      _selectedImageName = file.name;
      _isEncodingImage = true;
    });

    try {
      final payload = await ImageToolsService.prepareImageForQr(bytes);
      setState(() => _imageQrPayload = payload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isEncodingImage = false);
    }
  }

  Future<void> _downloadQr(String data) async {
    try {
      final pngBytes = await ImageToolsService.generateQrPng(data);
      await saveAndDownloadFile(pngBytes, 'campussetu_qr.png');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('QR code downloaded as PNG!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.cyanDeep,
          unselectedLabelColor: AppColors.inkSoft,
          indicatorColor: AppColors.cyanDeep,
          tabs: const [
            Tab(text: 'Text / URL to QR', icon: Icon(Icons.link_rounded)),
            Tab(text: 'Image to QR', icon: Icon(Icons.image_rounded)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // TAB 1: TEXT / URL
              SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _textCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enter text, link, roll number...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    if (_textCtrl.text.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: QrImageView(
                          data: _textCtrl.text,
                          version: QrVersions.auto,
                          size: 180.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ToolActionButton(
                        text: 'Download QR Code (PNG)',
                        icon: Icons.download_rounded,
                        onPressed: () => _downloadQr(_textCtrl.text),
                      ),
                    ],
                  ],
                ),
              ),

              // TAB 2: IMAGE TO QR
              SingleChildScrollView(
                child: Column(
                  children: [
                    NeuCard(
                      padding: const EdgeInsets.all(16),
                      onTap: _pickImageForQr,
                      child: Column(
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded, size: 36, color: AppColors.cyanDeep),
                          const SizedBox(height: 6),
                          Text(_selectedImageName ?? 'Select Image to embed in QR', style: AppTypography.interBody(weight: FontWeight.w600)),
                          Text('Scanners will read image Data-URI locally', style: AppTypography.interCaption(color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isEncodingImage)
                      const CircularProgressIndicator()
                    else if (_imageQrPayload != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: QrImageView(
                          data: _imageQrPayload!,
                          version: QrVersions.auto,
                          size: 180.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ToolActionButton(
                        text: 'Download Image QR (PNG)',
                        icon: Icons.download_rounded,
                        onPressed: () => _downloadQr(_imageQrPayload!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 5. BARCODE GENERATOR CONTENT ───────────────────────────────
class _BarcodeGeneratorContent extends StatefulWidget {
  const _BarcodeGeneratorContent();
  @override
  State<_BarcodeGeneratorContent> createState() => _BarcodeGeneratorContentState();
}

class _BarcodeGeneratorContentState extends State<_BarcodeGeneratorContent> {
  final _codeCtrl = TextEditingController(text: 'CAMPUS2026');
  bool _isDownloading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _downloadBarcode() async {
    final text = _codeCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isDownloading = true);
    try {
      final pngBytes = await ImageToolsService.generateBarcodePng(text);
      await saveAndDownloadFile(pngBytes, 'barcode_$text.png');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Barcode downloaded as PNG!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _codeCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Enter text or ID for Barcode (e.g. Roll No, ID)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        if (text.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              children: [
                BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: text,
                  width: 260,
                  height: 90,
                  drawText: true,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isDownloading)
            const Center(child: CircularProgressIndicator())
          else
            _ToolActionButton(
              text: 'Download Barcode (PNG)',
              icon: Icons.download_rounded,
              onPressed: _downloadBarcode,
            ),
        ],
      ],
    );
  }
}

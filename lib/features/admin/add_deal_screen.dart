import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import 'widgets/admin_toast.dart';

class AddDealScreen extends StatefulWidget {
  final Map<String, dynamic>? deal;
  const AddDealScreen({super.key, this.deal});

  @override
  State<AddDealScreen> createState() => _AddDealScreenState();
}

class _AddDealScreenState extends State<AddDealScreen> {
  static const _bg      = Color(0xFF0D0F1A);
  static const _card    = Color(0xFF141728);
  static const _border  = Color(0xFF252840);
  static const _purple  = Color(0xFFA855F7);
  static const _red     = Color(0xFFEF4444);
  static const _green   = Color(0xFF22C55E);
  static const _ink     = Color(0xFFE9EBEE);

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  
  XFile? _photo;
  String? _existingBannerUrl;
  bool _loading = false;
  final _picker = ImagePicker();

  bool get _isEditing => widget.deal != null;
  String get _dealId => (widget.deal?['_id'] ?? widget.deal?['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final d = widget.deal!;
      _titleCtrl.text = (d['title'] ?? '').toString();
      _descCtrl.text = (d['description'] ?? '').toString();
      _codeCtrl.text = (d['discount_code'] ?? d['code'] ?? '').toString();
      _cityCtrl.text = (d['city'] ?? '').toString();
      _stateCtrl.text = (d['state'] ?? '').toString();
      _existingBannerUrl = (d['banner_url'] ?? d['image'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _codeCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Title is required', _red);
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _snack('Description is required', _red);
      return;
    }

    setState(() => _loading = true);
    try {
      final payload = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'discount_code': _codeCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
      };

      if (_isEditing) {
        await ApiService().updateDeal(_dealId, payload, photoPath: _photo?.path);
        if (mounted) {
          _snack('Deal updated successfully!', _green);
          context.pop(true);
        }
      } else {
        await ApiService().createDeal(payload, photoPath: _photo?.path);
        if (mounted) {
          _snack('Deal added successfully!', _green);
          context.pop(true);
        }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', _red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color bg) {
    if (bg == _green) {
      AdminToast.success(context, msg);
    } else {
      AdminToast.error(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Deal' : 'Add New Deal',
          style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: _ink),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Deal Title'),
            _Field(controller: _titleCtrl, hint: 'e.g. 50% Off at Dominos'),
            const SizedBox(height: 20),
            
            const _Label('Description'),
            _Field(controller: _descCtrl, hint: 'Enter details about the deal...', maxLines: 4),
            const SizedBox(height: 20),
            
            const _Label('Discount Code (Optional)'),
            _Field(controller: _codeCtrl, hint: 'e.g. DOMINOS50'),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Target City (Optional)'),
                      _Field(controller: _cityCtrl, hint: 'e.g. Bangalore, Pune'),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('State (Optional)'),
                      _Field(controller: _stateCtrl, hint: 'e.g. Karnataka'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Leave empty or write "All" for all-India student deals.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
            const SizedBox(height: 20),
            
            const _Label('Banner Image (Optional)'),
            _PhotoPicker(
              photo: _photo,
              existingImageUrl: _existingBannerUrl,
              onTap: () async {
                final xf = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (xf != null) setState(() => _photo = xf);
              },
            ),
            
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _loading ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _loading ? _purple.withValues(alpha: 0.5) : _purple,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing ? 'Update Deal' : 'Publish Deal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE9EBEE),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _Field({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF252840)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final XFile? photo;
  final String? existingImageUrl;
  final VoidCallback onTap;

  const _PhotoPicker({
    required this.photo,
    this.existingImageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const border  = Color(0xFF252840);
    const purple  = Color(0xFFA855F7);
    const cardAlt = Color(0xFF1C2033);

    final hasExisting = existingImageUrl != null && existingImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (photo != null || hasExisting) ? purple.withValues(alpha: 0.4) : border),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo != null
            ? Stack(fit: StackFit.expand, children: [
                Image.file(File(photo!.path), fit: BoxFit.cover),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ])
            : hasExisting
                ? Stack(fit: StackFit.expand, children: [
                    Image.network(existingImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Change Image', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ])
                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, color: purple, size: 32),
                    SizedBox(height: 8),
                    Text('Add banner photo', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  ]),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';

class AddDealScreen extends StatefulWidget {
  const AddDealScreen({super.key});

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
  
  XFile? _photo;
  bool _loading = false;
  final _picker = ImagePicker();

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
      await ApiService().createDeal({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        if (_codeCtrl.text.trim().isNotEmpty) 'discount_code': _codeCtrl.text.trim(),
      }, photoPath: _photo?.path);

      if (mounted) {
        _snack('Deal added successfully!', _green);
        context.pop();
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', _red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: const Text('Add New Deal', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w600)),
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
            
            const _Label('Banner Image (Optional)'),
            _PhotoPicker(
              photo: _photo,
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _loading ? [] : [BoxShadow(color: _purple.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Post Deal', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(text, style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14, fontWeight: FontWeight.w500)),
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
  final VoidCallback onTap;

  const _PhotoPicker({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const border  = Color(0xFF252840);
    const purple  = Color(0xFFA855F7);
    const cardAlt = Color(0xFF1C2033);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: photo != null ? purple.withValues(alpha: 0.4) : border),
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
            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, color: purple, size: 32),
                SizedBox(height: 8),
                Text('Add banner photo', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              ]),
      ),
    );
  }
}

// lib/features/home/widgets/create_post_sheet.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/neu_card.dart';
import '../../../core/widgets/neu_text_field.dart';

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _contentCtrl = TextEditingController();
  bool _isPosting = false;
  File? _imageFile;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1200);
      if (picked != null) {
        final file = File(picked.path);
        final sizeMb = await file.length() / (1024 * 1024);
        if (sizeMb > 5) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be <5MB')));
          return;
        }
        setState(() => _imageFile = file);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pick failed: $e')));
    }
  }

  Future<String?> _uploadImageIfNeeded() async {
    if (_imageFile == null) return null;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      final ref = FirebaseStorage.instance.ref().child('post_images/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_imageFile!, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Post image Firebase upload failed: $e');
      // fallback to backend upload via profile endpoint hack? try as post image via same profile upload and use its url
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final res = await ApiService().uploadProfilePhoto(uid, _imageFile!.path);
        final url = (res['photo_url'] ?? res['file_url'] ?? '').toString();
        if (url.isNotEmpty) return url;
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _submit() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something or add a photo!')));
      return;
    }
    setState(() => _isPosting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) ApiService().setToken(token);
      }
      String? imageUrl;
      if (_imageFile != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading image...')));
        imageUrl = await _uploadImageIfNeeded();
      }
      await ApiService().createPost({'content': text.isEmpty ? '📷 Photo' : text, 'image_url': imageUrl});
      if (mounted) Navigator.pop(context, true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted ✓'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.neuRaisedShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.shadowDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Create Post', style: AppTypography.soraHeading3()),
            const SizedBox(height: 16),
            NeuTextField(
              hint: 'What\'s on your mind?',
              controller: _contentCtrl,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 12),
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_imageFile!, width: double.infinity, height: 160, fit: BoxFit.cover)),
                Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => setState(() => _imageFile = null), child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: Colors.white)))),
              ]),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                NeuCard(
                  padding: const EdgeInsets.all(10),
                  onTap: _isPosting ? null : _pickImage,
                  child: Icon(Icons.image_outlined, color: _imageFile != null ? AppColors.success : AppColors.cyanDeep, size: 20),
                ),
                if (_imageFile != null) ...[const SizedBox(width: 8), Text('1 photo selected', style: AppTypography.interCaption(color: AppColors.success))],
                const Spacer(),
                GestureDetector(
                  onTap: _isPosting ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Post', style: AppTypography.interButton(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

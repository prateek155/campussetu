import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_chip.dart';
import '../../core/widgets/neu_text_field.dart';

class CreateHelpingTaskSheet extends StatefulWidget {
  const CreateHelpingTaskSheet({super.key});
  @override
  State<CreateHelpingTaskSheet> createState() => _CreateHelpingTaskSheetState();
}

class _CreateHelpingTaskSheetState extends State<CreateHelpingTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  String _type = 'paid';
  DateTime? _deadline;
  File? _image;
  bool _posting = false;

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _amountCtrl.dispose(); _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
      if (picked == null) return;
      final f = File(picked.path);
      final mb = await f.length() / (1024 * 1024);
      if (mb > 2) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image max 2MB allowed'), backgroundColor: AppColors.error));
        return;
      }
      setState(() => _image = f);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pick failed: $e')));
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: now.add(const Duration(days: 3)));
    if (d != null) setState(() => _deadline = d);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.length < 3) { _err('Title min 3 chars'); return; }
    if (desc.length < 5) { _err('Description min 5 chars'); return; }
    double? amt; int? pts;
    if (_type == 'paid') {
      amt = double.tryParse(_amountCtrl.text.trim());
      if (amt == null || amt <= 0) { _err('Valid amount required'); return; }
      if (_deadline == null) { _err('Deadline required for paid task'); return; }
    } else {
      pts = int.tryParse(_pointsCtrl.text.trim());
      if (pts == null || pts <= 0) { _err('Valid points required'); return; }
    }
    setState(() => _posting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) ApiService().setToken(token);
      }
      await ApiService().createHelpingTask(
        title: title, description: desc, type: _type,
        amount: amt, points: pts,
        deadline: _deadline != null ? DateFormat('yyyy-MM-dd').format(_deadline!) : null,
        imagePath: _image?.path,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task posted ✓'), backgroundColor: AppColors.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      var msg = e.toString();
      if (msg.contains('Insufficient points')) { _err('Insufficient points balance'); }
      else { _err('Failed: ${msg.length > 120 ? msg.substring(0, 120) : msg}'); }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.neuRaisedShadows),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.shadowDark, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Post Helping Task', style: AppTypography.soraHeading3()),
          const SizedBox(height: 4),
          Text(_type == 'paid' ? 'Pay cash/UPI directly after work' : 'Reward from your points balance', style: AppTypography.interCaption(color: AppColors.inkSoft)),
          const SizedBox(height: 14),
          Row(children: [
            NeuChip(label: '💰 Paid', isSelected: _type == 'paid', onTap: () => setState(() => _type = 'paid')),
            const SizedBox(width: 8),
            NeuChip(label: '⭐ Points', isSelected: _type == 'points', onTap: () => setState(() => _type = 'points'), selectedColor: AppColors.warning),
          ]),
          const SizedBox(height: 14),
          NeuTextField(hint: 'e.g. Assignment help, notes...', label: 'Work title', controller: _titleCtrl, maxLength: 120),
          const SizedBox(height: 12),
          NeuTextField(hint: 'Work details...', label: 'Description', controller: _descCtrl, maxLines: 4, maxLength: 2000),
          const SizedBox(height: 12),
          if (_type == 'paid') ...[
            Row(children: [
              Expanded(child: NeuTextField(hint: '₹ 0', label: 'Amount (₹)', controller: _amountCtrl, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Deadline', style: AppTypography.interLabel(color: AppColors.inkSoft)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDeadline,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), boxShadow: AppColors.neuInsetShadows), child: Row(children: [Icon(Icons.event_outlined, size: 16, color: AppColors.inkSoft), const SizedBox(width: 6), Text(_deadline == null ? 'Select date' : DateFormat('dd MMM yyyy').format(_deadline!), style: AppTypography.interBody(size: 13))])),
                  ),
                ]),
              ),
            ]),
          ] else ...[
            NeuTextField(hint: 'e.g. 50', label: 'Reward points', controller: _pointsCtrl, keyboardType: TextInputType.number),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), boxShadow: AppColors.neuInsetShadows),
              child: _image == null
                  ? Row(children: [const Icon(Icons.image_outlined, color: AppColors.cyanDeep, size: 20), const SizedBox(width: 8), Expanded(child: Text('Add image (optional, max 2MB)', style: AppTypography.interBody(color: AppColors.inkSoft, size: 13)))])
                  : Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_image!, height: 140, width: double.infinity, fit: BoxFit.cover)), Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => setState(() => _image = null), child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: Colors.white))))]),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _posting ? null : _submit,
            child: Container(width: double.infinity, height: 54, decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: _posting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Post Task', style: AppTypography.interButton(color: Colors.white))),
          ),
          const SizedBox(height: 6),
          Center(child: NeuCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('Visible to all students', style: AppTypography.interCaption(color: AppColors.inkSoft)))),
        ]),
      ),
    );
  }
}

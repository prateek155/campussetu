// lib/features/admin/add_deal_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

class AddDealScreen extends ConsumerStatefulWidget {
  const AddDealScreen({super.key});

  @override
  ConsumerState<AddDealScreen> createState() => _AddDealScreenState();
}

class _AddDealScreenState extends ConsumerState<AddDealScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and Description are required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService().createDeal({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'discount_code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        'banner_url': _imgCtrl.text.trim().isEmpty ? null : _imgCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deal added successfully!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Add New Deal', style: AppTypography.soraHeading3()),
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _titleCtrl,
                style: TextStyle(color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'Title (e.g. 50% Off at Dominos)',
                  labelStyle: TextStyle(color: AppColors.inkSoft),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _descCtrl,
                maxLines: 3,
                style: TextStyle(color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: AppColors.inkSoft),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _codeCtrl,
                style: TextStyle(color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'Discount Code (Optional)',
                  labelStyle: TextStyle(color: AppColors.inkSoft),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _imgCtrl,
                style: TextStyle(color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'Banner Image URL (Optional)',
                  labelStyle: TextStyle(color: AppColors.inkSoft),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Post Deal'),
                  ),
          ],
        ),
      ),
    );
  }
}

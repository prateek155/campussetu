import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/services/api_service.dart';
import '../../core/models/deal_model.dart';

final adminDealsProvider = FutureProvider.autoDispose<List<DealModel>>((ref) async {
  final res = await ApiService().getDeals();
  return res.map((d) => DealModel.fromJson(d)).toList();
});

class EnterpriseScreen extends ConsumerStatefulWidget {
  const EnterpriseScreen({super.key});

  @override
  ConsumerState<EnterpriseScreen> createState() => _EnterpriseScreenState();
}

class _EnterpriseScreenState extends ConsumerState<EnterpriseScreen> {
  DealModel? _selectedDeal;
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _redeem() async {
    if (_selectedDeal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a deal first')));
      return;
    }
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a code')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService().post('/admin/enterprise/redeem', data: {
        'deal_id': _selectedDeal!.id,
        'deal_code': code,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Successfully redeemed!'),
          backgroundColor: AppColors.success,
        ));
        _codeCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dealsAsync = ref.watch(adminDealsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Enterprise Portal', style: AppTypography.soraHeading3()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: dealsAsync.when(
        data: (deals) {
          if (deals.isEmpty) {
            return const Center(child: Text('No deals available.'));
          }
          if (_selectedDeal == null && deals.isNotEmpty) {
            _selectedDeal = deals.first;
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NeuCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Redeem Offer', style: AppTypography.soraHeading3()),
                                  Text('Enterprise Deal Verification', style: AppTypography.interCaption(color: AppColors.inkSoft)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text("Select the deal and enter the student's deal code (e.g. PA1542) to mark it as availed.", style: AppTypography.interBody(color: AppColors.inkSoft)),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<DealModel>(
                            initialValue: _selectedDeal,
                            decoration: InputDecoration(
                              labelText: 'Select Deal',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: deals.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text(d.title, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDeal = val;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _codeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Student Deal Code',
                              hintText: 'PA1542',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _redeem,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify & Redeem', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

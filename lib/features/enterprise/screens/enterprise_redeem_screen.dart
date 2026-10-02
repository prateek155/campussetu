// lib/features/enterprise/screens/enterprise_redeem_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/deal_model.dart';
import '../../../core/services/api_service.dart';
import '../providers/enterprise_providers.dart';

final enterpriseDealsListProvider = FutureProvider.autoDispose<List<DealModel>>((ref) async {
  try {
    final res = await ApiService().getDeals();
    return res.map((d) => DealModel.fromJson(d)).toList();
  } catch (_) {
    return [];
  }
});

class EnterpriseRedeemScreen extends ConsumerStatefulWidget {
  const EnterpriseRedeemScreen({super.key});

  @override
  ConsumerState<EnterpriseRedeemScreen> createState() => _EnterpriseRedeemScreenState();
}

class _EnterpriseRedeemScreenState extends ConsumerState<EnterpriseRedeemScreen> {
  DealModel? _selectedDeal;
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_selectedDeal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an offer deal first')),
      );
      return;
    }
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter student deal code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService().post('/enterprise/redeem', data: {
        'deal_id': _selectedDeal!.id,
        'deal_code': code,
      });

      final studentName = res['student']?['name'] ?? 'Student';

      // Log redemption locally with exact date & time
      await ref.read(enterpriseRedeemProvider.notifier).logRedemption(
        _selectedDeal!.id,
        _selectedDeal!.title,
        code,
        studentName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res['message'] ?? 'Successfully redeemed!'} ($studentName)'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _codeCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dealsAsync = ref.watch(enterpriseDealsListProvider);
    final redeemLogs = ref.watch(enterpriseRedeemProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Redeem Verification Card (Preserves existing feature as requested)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF171E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26334D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Redeem Student Offer',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                        ),
                        Text('CampusSetu Deal Code Verification', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  "Student ka deal code (e.g. PA1542) verify karke redeem karein. Automatic date aur time log ho jayega.",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 20),

                dealsAsync.when(
                  data: (deals) {
                    if (deals.isEmpty) {
                      return const Text('Koi active deal nahi hai.', style: TextStyle(color: Color(0xFF94A3B8)));
                    }
                    if (_selectedDeal == null && deals.isNotEmpty) {
                      _selectedDeal = deals.first;
                    }

                    return DropdownButtonFormField<DealModel>(
                      initialValue: _selectedDeal,
                      dropdownColor: const Color(0xFF171E30),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Select Active Deal',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F1422),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
                      ),
                      items: deals.map((d) {
                        return DropdownMenuItem(
                          value: d,
                          child: Text(d.title, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedDeal = val);
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(color: Color(0xFF10B981)),
                  error: (_, __) => const Text('Failed to load deals', style: TextStyle(color: Colors.redAccent)),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    labelText: 'Student Deal Code',
                    hintText: 'PA1542',
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F1422),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isLoading ? null : _redeem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & Redeem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Redemptions History Log with Date & Timestamp (Requested by user)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF171E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26334D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Redemptions Log',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Har redemption ka exact date aur samay yahan automatic record hota hai',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 16),

                if (redeemLogs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text('Abhi tak koi offer redeem nahi hua hai.', style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: redeemLogs.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF26334D)),
                    itemBuilder: (context, index) {
                      final log = redeemLogs[index];
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1422),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${log.studentName} (${log.dealCode})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(log.dealTitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(log.timestamp),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                DateFormat('hh:mm a').format(log.timestamp),
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

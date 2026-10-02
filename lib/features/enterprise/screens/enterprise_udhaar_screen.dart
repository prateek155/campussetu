// lib/features/enterprise/screens/enterprise_udhaar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseUdhaarScreen extends ConsumerStatefulWidget {
  const EnterpriseUdhaarScreen({super.key});

  @override
  ConsumerState<EnterpriseUdhaarScreen> createState() => _EnterpriseUdhaarScreenState();
}

class _EnterpriseUdhaarScreenState extends ConsumerState<EnterpriseUdhaarScreen> {
  String _searchCustomer = '';

  void _showAddUdhaarDialog(bool isRepayment) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isRepayment ? 'Udhaar Wapas Lo (Payment Received)' : 'Udhaar Do (Credit Given)',
          style: TextStyle(
            color: isRepayment ? const Color(0xFF10B981) : Colors.orangeAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Customer / Student Name',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF0F1422),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF0F1422),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Date (YYYY-MM-DD)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF0F1422),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Note (Optional, e.g. Chai nashta bill)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF0F1422),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              final date = dateCtrl.text.trim();
              final note = noteCtrl.text.trim();
              if (name.isEmpty || amount <= 0) return;

              ref.read(enterpriseUdhaarProvider.notifier).addRecord(
                name,
                amount,
                isRepayment ? 'repaid' : 'given',
                date,
                note,
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isRepayment ? const Color(0xFF10B981) : Colors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(isRepayment ? 'Save Payment' : 'Save Udhaar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final udhaarList = ref.watch(enterpriseUdhaarProvider);

    final totalGiven = udhaarList.where((u) => u.type == 'given').fold(0.0, (acc, u) => acc + u.amount);
    final totalRepaid = udhaarList.where((u) => u.type == 'repaid').fold(0.0, (acc, u) => acc + u.amount);
    final netDue = (totalGiven - totalRepaid).clamp(0.0, double.infinity);

    final filtered = udhaarList.where((u) =>
        u.customerName.toLowerCase().contains(_searchCustomer.toLowerCase()) ||
        u.notes.toLowerCase().contains(_searchCustomer.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard('Total Udhaar Diya', '₹${totalGiven.toStringAsFixed(0)}', Colors.orangeAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildSummaryCard('Total Wapas Mila', '₹${totalRepaid.toStringAsFixed(0)}', const Color(0xFF10B981)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildSummaryCard('Net Baaki / Due', '₹${netDue.toStringAsFixed(0)}', Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Bar & Search
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF171E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26334D)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Udhaar (CRM) Khata Book',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showAddUdhaarDialog(true),
                          icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF10B981)),
                          label: const Text('Udhaar Wapas Lo', style: TextStyle(color: Color(0xFF10B981))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _showAddUdhaarDialog(false),
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: const Text('Udhaar Do'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (val) => setState(() => _searchCustomer = val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search customer / student name...',
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                    filled: true,
                    fillColor: const Color(0xFF0F1422),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ledger List
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF171E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26334D)),
            ),
            child: filtered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text('Koi udhaar record nahi mila.', style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF26334D)),
                    itemBuilder: (context, index) {
                      final u = filtered[index];
                      final isRepaid = u.type == 'repaid';

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isRepaid ? const Color(0xFF064E3B) : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isRepaid ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isRepaid ? const Color(0xFF10B981) : Colors.orangeAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(
                                  '${isRepaid ? "Payment Received" : "Udhaar Diya"} • ${u.transactionDate} ${u.notes.isNotEmpty ? "• ${u.notes}" : ""}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isRepaid ? "+" : "-"} ₹${u.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: isRepaid ? const Color(0xFF10B981) : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF171E30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26334D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

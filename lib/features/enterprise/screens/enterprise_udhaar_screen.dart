// lib/features/enterprise/screens/enterprise_udhaar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/enterprise_models.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseUdhaarScreen extends ConsumerStatefulWidget {
  const EnterpriseUdhaarScreen({super.key});

  @override
  ConsumerState<EnterpriseUdhaarScreen> createState() => _EnterpriseUdhaarScreenState();
}

class _EnterpriseUdhaarScreenState extends ConsumerState<EnterpriseUdhaarScreen> {
  String _searchCustomer = '';
  String _filterType = 'all'; // 'all', 'given', 'repaid'

  void _showAddEditUdhaarDialog({UdhaarRecord? existing, bool isRepayment = false}) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.customerName ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final dateCtrl = TextEditingController(
      text: existing?.transactionDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final noteCtrl = TextEditingController(text: existing?.notes ?? '');
    String recordType = existing?.type ?? (isRepayment ? 'repaid' : 'given');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isRepaidType = recordType == 'repaid';
          return AlertDialog(
            backgroundColor: const Color(0xFF171E30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isEditing
                  ? 'Edit Khata / Udhaar Record'
                  : (isRepaidType ? 'Udhaar Wapas Lo (Payment Received)' : 'Udhaar Do (Credit Given)'),
              style: TextStyle(
                color: isRepaidType ? const Color(0xFF10B981) : Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEditing) ...[
                    const Text('Transaction Type', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => recordType = 'given'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: recordType == 'given' ? Colors.orange.withValues(alpha: 0.25) : const Color(0xFF0F1422),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: recordType == 'given' ? Colors.orangeAccent : const Color(0xFF26334D)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Udhaar Diya',
                                style: TextStyle(
                                  color: recordType == 'given' ? Colors.orangeAccent : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => recordType = 'repaid'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: recordType == 'repaid' ? const Color(0xFF064E3B) : const Color(0xFF0F1422),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: recordType == 'repaid' ? const Color(0xFF10B981) : const Color(0xFF26334D)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Wapas Mila',
                                style: TextStyle(
                                  color: recordType == 'repaid' ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
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

                  if (isEditing) {
                    ref.read(enterpriseUdhaarProvider.notifier).updateRecord(
                      UdhaarRecord(
                        id: existing.id,
                        customerName: name,
                        amount: amount,
                        type: recordType,
                        transactionDate: date.isNotEmpty ? date : existing.transactionDate,
                        notes: note,
                      ),
                    );
                  } else {
                    ref.read(enterpriseUdhaarProvider.notifier).addRecord(
                      name,
                      amount,
                      recordType,
                      date,
                      note,
                    );
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRepaidType ? const Color(0xFF10B981) : Colors.orangeAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEditing ? 'Save Changes' : (isRepaidType ? 'Save Payment' : 'Save Udhaar')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(UdhaarRecord u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Udhaar Record?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Kya aap "${u.customerName}" ka ₹${u.amount.toStringAsFixed(0)} ka record delete karna chahte hain?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(enterpriseUdhaarProvider.notifier).deleteRecord(u.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Udhaar record delete ho gaya.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
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

    final filtered = udhaarList.where((u) {
      final matchesSearch = u.customerName.toLowerCase().contains(_searchCustomer.toLowerCase()) ||
          u.notes.toLowerCase().contains(_searchCustomer.toLowerCase());
      final matchesType = _filterType == 'all' || u.type == _filterType;
      return matchesSearch && matchesType;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat Cards (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildSummaryCard('Total Udhaar Diya', '₹${totalGiven.toStringAsFixed(0)}', Colors.orangeAccent),
                    const SizedBox(height: 10),
                    _buildSummaryCard('Total Wapas Mila', '₹${totalRepaid.toStringAsFixed(0)}', const Color(0xFF10B981)),
                    const SizedBox(height: 10),
                    _buildSummaryCard('Net Baaki / Due', '₹${netDue.toStringAsFixed(0)}', Colors.redAccent),
                  ],
                );
              }
              return Row(
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
              );
            },
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            if (!isNarrow) ...[
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showAddEditUdhaarDialog(isRepayment: true),
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
                                    onPressed: () => _showAddEditUdhaarDialog(isRepayment: false),
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
                          ],
                        ),
                        if (isNarrow) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showAddEditUdhaarDialog(isRepayment: true),
                                icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF10B981)),
                                label: const Text('Udhaar Wapas Lo', style: TextStyle(color: Color(0xFF10B981))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF10B981)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditUdhaarDialog(isRepayment: false),
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
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Search Bar + Filter Tabs
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1422),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF26334D)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterType,
                          dropdownColor: const Color(0xFF171E30),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Sabhi (All)')),
                            DropdownMenuItem(value: 'given', child: Text('Udhaar Diya')),
                            DropdownMenuItem(value: 'repaid', child: Text('Wapas Mila')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _filterType = val);
                          },
                        ),
                      ),
                    ),
                  ],
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

                      return LayoutBuilder(
                        builder: (ctx, itemConstraints) {
                          final isCompact = itemConstraints.maxWidth < 500;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
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
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.customerName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${isRepaid ? "Wapas Mila" : "Udhaar Diya"} • ${u.transactionDate}${u.notes.isNotEmpty ? " • ${u.notes}" : ""}',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isCompact) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${isRepaid ? "+" : "-"} ₹${u.amount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: isRepaid ? const Color(0xFF10B981) : Colors.orangeAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!isCompact) ...[
                                  Text(
                                    '${isRepaid ? "+" : "-"} ₹${u.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: isRepaid ? const Color(0xFF10B981) : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 18),
                                      tooltip: 'Edit Record',
                                      onPressed: () => _showAddEditUdhaarDialog(existing: u),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                      tooltip: 'Delete Record',
                                      onPressed: () => _confirmDelete(u),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
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
      padding: const EdgeInsets.all(18),
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

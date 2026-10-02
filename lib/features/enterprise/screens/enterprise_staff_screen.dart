// lib/features/enterprise/screens/enterprise_staff_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/enterprise_models.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseStaffScreen extends ConsumerWidget {
  const EnterpriseStaffScreen({super.key});

  void _showAddStaffDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final postCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Staff Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Staff Name (e.g. Rahul Sharma)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF0F1422),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: postCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Post / Role (e.g. Head Chef, Waiter, Helper)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF0F1422),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: salaryCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Monthly Salary (₹)',
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
                labelText: 'Joining Date (YYYY-MM-DD)',
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
              final post = postCtrl.text.trim();
              final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
              final date = dateCtrl.text.trim();
              if (name.isEmpty || post.isEmpty) return;

              ref.read(enterpriseStaffProvider.notifier).addStaff(name, post, salary, date);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Add Staff'),
          ),
        ],
      ),
    );
  }

  void _showAddAdvanceDialog(BuildContext context, WidgetRef ref, StaffMember staff) {
    final amountCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Advance Payment — ${staff.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Base Salary: ₹${staff.salary.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Advance Amount (₹)',
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
                labelText: 'Advance Date (YYYY-MM-DD)',
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
                labelText: 'Reason / Note (e.g. Ghar ke kharch ke liye)',
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
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              final date = dateCtrl.text.trim();
              final note = noteCtrl.text.trim();
              if (amount <= 0) return;

              ref.read(enterpriseStaffProvider.notifier).addAdvance(staff.id, amount, date, note);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${staff.name} ke liye ₹${amount.toStringAsFixed(0)} advance add ho gaya!'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Save Advance'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffList = ref.watch(enterpriseStaffProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF171E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26334D)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Staff salary, joining date aur advance payment track karein', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddStaffDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add Staff Member'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Staff Cards List
          if (staffList.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF171E30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF26334D)),
              ),
              alignment: Alignment.center,
              child: const Text('Abhi koi staff member add nahi kiya gaya hai.', style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staffList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final staff = staffList[index];

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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1422),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.badge_rounded, color: Color(0xFF10B981), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(staff.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                                const SizedBox(height: 2),
                                Text(
                                  '${staff.post} • Joined: ${staff.joiningDate}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              ref.read(enterpriseStaffProvider.notifier).deleteStaff(staff.id);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF26334D)),
                      const SizedBox(height: 12),

                      // Salary Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1422),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Base Salary', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('₹${staff.salary.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFF26334D)),
                            Column(
                              children: [
                                const Text('Advance Taken', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('₹${staff.totalAdvance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFF26334D)),
                            Column(
                              children: [
                                const Text('Net Payable', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('₹${staff.netSalary.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Action row: Advance button & Advance history list
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            staff.advances.isEmpty
                                ? 'Is month koi advance nahi liya'
                                : '${staff.advances.length} advance payment records',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddAdvanceDialog(context, ref, staff),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                            label: const Text('Add Advance'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF172554),
                              foregroundColor: const Color(0xFF38BDF8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),

                      if (staff.advances.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: staff.advances.map((a) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1422),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF26334D)),
                              ),
                              child: Text(
                                '${a.advanceDate}: ₹${a.amount.toStringAsFixed(0)} ${a.notes.isNotEmpty ? "(${a.notes})" : ""}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

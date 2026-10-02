// lib/features/enterprise/screens/enterprise_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseReportsScreen extends ConsumerWidget {
  const EnterpriseReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(enterpriseBillsProvider);

    final totalSale = bills.fold(0.0, (acc, b) => acc + b.totalAmount);
    final cashSale = bills.where((b) => b.paymentMode.toLowerCase() == 'cash').fold(0.0, (acc, b) => acc + b.totalAmount);
    final upiSale = bills.where((b) => b.paymentMode.toLowerCase() == 'upi').fold(0.0, (acc, b) => acc + b.totalAmount);
    final billsCount = bills.length;

    // Calculate top items
    final itemCounts = <String, int>{};
    final itemRevenue = <String, double>{};
    for (final b in bills) {
      for (final item in b.items) {
        itemCounts[item.name] = (itemCounts[item.name] ?? 0) + item.quantity;
        itemRevenue[item.name] = (itemRevenue[item.name] ?? 0.0) + item.total;
      }
    }
    final sortedItemNames = itemCounts.keys.toList()
      ..sort((a, b) => (itemCounts[b] ?? 0).compareTo(itemCounts[a] ?? 0));
    final topItems = sortedItemNames.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── TOP 4 STAT CARDS (Image 3) ─────────────────────
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total sale', '₹${totalSale.toStringAsFixed(0)}')),
              const SizedBox(width: 14),
              Expanded(child: _buildMetricCard('Cash', '₹${cashSale.toStringAsFixed(0)}')),
              const SizedBox(width: 14),
              Expanded(child: _buildMetricCard('UPI', '₹${upiSale.toStringAsFixed(0)}')),
              const SizedBox(width: 14),
              Expanded(child: _buildMetricCard('Bills', '$billsCount')),
            ],
          ),
          const SizedBox(height: 20),

          // ── TOP ITEMS CARD (Image 3) ───────────────────────
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
                  'Top items',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 12),
                if (topItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Bills banne par yahan dikhega.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  )
                else
                  ...topItems.map((name) {
                    final qty = itemCounts[name] ?? 0;
                    final rev = itemRevenue[name] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
                          ),
                          Text('$qty sold', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          const SizedBox(width: 16),
                          Text('₹${rev.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── WEEKLY SALES CHART ─────────────────────────────
          if (bills.isNotEmpty) ...[
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
                    'Daily Sales Trend',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Pichhle 7 dino ki bikri ka graph', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (totalSale > 0 ? totalSale * 1.2 : 500),
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                final now = DateTime.now();
                                final day = now.subtract(Duration(days: 6 - val.toInt()));
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    DateFormat('E').format(day),
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: List.generate(7, (i) {
                          final now = DateTime.now();
                          final targetDate = now.subtract(Duration(days: 6 - i));
                          final dayBills = bills.where((b) =>
                              b.createdAt.year == targetDate.year &&
                              b.createdAt.month == targetDate.month &&
                              b.createdAt.day == targetDate.day);
                          final dayTotal = dayBills.fold(0.0, (acc, b) => acc + b.totalAmount);

                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: dayTotal,
                                color: const Color(0xFF10B981),
                                width: 18,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── RECENT BILLS TABLE (Image 3) ───────────────────
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
                  'Recent bills',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 16),

                // Table Header (Bill | Table | Mode | Total)
                const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Bill', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13))),
                    Expanded(flex: 2, child: Text('Table', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13))),
                    Expanded(flex: 2, child: Text('Mode', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13))),
                    Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
                const Divider(color: Color(0xFF26334D), height: 20),

                if (bills.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text('Abhi tak koi bill generate nahi hua hai.', style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                else
                  ...bills.take(15).map((b) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.billNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(DateFormat('dd MMM, hh:mm a').format(b.createdAt), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(b.tableNumber, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: b.paymentMode == 'UPI' ? const Color(0xFF1E3A8A) : const Color(0xFF064E3B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                b.paymentMode,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: b.paymentMode == 'UPI' ? const Color(0xFF60A5FA) : const Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹${b.totalAmount.toStringAsFixed(0)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value) {
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
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// lib/features/enterprise/screens/enterprise_billing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/enterprise_models.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseBillingScreen extends ConsumerWidget {
  const EnterpriseBillingScreen({super.key});

  void _showReceiptDialog(BuildContext context, EnterpriseBill bill, EnterpriseStoreProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Text(
              'Bill / Receipt (${bill.billNumber})',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    profile.restaurantName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (profile.city.isNotEmpty)
                    Text(
                      '${profile.city}, ${profile.state}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  if (profile.mobileNumber.isNotEmpty)
                    Text(
                      'Ph: ${profile.mobileNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  const Divider(color: Colors.black45, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bill No: ${bill.billNumber}', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Table: ${bill.tableNumber}', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(
                    'Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(bill.createdAt)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const Divider(color: Colors.black45, thickness: 1),
                  // Items header
                  const Row(
                    children: [
                      Expanded(flex: 5, child: Text('Item', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...bill.items.map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: Text(i.name, style: const TextStyle(color: Colors.black87, fontSize: 12))),
                        Expanded(flex: 2, child: Text('${i.quantity}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 12))),
                        Expanded(flex: 3, child: Text('₹${i.total.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.black87, fontSize: 12))),
                      ],
                    ),
                  )),
                  const Divider(color: Colors.black45, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(color: Colors.black, fontSize: 12)),
                      Text('₹${bill.subtotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black, fontSize: 12)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GST (${bill.gstPercent.toStringAsFixed(0)}%):', style: const TextStyle(color: Colors.black, fontSize: 12)),
                      Text('₹${bill.gstAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('₹${bill.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Payment Mode: ${bill.paymentMode}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                  const Divider(color: Colors.black45, thickness: 1),
                  const Text(
                    'Thank You! Visit Again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Print command sent to POS printer!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Print Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpiQrDialog(
    BuildContext context,
    WidgetRef ref,
    EnterpriseStoreProfile profile,
    EnterpriseBillingState billingState,
  ) {
    final upiId = profile.upiId.trim().isNotEmpty ? profile.upiId.trim() : 'campussetu@upi';
    final total = billingState.getTotal(profile.gstPercent);
    final restName = Uri.encodeComponent(profile.restaurantName);
    final upiUri = 'upi://pay?pa=$upiId&pn=$restName&am=${total.toStringAsFixed(2)}&cu=INR&tn=Bill%20${billingState.selectedTable}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'UPI Payment — ${billingState.selectedTable}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total Payable: ₹${total.toStringAsFixed(0)}',
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'UPI ID: $upiId',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: upiUri,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Customer se QR scan karke pay karwayein.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final bill = await ref.read(enterpriseBillingProvider.notifier).checkoutBill(
                'UPI',
                profile.gstPercent,
                profile.billPrefix,
              );
              if (context.mounted) {
                _showReceiptDialog(context, bill, profile);
              }
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Payment Mil Gaya -> Print Bill'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(enterpriseProfileProvider);
    final foodItems = ref.watch(enterpriseFoodMenuProvider);
    final billingState = ref.watch(enterpriseBillingProvider);

    // Categories
    final categories = ['All', 'Nashta', 'Main', 'Drinks', 'Meetha'];
    // Filter food items
    final filteredItems = billingState.selectedCategory == 'All'
        ? foodItems
        : foodItems.where((i) => i.category.toLowerCase() == billingState.selectedCategory.toLowerCase()).toList();

    // Tables list (1 to tablesCount)
    final tables = List.generate(profile.tablesCount, (i) => 'Table ${i + 1}');

    final cart = billingState.currentCart;
    final subtotal = billingState.subtotal;
    final gstAmount = billingState.getGstAmount(profile.gstPercent);
    final total = billingState.getTotal(profile.gstPercent);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        final leftCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF171E30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF26334D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                      // Table Number Dropdown
                      const Text(
                        'Table number',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1422),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: tables.contains(billingState.selectedTable) ? billingState.selectedTable : tables.first,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF171E30),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: tables.map((t) {
                              final hasHoldCart = (billingState.tableCarts[t]?.isNotEmpty ?? false);
                              return DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Text(t),
                                    if (hasHoldCart) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Hold Order', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(enterpriseBillingProvider.notifier).selectTable(val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category Pills (All, Nashta, Main, Drinks, Meetha)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories.map((cat) {
                            final isSelected = billingState.selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => ref.read(enterpriseBillingProvider.notifier).selectCategory(cat),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF064E3B) : const Color(0xFF0F1422),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF26334D),
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Food Items Grid (Cards with Name & Price)
                      if (filteredItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: const Text(
                            'Is category me koi item nahi mila. Food Menu me items add karein.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: constraints.maxWidth < 500 ? 1 : 2,
                            childAspectRatio: constraints.maxWidth < 500 ? 3.5 : 2.2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final food = filteredItems[index];
                            return InkWell(
                              onTap: () {
                                ref.read(enterpriseBillingProvider.notifier).addItem(food);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1422),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF26334D)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      food.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${food.price.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );

        // ── RIGHT CARD: BILL SUMMARY & CHECKOUT ──
        final rightCard = Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${billingState.selectedTable} ka bill',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (cart.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                ref.read(enterpriseBillingProvider.notifier).clearCurrentTableCart();
                              },
                              icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.redAccent),
                              label: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (cart.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'Item chunke bill shuru karo.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      else ...[
                        // Cart item list
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cart.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xFF26334D), height: 16),
                          itemBuilder: (context, index) {
                            final item = cart[index];
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                      Text('₹${item.price.toStringAsFixed(0)} each', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF94A3B8), size: 18),
                                      onPressed: () => ref.read(enterpriseBillingProvider.notifier).decrementItem(item),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981), size: 18),
                                      onPressed: () => ref.read(enterpriseBillingProvider.notifier).incrementItem(item),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${item.total.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      const Divider(color: Color(0xFF26334D)),
                      const SizedBox(height: 8),

                      // Subtotal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                          Text('₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // GST
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('GST ${profile.gstPercent.toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                          Text('₹${gstAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Payment Buttons (Cash & UPI QR)
                      Row(
                        children: [
                          // Cash Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: cart.isEmpty
                                  ? null
                                  : () async {
                                      final bill = await ref.read(enterpriseBillingProvider.notifier).checkoutBill(
                                        'Cash',
                                        profile.gstPercent,
                                        profile.billPrefix,
                                      );
                                      if (context.mounted) {
                                        _showReceiptDialog(context, bill, profile);
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF26334D)),
                                backgroundColor: const Color(0xFF0F1422),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Cash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // UPI QR Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: cart.isEmpty
                                  ? null
                                  : () {
                                      _showUpiQrDialog(context, ref, profile, billingState);
                                    },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF26334D)),
                                backgroundColor: const Color(0xFF0F1422),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('UPI QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: leftCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: rightCard),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftCard,
                    const SizedBox(height: 20),
                    rightCard,
                  ],
                ),
        );
      },
    );
  }
}

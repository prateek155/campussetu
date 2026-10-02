// lib/features/enterprise/screens/enterprise_inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/enterprise_models.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseInventoryScreen extends ConsumerWidget {
  const EnterpriseInventoryScreen({super.key});

  void _showAddEditInventoryDialog(BuildContext context, WidgetRef ref, [InventoryItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.itemName ?? '');
    final qtyCtrl = TextEditingController(text: existing != null ? existing.quantity.toStringAsFixed(0) : '10');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    final dateCtrl = TextEditingController(
      text: existing?.purchaseDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing != null ? 'Edit Inventory Item' : 'Add Inventory Item',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Item Name (e.g. Dosa Batter, Paneer)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F1422),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Quantity (kg/pcs/packs)',
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
                  labelText: 'Total Cost Amount (₹)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F1422),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vendorCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Kisse Kharida (Vendor / Supplier Name)',
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
                  labelText: 'Purchase Date (YYYY-MM-DD)',
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
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              final vendor = vendorCtrl.text.trim();
              final date = dateCtrl.text.trim();

              if (name.isEmpty) return;

              if (existing != null) {
                ref.read(enterpriseInventoryProvider.notifier).updateItem(
                  InventoryItem(
                    id: existing.id,
                    itemName: name,
                    quantity: qty,
                    amount: amount,
                    vendor: vendor,
                    purchaseDate: date.isNotEmpty ? date : existing.purchaseDate,
                  ),
                );
              } else {
                ref.read(enterpriseInventoryProvider.notifier).addItem(name, qty, amount, vendor, date);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: Text(existing != null ? 'Update Item' : 'Add Item'),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog(BuildContext context, WidgetRef ref) {
    final textCtrl = TextEditingController(
      text: 'Milk, 20, 1200, Amul Dairy, 2026-10-02\nCheese, 5, 850, Metro Mart, 2026-10-02\nCooking Oil, 15, 2100, Fortune, 2026-10-02',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Import Inventory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Har line me ek item likhein:\n"Item Name, Quantity, Cost, Vendor, Date"',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 8,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Item Name, Quantity, Cost, Vendor, Date',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  filled: true,
                  fillColor: const Color(0xFF0F1422),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
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
              final lines = textCtrl.text.split('\n');
              final newItems = <InventoryItem>[];
              final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

              for (final line in lines) {
                final parts = line.split(',');
                if (parts.length >= 2) {
                  final name = parts[0].trim();
                  final qty = double.tryParse(parts[1].trim()) ?? 1.0;
                  final cost = parts.length >= 3 ? (double.tryParse(parts[2].trim()) ?? 0.0) : 0.0;
                  final vendor = parts.length >= 4 ? parts[3].trim() : 'Supplier';
                  final date = parts.length >= 5 ? parts[4].trim() : todayStr;

                  if (name.isNotEmpty) {
                    newItems.add(InventoryItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString() + newItems.length.toString(),
                      itemName: name,
                      quantity: qty,
                      amount: cost,
                      vendor: vendor,
                      purchaseDate: date,
                    ));
                  }
                }
              }

              if (newItems.isNotEmpty) {
                ref.read(enterpriseInventoryProvider.notifier).bulkImport(newItems);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${newItems.length} inventory items bulk import ho gaye!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Import All'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, InventoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Inventory Item?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Kya aap sach me "${item.itemName}" ko inventory se delete karna chahte hain?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(enterpriseInventoryProvider.notifier).deleteItem(item.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.itemName} delete ho gaya.'),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(enterpriseInventoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Container with responsive buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF171E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26334D)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory Management',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'serif',
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Stock track karein, low stock alert dekhein aur bulk import karein',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (!isNarrow) ...[
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showBulkImportDialog(context, ref),
                                icon: const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF10B981)),
                                label: const Text('Bulk Import', style: TextStyle(color: Color(0xFF10B981))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF10B981)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditInventoryDialog(context, ref),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Stock'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (isNarrow) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showBulkImportDialog(context, ref),
                            icon: const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF10B981)),
                            label: const Text('Bulk Import', style: TextStyle(color: Color(0xFF10B981))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditInventoryDialog(context, ref),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Stock'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
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
          ),
          const SizedBox(height: 20),

          // Inventory List
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF171E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26334D)),
            ),
            child: inventory.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const Text('Abhi koi inventory item add nahi hua hai.', style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: inventory.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF26334D)),
                    itemBuilder: (context, index) {
                      final item = inventory[index];
                      final isLowStock = item.quantity <= 5;

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
                                    color: const Color(0xFF0F1422),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                                    color: isLowStock ? Colors.orangeAccent : const Color(0xFF10B981),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.itemName,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isLowStock) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Kam Stock', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Vendor: ${item.vendor.isNotEmpty ? item.vendor : "Self"} • Date: ${item.purchaseDate}',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isCompact) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock: ${item.quantity.toStringAsFixed(0)} • Cost: ₹${item.amount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: isLowStock ? Colors.orangeAccent : const Color(0xFF10B981),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!isCompact) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.quantity.toStringAsFixed(0)} in stock',
                                        style: TextStyle(
                                          color: isLowStock ? Colors.orangeAccent : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text('Cost: ₹${item.amount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 18),
                                      tooltip: 'Edit Item',
                                      onPressed: () => _showAddEditInventoryDialog(context, ref, item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                      tooltip: 'Delete Item',
                                      onPressed: () => _confirmDelete(context, ref, item),
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
}

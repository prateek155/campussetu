// lib/features/enterprise/screens/enterprise_food_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enterprise_models.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseFoodMenuScreen extends ConsumerStatefulWidget {
  const EnterpriseFoodMenuScreen({super.key});

  @override
  ConsumerState<EnterpriseFoodMenuScreen> createState() => _EnterpriseFoodMenuScreenState();
}

class _EnterpriseFoodMenuScreenState extends ConsumerState<EnterpriseFoodMenuScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  void _showAddEditItemDialog([FoodItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? 'Main');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing != null ? 'Edit Food Item' : 'Add Food Item',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Food Name',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF0F1422),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: catCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Category (e.g. Nashta, Main, Drinks, Meetha)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF0F1422),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Price (₹)',
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
              final cat = catCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty) return;

              if (existing != null) {
                ref.read(enterpriseFoodMenuProvider.notifier).updateItem(
                  FoodItem(id: existing.id, name: name, category: cat.isEmpty ? 'Main' : cat, price: price),
                );
              } else {
                ref.read(enterpriseFoodMenuProvider.notifier).addItem(name, cat, price);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: Text(existing != null ? 'Update' : 'Add Item'),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog() {
    final textCtrl = TextEditingController(
      text: 'Veg Biryani, Main, 180\nCold Coffee, Drinks, 60\nPaneer Tikka, Nashta, 150',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Import Food Items', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Har line me ek item likhein: "Name, Category, Price"',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 8,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Item Name, Category, Price',
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
              final newItems = <FoodItem>[];
              for (final line in lines) {
                final parts = line.split(',');
                if (parts.length >= 2) {
                  final name = parts[0].trim();
                  final cat = parts.length >= 3 ? parts[1].trim() : 'Main';
                  final price = double.tryParse(parts.last.trim()) ?? 0.0;
                  if (name.isNotEmpty) {
                    newItems.add(FoodItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString() + newItems.length.toString(),
                      name: name,
                      category: cat,
                      price: price,
                    ));
                  }
                }
              }
              if (newItems.isNotEmpty) {
                ref.read(enterpriseFoodMenuProvider.notifier).bulkImport(newItems);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${newItems.length} items bulk import ho gaye!'),
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

  @override
  Widget build(BuildContext context) {
    final foodItems = ref.watch(enterpriseFoodMenuProvider);

    // Get unique categories
    final categories = {'All', ...foodItems.map((e) => e.category).where((c) => c.isNotEmpty)};

    final filtered = foodItems.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || item.category.toLowerCase() == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Action Bar
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Food Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showBulkImportDialog,
                          icon: const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF10B981)),
                          label: const Text('Bulk Import', style: TextStyle(color: Color(0xFF10B981))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditItemDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Food Item'),
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
                ),
                const SizedBox(height: 16),

                // Search & Filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search food item...',
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
                    const SizedBox(width: 12),
                    // Category dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1422),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF26334D)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: categories.contains(_selectedCategory) ? _selectedCategory : 'All',
                          dropdownColor: const Color(0xFF171E30),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedCategory = v);
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

          // Items Table / List
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
                    child: const Text('Koi item nahi mila.', style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF26334D)),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1422),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.fastfood_rounded, color: Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF064E3B),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(item.category, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 18),
                            onPressed: () => _showAddEditItemDialog(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            onPressed: () {
                              ref.read(enterpriseFoodMenuProvider.notifier).deleteItem(item.id);
                            },
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
}

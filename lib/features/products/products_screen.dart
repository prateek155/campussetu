import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_chip.dart';
import '../../core/widgets/neu_text_field.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final key = '$_selectedCategory|${_searchCtrl.text}';
    final asyncProducts = ref.watch(productsProvider(key));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Marketplace', style: AppTypography.soraDisplay(size: 26)), Row(children: [const Icon(Icons.location_on_rounded, size: 14, color: AppColors.cyanDeep), const SizedBox(width: 4), Text('City-locked listings', style: AppTypography.interCaption(color: AppColors.cyanDeep))])]),
                const Spacer(),
                NeuCard(padding: const EdgeInsets.all(12), onTap: () => _showSellSheet(context), child: Row(children: [const Icon(Icons.add_rounded, size: 18, color: AppColors.cyanDeep), const SizedBox(width: 6), Text('Sell', style: AppTypography.interLabel(color: AppColors.cyanDeep))])),
              ]),
              const SizedBox(height: 16),
              NeuTextField(hint: '🔍  Search products...', controller: _searchCtrl, onChanged: (_) => setState(() {}), prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkSoft, size: 20)),
              const SizedBox(height: 12),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['All', 'Books', 'Electronics', 'Services', 'Clothing', 'Other'].map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: NeuChip(label: c, isSelected: _selectedCategory == c, onTap: () => setState(() => _selectedCategory = c)))).toList())),
            ]),
          ),
          Expanded(
            child: asyncProducts.when(
              data: (products) {
                if (products.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32), child: NeuCard(padding: const EdgeInsets.all(24), child: Column(children: [Icon(Icons.shopping_bag_outlined, size: 40, color: AppColors.inkSoft), const SizedBox(height: 12), Text('No products found', style: AppTypography.soraHeading3()), Text('Try different category', style: AppTypography.interCaption())]))));
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsProvider(key)),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
                    itemCount: products.length,
                    itemBuilder: (ctx, i) => _ProductTile(product: products[i]).animate(delay: (i * 50).ms).fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95)),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Failed', style: AppTypography.interBody(color: AppColors.error)), Text(e.toString(), style: AppTypography.interCaption()), const SizedBox(height: 12), GestureDetector(onTap: () => ref.invalidate(productsProvider(key)), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.cyanDeep, borderRadius: BorderRadius.circular(10)), child: Text('Retry', style: AppTypography.interLabel(color: Colors.white))))])),
            ),
          ),
        ]),
      ),
    );
  }

  void _showSellSheet(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => Container(margin: const EdgeInsets.all(16), padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.neuRaisedShadows), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.shadowDark, borderRadius: BorderRadius.circular(2)))), const SizedBox(height: 20), Text('List an Item', style: AppTypography.soraHeading3()), const SizedBox(height: 16), const NeuTextField(hint: 'Item title', label: 'Title'), const SizedBox(height: 12), const NeuTextField(hint: 'Describe your item...', label: 'Description', maxLines: 3), const SizedBox(height: 12), const NeuTextField(hint: '₹ 0', label: 'Price', keyboardType: TextInputType.number), const SizedBox(height: 20), Container(width: double.infinity, height: 54, decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: Text('Post Listing', style: AppTypography.interButton(color: Colors.white)))]))));
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductTile({required this.product});
  @override
  Widget build(BuildContext context) {
    final title = (product['title'] ?? '').toString();
    final desc = (product['description'] ?? '').toString();
    final price = product['price'] != null ? '₹${product['price']}' : (product['price'] ?? '').toString();
    final category = (product['category'] ?? 'Other').toString();
    Color catColor = AppColors.cyanDeep;
    if (category == 'Electronics') catColor = AppColors.warning;
    if (category == 'Services') catColor = AppColors.success;
    return NeuCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 80, decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Center(child: Icon(_icon(category), color: catColor, size: 36))),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(category, style: AppTypography.interBadge(color: catColor))),
        const SizedBox(height: 6),
        Text(title, style: AppTypography.interButton(color: AppColors.ink, size: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(desc, style: AppTypography.interCaption(), maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Row(children: [Text(price, style: AppTypography.monoCode(size: 15, weight: FontWeight.w700, color: AppColors.ink)), const Spacer(), Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white))]),
      ]),
    );
  }

  IconData _icon(String cat) {
    switch (cat) {
      case 'Books': return Icons.menu_book_rounded;
      case 'Electronics': return Icons.devices_rounded;
      case 'Services': return Icons.handshake_outlined;
      case 'Clothing': return Icons.checkroom_rounded;
      default: return Icons.shopping_bag_outlined;
    }
  }
}

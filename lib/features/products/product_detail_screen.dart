// lib/features/products/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/user_avatar.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: NeuCard(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.ink),
          ),
        ),
        title: Text('Item Details', style: AppTypography.soraHeading3()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: AppColors.cyanDeep.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, size: 64, color: AppColors.cyanDeep),
              ),
            ),
            const SizedBox(height: 20),
            Text('DSA Handwritten Notes', style: AppTypography.soraHeading2()),
            const SizedBox(height: 8),
            Text('₹150', style: AppTypography.monoDisplay(size: 28, color: AppColors.ink)),
            const SizedBox(height: 16),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const UserAvatar(name: 'Rahul V.', size: 44),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rahul Verma', style: AppTypography.interButton(color: AppColors.ink)),
                  Text('IIT Delhi · Delhi', style: AppTypography.interCaption()),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(10)),
                  child: Text('Chat', style: AppTypography.interCaption(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Description', style: AppTypography.soraHeading3()),
            const SizedBox(height: 8),
            Text(
              'Complete DSA notes covering all topics for placements — Arrays, Linked Lists, Trees, Graphs, DP, and more. 200+ pages, handwritten and well-organised.',
              style: AppTypography.interBody(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

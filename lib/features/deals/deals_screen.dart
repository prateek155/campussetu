// lib/features/deals/deals_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/deal_model.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

final dealsProvider = FutureProvider.autoDispose<List<DealModel>>((ref) async {
  final res = await ApiService().getDeals();
  return res.map((d) => DealModel.fromJson(d)).toList();
});

class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealsAsync = ref.watch(dealsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Campus Deals', style: AppTypography.soraHeading3()),
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      body: dealsAsync.when(
        data: (deals) {
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(dealsProvider.future),
            color: AppColors.cyanDeep,
            child: deals.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 200),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_offer_outlined, size: 64, color: AppColors.inkSoft),
                          const SizedBox(height: 16),
                          Text('No offers right now', style: AppTypography.soraHeading3()),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for exclusive student deals!',
                            style: AppTypography.interBody(color: AppColors.inkSoft),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: deals.length,
              itemBuilder: (context, i) {
                final d = deals[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: NeuCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (d.bannerUrl != null && d.bannerUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: d.bannerUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (context, _, __) => Container(
                                height: 140,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(d.title, style: AppTypography.soraHeading3()),
                        const SizedBox(height: 6),
                        Text(d.description, style: AppTypography.interBody(height: 1.5)),
                        if (d.discountCode != null && d.discountCode!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_offer, size: 16, color: AppColors.success),
                                const SizedBox(width: 8),
                                Text(
                                  d.discountCode!,
                                  style: AppTypography.monoCode(
                                    color: AppColors.success,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyanDeep)),
        error: (e, _) => Center(
          child: Text('Error loading deals: $e', style: AppTypography.interBody(color: AppColors.error)),
        ),
      ),
    );
  }
}

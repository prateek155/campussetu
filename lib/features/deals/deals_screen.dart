// lib/features/deals/deals_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/deal_model.dart';
import '../../core/services/api_service.dart';
import '../../core/providers/app_providers.dart';
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    if (width >= 650) {
                      final cols = width >= 1050 ? 3 : 2;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: deals.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 310,
                            ),
                            itemBuilder: (context, i) =>
                                _buildDealCard(context, deals[i], isWeb: true),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: deals.length,
                      itemBuilder: (context, i) =>
                          _buildDealCard(context, deals[i]),
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

  Widget _buildDealCard(BuildContext context, DealModel d, {bool isWeb = false}) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      margin: isWeb ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.bannerUrl != null && d.bannerUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: d.bannerUrl!,
                height: isWeb ? 120 : 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (context, _, __) => Container(
                  height: isWeb ? 120 : 140,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            d.title,
            style: AppTypography.soraHeading3(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            d.description,
            style: AppTypography.interBody(height: 1.4, color: AppColors.inkSoft),
            maxLines: isWeb ? 2 : 4,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Show the user's dealCode here
          Consumer(
            builder: (context, ref, child) {
              final meAsync = ref.watch(currentUserProvider);
              return meAsync.when(
                data: (me) {
                  if (me.dealCode == null) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cyanDeep.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cyanDeep.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code, size: 16, color: AppColors.cyanDeep),
                        const SizedBox(width: 8),
                        Text(
                          'Show Code: ${me.dealCode}',
                          style: AppTypography.monoCode(
                            color: AppColors.cyanDeep,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// lib/features/flatmates/flatmates_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/models/flatmate_model.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

final flatmatesProvider = FutureProvider.autoDispose<List<FlatmateModel>>((ref) async {
  final res = await ApiService().getFlatmates();
  final data = res['data'] as List? ?? [];
  return data.map((d) => FlatmateModel.fromJson(d)).toList();
});

class FlatmatesScreen extends ConsumerWidget {
  const FlatmatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flatmatesAsync = ref.watch(flatmatesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Flatmates & Rooms', style: AppTypography.soraHeading3()),
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      body: flatmatesAsync.when(
        data: (flatmates) {
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(flatmatesProvider.future),
            color: AppColors.cyanDeep,
            child: flatmates.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 200),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_work_outlined, size: 64, color: AppColors.inkSoft),
                            const SizedBox(height: 16),
                            Text('No listings yet', style: AppTypography.soraHeading3()),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to list a room or find flatmates!',
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
                    itemCount: flatmates.length,
                    itemBuilder: (context, i) {
                      final f = flatmates[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: NeuCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User Info Row
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    backgroundImage: f.avatar != null ? CachedNetworkImageProvider(f.avatar!) : null,
                                    child: f.avatar == null ? const Icon(Icons.person, color: AppColors.primary) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f.posterName ?? 'Unknown', style: AppTypography.interBody(weight: FontWeight.w600)),
                                        Text(timeago.format(f.createdAt), style: AppTypography.interLabel(color: AppColors.inkSoft)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Main Post Info
                              Text(f.name, style: AppTypography.soraHeading3()),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: AppColors.error),
                                  const SizedBox(width: 4),
                                  Text(f.place, style: AppTypography.interBody(color: AppColors.ink)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 16, color: AppColors.info),
                                  const SizedBox(width: 4),
                                  Text('${f.numPersons} needed', style: AppTypography.interBody(color: AppColors.ink)),
                                ],
                              ),
                              
                              if (f.description != null && f.description!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(f.description!, style: AppTypography.interBody(height: 1.5)),
                              ],
                              
                              // Images
                              if (f.photoUrl1 != null || f.photoUrl2 != null) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 140,
                                  child: Row(
                                    children: [
                                      if (f.photoUrl1 != null)
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: f.photoUrl1!,
                                              fit: BoxFit.cover,
                                              height: 140,
                                              errorWidget: (context, _, __) => Container(color: Colors.grey[200]),
                                            ),
                                          ),
                                        ),
                                      if (f.photoUrl1 != null && f.photoUrl2 != null)
                                        const SizedBox(width: 8),
                                      if (f.photoUrl2 != null)
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: f.photoUrl2!,
                                              fit: BoxFit.cover,
                                              height: 140,
                                              errorWidget: (context, _, __) => Container(color: Colors.grey[200]),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      f.contactNumber,
                                      style: AppTypography.monoCode(
                                        color: AppColors.primary,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
          child: Text('Error loading flats: $e', style: AppTypography.interBody(color: AppColors.error)),
        ),
      ),
    );
  }
}

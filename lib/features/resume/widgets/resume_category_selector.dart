import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/resume_category.dart';
import '../templates/resume_template_registry.dart';

/// Interactive Canva-style category selector for filtering resume designs.
///
/// Supports filtering between:
/// - null (All designs)
/// - [ResumeCategory.professional] (💼 Professional)
/// - [ResumeCategory.designed] (🎨 Designed)
/// - [ResumeCategory.modern] (⚡ Modern)
class ResumeCategorySelector extends StatelessWidget {
  final ResumeCategory? selectedCategory;
  final ValueChanged<ResumeCategory?> onCategoryChanged;

  const ResumeCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final registry = ResumeTemplateRegistry.instance;
    final totalCount = registry.count();
    final profCount = registry.count(category: ResumeCategory.professional);
    final desCount = registry.count(category: ResumeCategory.designed);
    final modCount = registry.count(category: ResumeCategory.modern);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal scrolling category pill bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildPill(
                label: 'All Designs',
                emoji: '✨',
                count: totalCount,
                isSelected: selectedCategory == null,
                onTap: () => onCategoryChanged(null),
              ),
              const SizedBox(width: 8),
              _buildPill(
                label: ResumeCategory.professional.label,
                emoji: ResumeCategory.professional.emoji,
                count: profCount,
                isSelected: selectedCategory == ResumeCategory.professional,
                onTap: () => onCategoryChanged(ResumeCategory.professional),
              ),
              const SizedBox(width: 8),
              _buildPill(
                label: ResumeCategory.designed.label,
                emoji: ResumeCategory.designed.emoji,
                count: desCount,
                isSelected: selectedCategory == ResumeCategory.designed,
                onTap: () => onCategoryChanged(ResumeCategory.designed),
              ),
              const SizedBox(width: 8),
              _buildPill(
                label: ResumeCategory.modern.label,
                emoji: ResumeCategory.modern.emoji,
                count: modCount,
                isSelected: selectedCategory == ResumeCategory.modern,
                onTap: () => onCategoryChanged(ResumeCategory.modern),
              ),
            ],
          ),
        ),

        // Explanatory banner for selected category
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildCategoryDescriptionBanner(selectedCategory),
        ),
      ],
    );
  }

  Widget _buildPill({
    required String label,
    required String emoji,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyanDeep : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.cyanDeep
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.cyanDeep.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  const BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDescriptionBanner(ResumeCategory? category) {
    if (category == null) {
      return Container(
        key: const ValueKey('all_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing all curated templates. Filter by Professional, Designed, or Modern to find your exact match.',
                style: AppTypography.interCaption(color: const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: ValueKey(category.id),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cyanDeep.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cyanDeep.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(category.icon, size: 16, color: AppColors.cyanDeep),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category.emoji} ${category.label} — ${category.tagline}',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.description,
                  style: AppTypography.interCaption(color: const Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

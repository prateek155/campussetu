// lib/core/widgets/neu_chip.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Neumorphic filter/selection chip
class NeuChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? selectedColor;

  const NeuChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = selectedColor ?? AppColors.cyanDeep;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.4) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected ? [] : AppColors.neuSmallShadows,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.interLabel(
                color: isSelected ? activeColor : AppColors.inkSoft,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header — label + optional "See All" action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.soraHeading3()),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: AppTypography.interLabel(color: AppColors.cyanDeep)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

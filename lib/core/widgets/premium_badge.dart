// lib/core/widgets/premium_badge.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Premium badge — DarkTile style pill with gold/cyan glow
class PremiumBadge extends StatelessWidget {
  final String label;
  final bool isSmall;

  const PremiumBadge({super.key, this.label = 'PRO', this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB800), Color(0xFFFF6B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTypography.interBadge(color: Colors.white).copyWith(
          fontSize: isSmall ? 9 : 11,
        ),
      ),
    );
  }
}

/// Verified badge
class VerifiedBadge extends StatelessWidget {
  final bool isSmall;

  const VerifiedBadge({super.key, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 10,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.cyanDeep.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyanDeep.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: isSmall ? 10 : 12, color: AppColors.cyanDeep),
          const SizedBox(width: 3),
          Text(
            'Verified',
            style: AppTypography.interBadge(color: AppColors.cyanDeep).copyWith(
              fontSize: isSmall ? 9 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

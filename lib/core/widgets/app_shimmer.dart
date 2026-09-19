// lib/core/widgets/app_shimmer.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// Shimmer loading placeholder with neumorphic style
class AppShimmer extends StatelessWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shadowDark,
      highlightColor: AppColors.shadowLight,
      child: child,
    );
  }
}

class ShimmerCard extends StatelessWidget {
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.borderRadius = 24,
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.shadowDark,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

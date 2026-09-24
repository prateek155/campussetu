// lib/core/widgets/neu_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Raised neumorphic card — default container for most content.
/// Background matches page bg; dual soft shadows create "raised" illusion.
class NeuCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final VoidCallback? onTap;
  final List<BoxShadow>? customShadows;
  final double? width;
  final double? height;
  final Alignment? alignment;

  const NeuCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
    this.onTap,
    this.customShadows,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: color ?? (isDark ? const Color(0xFF1B1F2E) : Colors.white),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? const Color(0xFF30364A) : const Color(0xFFE5E9EF),
      ),
      boxShadow: customShadows ?? [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.045),
          blurRadius: isDark ? 16 : 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

    final container = Container(
      width: width,
      height: height,
      alignment: alignment,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 120),
          child: container,
        ),
      );
    }
    return container;
  }
}

/// Tappable NeuCard with press animation.
class NeuButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? width;
  final double? height;

  const NeuButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.color,
    this.width,
    this.height,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color ?? AppColors.bg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _pressed ? AppColors.neuInsetShadows : AppColors.neuRaisedShadows,
        ),
        child: widget.child,
      ),
    );
  }
}

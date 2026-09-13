// lib/core/widgets/dark_tile.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Dark glow tile — reserved for premium content, Tshare code display,
/// authenticating states, and key moments needing visual weight.
/// Cyan glow ONLY appears inside dark tiles, never on light background.
class DarkTile extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool showGlow;
  final double glowIntensity;
  final double? width;
  final double? height;
  final Alignment? alignment;

  const DarkTile({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.showGlow = true,
    this.glowIntensity = 0.2,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      gradient: AppColors.darkTileGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: showGlow
          ? [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: glowIntensity),
                blurRadius: 28,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
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
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}

/// Glowing text styled for dark tiles — uses cyan with text-shadow glow effect
class GlowText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Color glowColor;
  final double glowRadius;

  const GlowText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.glowColor = AppColors.cyan,
    this.glowRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: (style ?? const TextStyle()).copyWith(
        color: glowColor,
        shadows: [
          Shadow(color: glowColor.withValues(alpha: 0.8), blurRadius: glowRadius),
          Shadow(color: glowColor.withValues(alpha: 0.4), blurRadius: glowRadius * 2),
        ],
      ),
    );
  }
}

/// Animated pulsing glow dot — used as status indicator in dark tiles
class GlowDot extends StatefulWidget {
  final Color color;
  final double size;

  const GlowDot({super.key, this.color = AppColors.cyan, this.size = 8});

  @override
  State<GlowDot> createState() => _GlowDotState();
}

class _GlowDotState extends State<GlowDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _pulse.value * 0.8),
              blurRadius: widget.size * 2,
              spreadRadius: widget.size * 0.3,
            ),
          ],
        ),
      ),
    );
  }
}

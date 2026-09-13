// lib/core/widgets/ring_progress.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Donut/ring progress indicator — used for profile completion, contribution score.
/// Matches the "widget" feel from the spec.
class RingProgress extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;
  final Widget? centerChild;
  final String? centerLabel;
  final bool animate;

  RingProgress({
    super.key,
    required this.progress,
    this.size = 80,
    this.strokeWidth = 8,
    this.progressColor = AppColors.cyanDeep,
    Color? trackColor,
    this.centerChild,
    this.centerLabel,
    this.animate = true,
  }) : trackColor = trackColor ?? AppColors.shadowDark;

  @override
  State<RingProgress> createState() => _RingProgressState();
}

class _RingProgressState extends State<RingProgress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(RingProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(begin: _animation.value, end: widget.progress).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(
            progress: widget.animate ? _animation.value : widget.progress,
            strokeWidth: widget.strokeWidth,
            progressColor: widget.progressColor,
            trackColor: widget.trackColor,
          ),
          child: Center(
            child: widget.centerChild ??
                (widget.centerLabel != null
                    ? Text(
                        widget.centerLabel!,
                        style: AppTypography.monoCode(
                          size: widget.size * 0.2,
                          color: AppColors.ink,
                          weight: FontWeight.w700,
                        ),
                      )
                    : Text(
                        '${((widget.animate ? _animation.value : widget.progress) * 100).round()}%',
                        style: AppTypography.monoCode(
                          size: widget.size * 0.18,
                          color: AppColors.ink,
                          weight: FontWeight.w700,
                        ),
                      )),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // top

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + 2 * math.pi * progress,
        colors: [progressColor, progressColor.withValues(alpha: 0.7)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.progressColor != progressColor;
}

/// Energy ring with gradient — used for profile contribution score
class EnergyRing extends StatelessWidget {
  final double progress;
  final double size;
  final Widget? centerChild;

  const EnergyRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.centerChild,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: size + 16,
          height: size + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.cyanDeep.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
        RingProgress(
          progress: progress,
          size: size,
          strokeWidth: 10,
          progressColor: AppColors.cyanDeep,
          trackColor: AppColors.shadowDark,
          centerChild: centerChild,
        ),
      ],
    );
  }
}

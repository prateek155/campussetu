// lib/features/admin/widgets/admin_toast.dart
import 'dart:async';
import 'package:flutter/material.dart';

enum AdminToastType { success, error, warning, info }

class AdminToast {
  static OverlayEntry? _activeEntry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    AdminToastType type = AdminToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    _timer?.cancel();
    if (_activeEntry != null && _activeEntry!.mounted) {
      _activeEntry!.remove();
    }
    _activeEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlayWidget(
        message: message,
        type: type,
        onDismiss: () {
          _timer?.cancel();
          if (_activeEntry == entry) {
            if (entry.mounted) {
              entry.remove();
            }
            _activeEntry = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, () {
      if (_activeEntry == entry) {
        if (entry.mounted) {
          entry.remove();
        }
        _activeEntry = null;
      }
    });
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, type: AdminToastType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: AdminToastType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, type: AdminToastType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: AdminToastType.info);
  }
}

class _ToastOverlayWidget extends StatefulWidget {
  final String message;
  final AdminToastType type;
  final VoidCallback onDismiss;

  const _ToastOverlayWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlayWidget> createState() => _ToastOverlayWidgetState();
}

class _ToastOverlayWidgetState extends State<_ToastOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    IconData icon;

    switch (widget.type) {
      case AdminToastType.error:
        accentColor = const Color(0xFFEF4444);
        icon = Icons.error_outline_rounded;
        break;
      case AdminToastType.warning:
        accentColor = const Color(0xFFF59E0B);
        icon = Icons.warning_amber_rounded;
        break;
      case AdminToastType.info:
        accentColor = const Color(0xFF38BDF8);
        icon = Icons.info_outline_rounded;
        break;
      case AdminToastType.success:
        accentColor = const Color(0xFF10B981);
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    final topPadding = MediaQuery.of(context).padding.top + 16;

    return Positioned(
      top: topPadding,
      left: 20, // Upper side left!
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1524),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Short, jitna msg ho utna hi!
                  children: [
                    Icon(icon, color: accentColor, size: 18),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Color(0xFFF1F5F9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

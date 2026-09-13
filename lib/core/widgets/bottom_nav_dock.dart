// lib/core/widgets/bottom_nav_dock.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });

  NavItem copyWith({int? badgeCount}) => NavItem(icon: icon, activeIcon: activeIcon, label: label, badgeCount: badgeCount ?? this.badgeCount);
}

/// Floating pill-shaped bottom nav dock — fully rounded, with margin from edges.
/// Sits above screen edges as a floating element, not edge-to-edge.
class BottomNavDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  const BottomNavDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark,
              offset: const Offset(6, 6),
              blurRadius: 16,
            ),
            BoxShadow(
              color: AppColors.shadowLight,
              offset: const Offset(-6, -6),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            items.length,
            (index) => _NavDockItem(
              item: items[index],
              isActive: index == currentIndex,
              onTap: () => onTap(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDockItem extends StatefulWidget {
  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavDockItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavDockItem> createState() => _NavDockItemState();
}

class _NavDockItemState extends State<_NavDockItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isActive ? AppColors.cyanDeep.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.isActive ? widget.item.activeIcon : widget.item.icon, color: widget.isActive ? AppColors.cyanDeep : AppColors.inkSoft, size: 22),
                  ),
                  if (widget.item.badgeCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.bg, width: 1.5)),
                        alignment: Alignment.center,
                        child: Text(widget.item.badgeCount > 99 ? '99+' : '${widget.item.badgeCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.interCaption(
                  color: widget.isActive ? AppColors.cyanDeep : AppColors.inkSoft,
                ).copyWith(
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(widget.item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

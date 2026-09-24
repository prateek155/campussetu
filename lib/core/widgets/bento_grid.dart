// lib/core/widgets/bento_grid.dart
//
// Reusable bento layout. Give it a list of BentoTile and it packs them into a
// 4-column grid (first free slot wins), so tiles never leave holes.
//
//   BentoGrid(tiles: [
//     BentoTile(id: 'a', kind: BentoKind.wide, w: 2, h: 1, icon: Icons.star, color: Colors.orange, title: 'Hello', subtitle: 'World'),
//     ...
//   ])
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum BentoKind {
  feature, // big number + label (use with w:2, h:2)
  wide, // icon left, text right (w:2 or w:4, h:1)
  small, // icon + title (w:1, h:1)
  dark, // dark strip with accent icon (w:4, h:1)
  custom, // you provide the content through `builder`
}

class BentoTile {
  final String id;
  final BentoKind kind;
  final int w;
  final int h;
  final Color color;
  final IconData? icon;
  final String title;
  final String subtitle;
  final String? count; // pill top-right (or the big number on a feature tile)
  final String? badge; // static pill, e.g. PRO
  final String? bigLabel; // small label under the big number on a feature tile
  final VoidCallback? onTap;
  final Color? fill; // solid background (custom / hero tiles)
  final WidgetBuilder? builder; // content for BentoKind.custom
  final bool dismissible; // always show the × button (calls BentoGrid.onHide)

  const BentoTile({
    required this.id,
    required this.kind,
    required this.w,
    required this.h,
    required this.color,
    this.icon,
    this.title = '',
    this.subtitle = '',
    this.count,
    this.badge,
    this.bigLabel,
    this.onTap,
    this.fill,
    this.builder,
    this.dismissible = false,
  });
}

class _Placed {
  final BentoTile tile;
  final int row;
  final int col;
  const _Placed(this.tile, this.row, this.col);
}

List<_Placed> _pack(List<BentoTile> tiles) {
  const cols = 4;
  final grid = <List<bool>>[];

  bool fits(int r, int c, int w, int h) {
    for (var y = r; y < r + h; y++) {
      if (y >= grid.length) continue;
      for (var x = c; x < c + w; x++) {
        if (grid[y][x]) return false;
      }
    }
    return true;
  }

  void mark(int r, int c, int w, int h) {
    while (grid.length < r + h) {
      grid.add(List<bool>.filled(cols, false));
    }
    for (var y = r; y < r + h; y++) {
      for (var x = c; x < c + w; x++) {
        grid[y][x] = true;
      }
    }
  }

  final out = <_Placed>[];
  for (final t in tiles) {
    // Invalid spans cannot fit the fixed four-column grid. Ignore them rather
    // than letting the placement loop run forever for a malformed tile.
    if (t.w < 1 || t.w > cols || t.h < 1) continue;
    var placed = false;
    var r = 0;
    while (!placed) {
      for (var c = 0; c + t.w <= cols; c++) {
        if (fits(r, c, t.w, t.h)) {
          mark(r, c, t.w, t.h);
          out.add(_Placed(t, r, c));
          placed = true;
          break;
        }
      }
      if (!placed) r++;
    }
  }
  return out;
}

class BentoGrid extends StatelessWidget {
  final List<BentoTile> tiles;
  final double gap;
  final double rowHeight;
  final bool editing; // shows a × on every tile
  final void Function(String id)? onHide;

  const BentoGrid({
    super.key,
    required this.tiles,
    this.gap = 10,
    this.rowHeight = 96,
    this.editing = false,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.maxWidth.isFinite || box.maxWidth <= gap * 3) {
          return const SizedBox.shrink();
        }
        final cellW = (box.maxWidth - gap * 3) / 4;
        final placed = _pack(tiles);
        var rows = 0;
        for (final p in placed) {
          final end = p.row + p.tile.h;
          if (end > rows) rows = end;
        }
        final height = rows * rowHeight + (rows - 1) * gap;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (final p in placed)
                AnimatedPositioned(
                  key: ValueKey(p.tile.id),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: p.col * (cellW + gap),
                  top: p.row * (rowHeight + gap),
                  width: p.tile.w * cellW + (p.tile.w - 1) * gap,
                  height: p.tile.h * rowHeight + (p.tile.h - 1) * gap,
                  child: _BentoTileView(
                    tile: p.tile,
                    editing: editing,
                    onHide: onHide == null ? null : () => onHide!(p.tile.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BentoTileView extends StatelessWidget {
  final BentoTile tile;
  final bool editing;
  final VoidCallback? onHide;

  const _BentoTileView({required this.tile, required this.editing, this.onHide});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Color.lerp(tile.color, Colors.white, 0.35)! : tile.color;
    final surface = isDark ? const Color(0xFF1B1F2E) : Colors.white;

    Color bg = Color.alphaBlend(accent.withValues(alpha: isDark ? 0.18 : 0.15), surface);
    Color fg = AppColors.ink;
    Color sub = AppColors.inkSoft;
    Color iconBg = accent;
    Color iconFg = isDark ? const Color(0xFF12141F) : Colors.white;
    Color borderColor = accent.withValues(alpha: isDark ? 0.30 : 0.22);

    if (tile.kind == BentoKind.dark) {
      bg = AppColors.darkTile;
      fg = Colors.white;
      sub = Colors.white70;
      iconBg = tile.color;
      iconFg = const Color(0xFF12141F);
      borderColor = Colors.white.withValues(alpha: isDark ? 0.10 : 0.0);
    }
    if (tile.fill != null) {
      bg = tile.fill!;
      borderColor = Colors.transparent;
    }
    if (editing) borderColor = AppColors.ink.withValues(alpha: 0.35);

    final icon = tile.icon ?? Icons.circle;
    final pillText = tile.count ?? tile.badge;

    Widget iconBox(double size, double iconSize) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(size * 0.34)),
          child: Icon(icon, color: iconFg, size: iconSize),
        );

    Widget pill(String text, {Color? bgc, Color? fgc}) => Container(
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgc ?? accent.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fgc ?? AppColors.ink),
          ),
        );

    Widget content;
    switch (tile.kind) {
      case BentoKind.custom:
        content = tile.builder != null ? tile.builder!(context) : const SizedBox.shrink();
        break;

      case BentoKind.feature:
        content = Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              iconBox(36, 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tile.count ?? '',
                      style: AppTypography.soraDisplay(size: 46, weight: FontWeight.w700, color: fg).copyWith(height: 0.95),
                    ),
                  ),
                  if (tile.bigLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(tile.bigLabel!, style: AppTypography.interBody(size: 12, color: sub)),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tile.title, style: AppTypography.interBody(size: 14, weight: FontWeight.w700, color: fg)),
                  Text(tile.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.interBody(size: 11.5, color: sub)),
                ],
              ),
            ],
          ),
        );
        break;

      case BentoKind.wide:
        content = Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    iconBox(38, 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(tile.title, style: AppTypography.interBody(size: 13.5, weight: FontWeight.w700, color: fg)),
                          ),
                          if (tile.subtitle.isNotEmpty)
                            Text(tile.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.interBody(size: 11.5, color: sub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!editing && pillText != null) Positioned(top: 8, right: 8, child: pill(pillText)),
          ],
        );
        break;

      case BentoKind.small:
        content = Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    iconBox(32, 18),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(tile.title, style: AppTypography.interBody(size: 13, weight: FontWeight.w700, color: fg)),
                    ),
                  ],
                ),
              ),
            ),
            if (!editing && pillText != null) Positioned(top: 8, right: 8, child: pill(pillText)),
          ],
        );
        break;

      case BentoKind.dark:
        content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              iconBox(38, 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tile.title, style: AppTypography.interBody(size: 14, weight: FontWeight.w700, color: fg)),
                    if (tile.subtitle.isNotEmpty)
                      Text(tile.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.interBody(size: 11.5, color: sub)),
                  ],
                ),
              ),
              if (tile.badge != null) pill(tile.badge!, bgc: tile.color, fgc: const Color(0xFF12141F)),
              if (tile.badge == null) Icon(Icons.arrow_forward_ios_rounded, size: 14, color: tile.color),
            ],
          ),
        );
        break;
    }

    final showX = onHide != null && (editing || tile.dismissible);

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: editing ? 1.4 : 1),
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: editing ? null : tile.onTap,
                child: content,
              ),
            ),
          ),
        ),
        if (showX)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onHide,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: tile.fill != null ? Colors.black.withValues(alpha: 0.2) : AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 15, color: tile.fill != null ? Colors.white : AppColors.bg),
              ),
            ),
          ),
      ],
    );
  }
}

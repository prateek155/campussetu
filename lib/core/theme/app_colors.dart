// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static bool _isDark = false;
  static void setDark(bool v) => _isDark = v;
  static bool get isDark => _isDark;

  // ── Base ─────────────────────────────────────────────
  static Color get bg => _isDark ? const Color(0xFF12141F) : const Color(0xFFE9EBEE);
  static Color get shadowDark => _isDark ? const Color(0xFF0A0C14) : const Color(0xFFC7CAD1);
  static Color get shadowLight => _isDark ? const Color(0xFF1E2330) : const Color(0xFFFFFFFF);

  // ── Text ─────────────────────────────────────────────
  static Color get ink => _isDark ? const Color(0xFFE9EBEE) : const Color(0xFF1A1D24);
  static Color get inkSoft => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get inkMuted => _isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

  // ── Accent ───────────────────────────────────────────
  static const Color cyan = Color(0xFF3FD8F5);
  static const Color cyanDeep = Color(0xFF1BA8C4);
  static const Color cyanGlow = Color(0x263FD8F5); // 15% opacity
  static const Color primary = cyan;

  // ── Dark Tile ────────────────────────────────────────
  static const Color darkTile = Color(0xFF14161F);
  static const Color darkTileAlt = Color(0xFF1E2130);

  // ── Status / Semantic ─────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Premium / Gold ────────────────────────────────────
  static const Color gold = Color(0xFFFFB800);
  static const Color goldSoft = Color(0xFFFFF3CD);

  // ── Transparent ───────────────────────────────────────
  static const Color transparent = Colors.transparent;

  // ── Gradients ─────────────────────────────────────────
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [cyan, cyanDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkTileGradient = LinearGradient(
    colors: [Color(0xFF14161F), Color(0xFF1E2130)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient indiaGradient = LinearGradient(
    colors: [Color(0xFFFF9933), Color(0xFFFFFFFF), Color(0xFF138808)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Neu Shadows ───────────────────────────────────────
  static List<BoxShadow> get neuRaisedShadows => [
    BoxShadow(color: shadowDark, offset: const Offset(7, 7), blurRadius: 14),
    BoxShadow(color: shadowLight, offset: const Offset(-7, -7), blurRadius: 14),
  ];

  static List<BoxShadow> get neuInsetShadows => [
    BoxShadow(color: shadowDark, offset: const Offset(4, 4), blurRadius: 8, spreadRadius: -2),
    BoxShadow(color: shadowLight, offset: const Offset(-4, -4), blurRadius: 8, spreadRadius: -2),
  ];

  static List<BoxShadow> get neuSmallShadows => [
    BoxShadow(color: shadowDark, offset: const Offset(4, 4), blurRadius: 8),
    BoxShadow(color: shadowLight, offset: const Offset(-4, -4), blurRadius: 8),
  ];

  static List<BoxShadow> get cyanGlowShadows => [
    BoxShadow(color: cyan.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: 2),
  ];
}

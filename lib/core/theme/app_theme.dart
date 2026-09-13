// lib/core/theme/app_theme.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get theme => lightTheme;

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF12141F) : AppColors.bg;
    final ink = isDark ? const Color(0xFFE9EBEE) : AppColors.ink;
    final inkSoft = isDark ? const Color(0xFF9CA3AF) : AppColors.inkSoft;
    return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: bg,
        colorScheme: (isDark ? ColorScheme.dark : ColorScheme.light)(
          surface: bg,
          primary: AppColors.cyanDeep,
          secondary: AppColors.cyan,
          error: AppColors.error,
          onSurface: ink,
          onPrimary: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme().copyWith(
          bodyLarge: GoogleFonts.inter(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: GoogleFonts.inter(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          titleLarge: GoogleFonts.sora(
            color: AppColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: GoogleFonts.sora(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: bg,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          titleTextStyle: GoogleFonts.sora(color: ink, fontSize: 20, fontWeight: FontWeight.w700),
          iconTheme: IconThemeData(color: ink),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.cyanDeep, width: 1.5)),
          labelStyle: GoogleFonts.inter(color: inkSoft, fontSize: 14),
          hintStyle: GoogleFonts.inter(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.bg,
          selectedColor: AppColors.cyanDeep.withValues(alpha: 0.15),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.shadowDark,
          thickness: 1,
          space: 0,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle soraDisplay({double size = 32, FontWeight weight = FontWeight.w800, Color? color}) =>
      GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color ?? AppColors.ink, letterSpacing: -0.5);

  static TextStyle soraHeading1({Color? color}) =>
      GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: color ?? AppColors.ink, letterSpacing: -0.3);

  static TextStyle soraHeading2({Color? color}) =>
      GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w600, color: color ?? AppColors.ink, letterSpacing: -0.2);

  static TextStyle soraHeading3({Color? color}) =>
      GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: color ?? AppColors.ink);

  static TextStyle soraSubtitle({Color? color}) =>
      GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w500, color: color ?? AppColors.inkSoft);

  static TextStyle interBody({double size = 15, FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? AppColors.ink, height: height);

  static TextStyle interBodyLarge({Color? color}) =>
      GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w400, color: color ?? AppColors.ink, height: 1.6);

  static TextStyle interBodySmall({Color? color}) =>
      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: color ?? AppColors.inkSoft);

  static TextStyle interLabel({Color? color}) =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: color ?? AppColors.inkSoft, letterSpacing: 0.3);

  static TextStyle interButton({Color? color, double size = 15}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w600, color: color ?? AppColors.ink, letterSpacing: 0.2);

  static TextStyle interCaption({Color? color}) =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: color ?? AppColors.inkMuted);

  static TextStyle interBadge({Color? color}) =>
      GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color ?? AppColors.ink, letterSpacing: 0.5);

  static TextStyle monoCode({double size = 14, Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color ?? AppColors.ink, letterSpacing: 0.5);

  static TextStyle monoDisplay({double size = 48, Color? color}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: FontWeight.w700, color: color ?? AppColors.cyan, letterSpacing: 8);

  static TextStyle monoTimestamp({Color? color}) =>
      GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w400, color: color ?? AppColors.inkMuted);

  static TextStyle caveatBrand({double size = 36, Color? color}) =>
      GoogleFonts.caveat(fontSize: size, fontWeight: FontWeight.w700, color: color ?? AppColors.ink);

  static TextStyle caveatWarm({double size = 20, Color? color}) =>
      GoogleFonts.caveat(fontSize: size, fontWeight: FontWeight.w400, color: color ?? AppColors.inkSoft);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) { _load(); }

  static const _key = 'is_dark_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    AppColors.setDark(isDark);
  }

  Future<void> toggle() async {
    final isDark = state == ThemeMode.dark;
    final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    AppColors.setDark(newMode == ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, newMode == ThemeMode.dark);
  }

  Future<void> setDark(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    AppColors.setDark(isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }

  bool get isDark => state == ThemeMode.dark;
}

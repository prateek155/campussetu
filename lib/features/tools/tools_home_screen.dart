// lib/features/tools/tools_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_typography.dart';

class ToolsHomeScreen extends ConsumerWidget {
  final String backRoute;
  const ToolsHomeScreen({super.key, this.backRoute = '/home'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark ||
        Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F111A) : const Color(0xFFF6F8FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);
    final textMuted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bgColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(backRoute);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toolkit',
              style: AppTypography.soraHeading2().copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            Text(
              'Everything you need. Offline.',
              style: AppTypography.interCaption(color: textMuted),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // ── AI / Quick Finder Banner ────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1D2B) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? const Color(0xFF282D42) : Colors.black.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'What are you trying to do?',
                                  style: AppTypography.soraHeading3().copyWith(
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Choose between PDF & Image packs or explore individual offline utilities.',
                              style: AppTypography.interCaption(color: textMuted),
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: () => context.push('/tools/pdf'),
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7DD3FC),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Find the right tool',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F172A), size: 15),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 4),
                                Text(
                                  '100% Private. Always Offline.',
                                  style: AppTypography.interCaption(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF24293D) : const Color(0xFFE0F2FE),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.smart_toy_outlined, size: 44, color: Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Hero Card 1: PDF Tools ──────────────────────
                _HeroToolPackCard(
                  title: 'PDF Tools',
                  subtitle: 'PDF to Word, PPT to PDF, CSV to Excel/PDF, Compress, Reorder & PPTX',
                  badgeText: '12 Tools',
                  isDark: isDark,
                  gradientColors: isDark
                      ? const [Color(0xFF1E2640), Color(0xFF162A4A), Color(0xFF1C2237)]
                      : const [Color(0xFFDCE8F8), Color(0xFFC7DDF7), Color(0xFFD6E4F7)],
                  accentColor: const Color(0xFF3B82F6),
                  iconData: Icons.picture_as_pdf_rounded,
                  onTap: () => context.push('/tools/pdf'),
                ),

                const SizedBox(height: 18),

                // ── Hero Card 2: Image Tools ────────────────────
                _HeroToolPackCard(
                  title: 'Image Tools',
                  subtitle: 'Convert (SVG & BMP), Compress, Erase Watermark, QR, Barcode & OCR to PDF/Word',
                  badgeText: '6 Tools',
                  isDark: isDark,
                  gradientColors: isDark
                      ? const [Color(0xFF193233), Color(0xFF132B2B), Color(0xFF182329)]
                      : const [Color(0xFFD5F3E7), Color(0xFFC3ECE0), Color(0xFFD4F2E7)],
                  accentColor: const Color(0xFF10B981),
                  iconData: Icons.photo_library_rounded,
                  onTap: () => context.push('/tools/image'),
                ),

                const SizedBox(height: 28),

                // ── Footer ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Text(
                      '100% Offline',
                      style: AppTypography.interCaption(color: textColor).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('|', style: AppTypography.interCaption(color: textMuted)),
                    ),
                    Text(
                      'Your files never leave your device',
                      style: AppTypography.interCaption(color: textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroToolPackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final bool isDark;
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData iconData;
  final VoidCallback onTap;

  const _HeroToolPackCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.isDark,
    required this.gradientColors,
    required this.accentColor,
    required this.iconData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 175,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark ? accentColor.withValues(alpha: 0.3) : accentColor.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: subColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right-side 3D stylized emblem
            Container(
              width: 90,
              height: 110,
              decoration: BoxDecoration(
                color: isDark ? accentColor.withValues(alpha: 0.2) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconData, size: 48, color: accentColor),
                  const SizedBox(height: 4),
                  Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

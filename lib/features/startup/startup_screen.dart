// lib/features/startup/startup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/dark_tile.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_chip.dart';
import '../../core/widgets/premium_badge.dart';

class _Startup {
  final String id, name, tagline, stage, sector;
  final int teamSize, lookingFor;
  const _Startup({required this.id, required this.name, required this.tagline,
      required this.stage, required this.sector, required this.teamSize, required this.lookingFor});
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  static final _startups = [
    const _Startup(id: '1', name: 'AgroAI', tagline: 'AI-powered crop disease detection for Indian farmers', stage: 'Ideation', sector: 'AgriTech', teamSize: 3, lookingFor: 2),
    const _Startup(id: '2', name: 'SkillBridge', tagline: 'Connecting tier-2 college students with mentors', stage: 'MVP', sector: 'EdTech', teamSize: 4, lookingFor: 1),
    const _Startup(id: '3', name: 'CampusMart', tagline: 'Student-to-student marketplace for every campus', stage: 'Pre-Revenue', sector: 'Marketplace', teamSize: 2, lookingFor: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const PremiumBadge(),
                    const SizedBox(width: 10),
                    Text('Startup Hub', style: AppTypography.soraDisplay(size: 26)),
                  ]),
                  Text('Build your startup with campus peers', style: AppTypography.interBody(color: AppColors.inkSoft)),
                  const SizedBox(height: 20),

                  // ── CTAs ───────────────────────────────────
                  DarkTile(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      GlowText('Launch Your Startup', style: AppTypography.soraHeading2(color: AppColors.cyan)),
                      const SizedBox(height: 8),
                      Text('Pitch your idea. Find your team. Build together.',
                          style: AppTypography.interBody(color: AppColors.inkSoft)),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: AppColors.cyanGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Post Your Idea', style: AppTypography.interButton(color: AppColors.darkTile)),
                        ),
                      ),
                    ]),
                  ).animate().fadeIn(duration: 500.ms),

                  const SizedBox(height: 24),
                  Text('Student Startups', style: AppTypography.soraHeading3()),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final s = _startups[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: NeuCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(color: AppColors.cyanDeep.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text(s.name[0], style: AppTypography.soraHeading2(color: AppColors.cyanDeep))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: AppTypography.interButton(color: AppColors.ink, size: 15)),
                            Row(children: [
                              NeuChip(label: s.stage, selectedColor: AppColors.warning, isSelected: true),
                              const SizedBox(width: 6),
                              NeuChip(label: s.sector),
                            ]),
                          ])),
                        ]),
                        const SizedBox(height: 12),
                        Text(s.tagline, style: AppTypography.interBody(color: AppColors.ink, height: 1.5)),
                        const SizedBox(height: 14),
                        Row(children: [
                          Icon(Icons.people_outline, size: 14, color: AppColors.inkSoft),
                          const SizedBox(width: 4),
                          Text('Team: ${s.teamSize}', style: AppTypography.interCaption()),
                          const SizedBox(width: 12),
                          const Icon(Icons.person_add_outlined, size: 14, color: AppColors.cyanDeep),
                          const SizedBox(width: 4),
                          Text('Looking for ${s.lookingFor}', style: AppTypography.interCaption(color: AppColors.cyanDeep)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(10)),
                            child: Text('Join Team', style: AppTypography.interCaption(color: Colors.white)
                                .copyWith(fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ]),
                    ).animate(delay: (i * 80).ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  );
                },
                childCount: _startups.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

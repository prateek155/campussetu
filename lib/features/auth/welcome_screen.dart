// lib/features/auth/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/router/app_router.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    ApiService().warmup();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService().signInWithGoogle();
      if (!mounted) return;
      if (result['profile_complete'] == true) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.authConfirm, extra: result);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: ${e.toString()}', style: AppTypography.interBody(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Brand Orb Hero ───────────────────────────
              _BrandOrb()
                  .animate()
                  .scale(begin: const Offset(0.6, 0.6), duration: 800.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 600.ms),

              const SizedBox(height: 32),

              // ── Brand Name (Caveat) ───────────────────────
              Text(
                'CampusSetu',
                style: AppTypography.caveatBrand(size: 42, color: AppColors.ink),
              )
                  .animate(delay: 300.ms)
                  .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOut)
                  .fadeIn(duration: 600.ms),

              const SizedBox(height: 8),
              Text(
                'India\'s student network',
                style: AppTypography.interBody(color: AppColors.inkSoft, size: 15),
              ).animate(delay: 400.ms).fadeIn(duration: 500.ms),

              const Spacer(flex: 2),

              // ── Feature Strips ────────────────────────────
              Column(
                children: [
                  const _FeatureRow(Icons.people_rounded, 'Connect with students across India'),
                  const SizedBox(height: 12),
                  const _FeatureRow(Icons.work_rounded, 'Discover jobs & internships'),
                  const SizedBox(height: 12),
                  const _FeatureRow(Icons.share_rounded, 'Share code snippets instantly with Tshare'),
                  const SizedBox(height: 12),
                  const _FeatureRow(Icons.store_rounded, 'Campus marketplace for your city'),
                ]
                    .animate(interval: 100.ms, delay: 500.ms)
                    .slideX(begin: -0.2, duration: 500.ms, curve: Curves.easeOut)
                    .fadeIn(duration: 500.ms),
              ),

              const Spacer(flex: 3),

              // ── Google Sign-In Button ─────────────────────
              _GoogleSignInButton(
                isLoading: _isLoading,
                onTap: _handleGoogleSignIn,
              )
                  .animate(delay: 800.ms)
                  .slideY(begin: 0.4, duration: 600.ms, curve: Curves.easeOut)
                  .fadeIn(duration: 600.ms),

              const SizedBox(height: 16),
              Text(
                'By continuing, you agree to our Terms & Privacy Policy',
                style: AppTypography.interCaption(),
                textAlign: TextAlign.center,
              ).animate(delay: 900.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Brand Orb ─────────────────────────────────────────────
class _BrandOrb extends StatefulWidget {
  @override
  State<_BrandOrb> createState() => _BrandOrbState();
}

class _BrandOrbState extends State<_BrandOrb> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _pulse.value,
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.shadowDark, offset: const Offset(12, 12), blurRadius: 24),
              BoxShadow(color: AppColors.shadowLight, offset: const Offset(-12, -12), blurRadius: 24),
            ],
            color: AppColors.bg,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/images/app_icon.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ── Feature Row ───────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.cyanDeep.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.cyanDeep, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: AppTypography.interBody(color: AppColors.ink, size: 14)),
        ),
      ],
    );
  }
}

// ── Google Sign-In Button ─────────────────────────────────
class _GoogleSignInButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.isLoading, required this.onTap});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _pressed ? AppColors.neuInsetShadows : AppColors.neuRaisedShadows,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.cyanDeep,
                ),
              )
            else ...[
              // Google G logo
              const SizedBox(
                width: 28,
                height: 28,
                child: Center(child: Text('G', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4285F4), fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: AppTypography.interButton(color: AppColors.ink, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

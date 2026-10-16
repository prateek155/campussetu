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
import '../events/widgets/organizer_login_dialog.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
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
          content: Text('Sign-in failed: ${e.toString()}',
              style: AppTypography.interBody(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // ── Brand Orb Hero ───────────────────────────
                      _BrandOrb()
                          .animate()
                          .scale(
                              begin: const Offset(0.7, 0.7),
                              duration: 800.ms,
                              curve: Curves.elasticOut)
                          .fadeIn(duration: 600.ms),

                      const SizedBox(height: 18),

                      // ── Brand Name & Tagline ─────────────────────
                      Text(
                        'CampusSetu',
                        style: AppTypography.caveatBrand(
                            size: 44, color: AppColors.ink),
                      )
                          .animate(delay: 200.ms)
                          .slideY(
                              begin: 0.3,
                              duration: 500.ms,
                              curve: Curves.easeOut)
                          .fadeIn(duration: 500.ms),

                      const SizedBox(height: 4),
                      Text(
                        'India\'s student network',
                        style: AppTypography.interBody(
                            color: AppColors.inkSoft, size: 14.5),
                      ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

                      const SizedBox(height: 12),

                      // ── Community Social Proof Pill ──────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cyanDeep.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.cyanDeep.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '5,000+ Students across 80+ Campuses',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cyanDeep,
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                      const SizedBox(height: 24),

                      // ── Feature Grid (2x2 Compact) ───────────────
                      Row(
                        children: const [
                          Expanded(
                            child: _FeatureChip(
                              icon: Icons.people_alt_outlined,
                              label: 'Connect with Peers',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _FeatureChip(
                              icon: Icons.work_outline_rounded,
                              label: 'Jobs & Internships',
                            ),
                          ),
                        ],
                      ).animate(delay: 450.ms).fadeIn(duration: 400.ms),

                      const SizedBox(height: 10),

                      Row(
                        children: const [
                          Expanded(
                            child: _FeatureChip(
                              icon: Icons.bolt_rounded,
                              label: 'Tshare Instant Code',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _FeatureChip(
                              icon: Icons.storefront_outlined,
                              label: 'Campus Marketplace',
                            ),
                          ),
                        ],
                      ).animate(delay: 550.ms).fadeIn(duration: 400.ms),

                      const Spacer(),
                      const SizedBox(height: 24),

                      // ── Action Hub ───────────────────────────────
                      // 1. Google Sign-In Button
                      _GoogleSignInButton(
                        isLoading: _isLoading,
                        onTap: _handleGoogleSignIn,
                      )
                          .animate(delay: 650.ms)
                          .slideY(
                              begin: 0.3,
                              duration: 500.ms,
                              curve: Curves.easeOut)
                          .fadeIn(duration: 500.ms),

                      const SizedBox(height: 14),

                      // Divider "or create account with"
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppColors.isDark
                                  ? Colors.white12
                                  : Colors.black12,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or create account with',
                              style: AppTypography.interCaption(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.isDark
                                  ? Colors.white12
                                  : Colors.black12,
                            ),
                          ),
                        ],
                      ).animate(delay: 700.ms).fadeIn(duration: 350.ms),

                      const SizedBox(height: 14),

                      // 2. Email Sign-Up Button (New!)
                      _EmailSignUpButton(
                        onTap: _isLoading
                            ? null
                            : () => context.push('${AppRoutes.emailLogin}?mode=signup'),
                      )
                          .animate(delay: 750.ms)
                          .slideY(
                              begin: 0.3,
                              duration: 500.ms,
                              curve: Curves.easeOut)
                          .fadeIn(duration: 500.ms),

                      const SizedBox(height: 12),

                      // 3. Existing User Sign In Switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already registered?',
                            style: AppTypography.interBodySmall(
                                color: AppColors.inkSoft),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () => context
                                    .push('${AppRoutes.emailLogin}?mode=signin'),
                            child: Text(
                              'Log In here',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyanDeep,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ).animate(delay: 800.ms).fadeIn(duration: 350.ms),

                      const SizedBox(height: 8),

                      // 4. Organizer Desk Portal
                      TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => OrganizerLoginDialog.show(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                        icon: const Icon(Icons.shield_outlined,
                            size: 15, color: Color(0xFFF59E0B)),
                        label: const Text(
                          'Event Organizer Desk',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 5. Terms & Privacy disclaimer
                      Text(
                        'By continuing, you agree to our Terms & Privacy Policy',
                        style: AppTypography.interCaption(),
                        textAlign: TextAlign.center,
                      ).animate(delay: 850.ms).fadeIn(duration: 350.ms),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
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

class _BrandOrbState extends State<_BrandOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
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
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadowDark,
                  offset: const Offset(10, 10),
                  blurRadius: 20),
              BoxShadow(
                  color: AppColors.shadowLight,
                  offset: const Offset(-10, -10),
                  blurRadius: 20),
            ],
            color: AppColors.bg,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Image.asset('assets/images/app_icon.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ── Feature Chip ───────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cyanDeep.withValues(alpha: 0.12),
        ),
        boxShadow: AppColors.neuSmallShadows,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.cyanDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.cyanDeep, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              _pressed ? AppColors.neuInsetShadows : AppColors.neuRaisedShadows,
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
              // Google G emblem
              const SizedBox(
                width: 26,
                height: 26,
                child: Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4285F4),
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Continue with Google',
                style:
                    AppTypography.interButton(color: AppColors.ink, size: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Email Sign-Up Button (New!) ───────────────────────────
class _EmailSignUpButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _EmailSignUpButton({required this.onTap});

  @override
  State<_EmailSignUpButton> createState() => _EmailSignUpButtonState();
}

class _EmailSignUpButtonState extends State<_EmailSignUpButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.cyanDeep, Color(0xFF0E8399)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyanDeep.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.mail_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Sign up with Email & Password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

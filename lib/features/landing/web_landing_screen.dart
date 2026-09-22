// lib/features/landing/web_landing_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _ecosystemKey = GlobalKey();
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    ApiService().warmup();
  }

  static const _bg          = Color(0xFF090B14);
  static const _card        = Color(0xFF121526);
  static const _cardBorder  = Color(0xFF222640);
  static const _cyan        = Color(0xFF3FD8F5);
  static const _purple      = Color(0xFF8B5CF6);
  static const _green       = Color(0xFF22C55E);
  static const _orange      = Color(0xFFF59E0B);
  static const _ink         = Color(0xFFE9EBEE);
  static const _inkSoft     = Color(0xFF9CA3AF);

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSigningIn = true);
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
          content: Text('Sign-in failed: ${e.toString()}', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background subtle ambient glows
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 550,
              height: 550,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyan.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 300,
            right: -180,
            child: Container(
              width: 650,
              height: 650,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _purple.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Scrollable Landing Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Sticky Web Navbar
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: _bg.withValues(alpha: 0.92),
                elevation: 0,
                toolbarHeight: 74,
                titleSpacing: 0,
                title: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          // Brand Logo
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_cyan, Color(0xFF1BA8C4)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(color: _cyan.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 10),
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(text: 'Campus', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                                    TextSpan(text: 'Setu', style: TextStyle(color: _cyan, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _cyan.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                                ),
                                child: const Text('WEB', style: TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Nav Links (visible on desktop)
                          if (MediaQuery.of(context).size.width >= 780) ...[
                            _NavBtn(label: 'Features', onTap: () => _scrollTo(_featuresKey)),
                            const SizedBox(width: 20),
                            _NavBtn(label: 'Ecosystem', onTap: () => _scrollTo(_ecosystemKey)),
                            const SizedBox(width: 20),
                            _NavBtn(
                              label: 'Portals',
                              onTap: () => _showPortalsDialog(context),
                            ),
                            const SizedBox(width: 28),
                          ],

                          // Header CTA Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cyan,
                              foregroundColor: const Color(0xFF0D0F1A),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                            icon: _isSigningIn
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D0F1A)))
                                : const Icon(Icons.login_rounded, size: 18),
                            label: Text(
                              _isSigningIn ? 'Signing in...' : 'Sign In with Google',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Hero Section
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 80),
                      child: Column(
                        children: [
                          // Pill Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: _cyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, color: _cyan, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "India's Unified Student Campus Network",
                                  style: TextStyle(color: _cyan, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Main Headline
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFE2E8F0), _cyan],
                              stops: [0.0, 0.7, 1.0],
                            ).createShader(bounds),
                            child: const Text(
                              'Everything Your College Life Needs.\nAll In One Connected Hub.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 44,
                                height: 1.18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Subtitle
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: const Text(
                              'Connect with verified college peers, earn cash or points with Helping Hand, swap notes instantly, carpool together, find student flatmates, and compete in live faculty quizzes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 17, height: 1.55, color: _inkSoft),
                            ),
                          ),

                          const SizedBox(height: 36),

                          // CTA Buttons
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              // Primary Google Login Button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0D0F1A),
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 4,
                                ),
                                onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.network(
                                      'https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9zOIoTQPdMK5AEnhETractivity1=s96',
                                      width: 22,
                                      height: 22,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isSigningIn ? 'Connecting...' : 'Continue with Google',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D0F1A)),
                                    ),
                                  ],
                                ),
                              ),

                              // Secondary Explore Button
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _ink,
                                  side: const BorderSide(color: _cardBorder, width: 1.5),
                                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () => _scrollTo(_featuresKey),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Explore Features', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_downward_rounded, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 60),

                          // Live Highlights Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            decoration: BoxDecoration(
                              color: _card.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _cardBorder),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isSmall = constraints.maxWidth < 650;
                                if (isSmall) {
                                  return Column(
                                    children: const [
                                      _MetricItem(label: 'College Campuses', value: '50+'),
                                      Divider(color: _cardBorder, height: 24),
                                      _MetricItem(label: 'Active Peers', value: '10,000+'),
                                      Divider(color: _cardBorder, height: 24),
                                      _MetricItem(label: 'Tasks Solved', value: '5,000+'),
                                      Divider(color: _cardBorder, height: 24),
                                      _MetricItem(label: 'Cost to Students', value: '100% Free'),
                                    ],
                                  );
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: const [
                                    _MetricItem(label: 'College Campuses', value: '50+'),
                                    _MetricDivider(),
                                    _MetricItem(label: 'Active Peers', value: '10,000+'),
                                    _MetricDivider(),
                                    _MetricItem(label: 'Tasks Solved', value: '5,000+'),
                                    _MetricDivider(),
                                    _MetricItem(label: 'Cost to Students', value: '100% Free'),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Feature Showcase Section
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    key: _featuresKey,
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BUILT FOR CAMPUS REALITY',
                            style: TextStyle(color: _cyan, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Supercharge Every Aspect of Your Student Life',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Everything from peer academics to roommates and errands, organized seamlessly.',
                            style: TextStyle(color: _inkSoft, fontSize: 16),
                          ),
                          const SizedBox(height: 36),

                          // Feature Cards Grid
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth > 950 ? 3 : constraints.maxWidth > 650 ? 2 : 1;
                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 18,
                                crossAxisSpacing: 18,
                                childAspectRatio: constraints.maxWidth > 950 ? 1.25 : 1.4,
                                children: const [
                                  _FeatureCard(
                                    icon: Icons.people_alt_rounded,
                                    iconColor: _cyan,
                                    title: 'Campus Peer Network',
                                    description: 'Connect with students across India filtered by college, city, branch, or year. Expand your academic and professional circle.',
                                  ),
                                  _FeatureCard(
                                    icon: Icons.volunteer_activism_rounded,
                                    iconColor: _orange,
                                    title: 'Helping Hand Tasks',
                                    description: 'Need assistance with an assignment, moving, or notes? Post a task with real rewards or earn points by helping your peers.',
                                  ),
                                  _FeatureCard(
                                    icon: Icons.share_rounded,
                                    iconColor: _purple,
                                    title: 'TShare & Notes Vault',
                                    description: 'Instantly transfer code snippets and verified lecture notes using 4-character secret keys and secure cloud storage.',
                                  ),
                                  _FeatureCard(
                                    icon: Icons.hotel_rounded,
                                    iconColor: _green,
                                    title: 'Flatmates & Rooms',
                                    description: 'Looking for a roommate or PG near campus? Search and connect with fellow students looking for flat shares.',
                                  ),
                                  _FeatureCard(
                                    icon: Icons.directions_car_rounded,
                                    iconColor: Color(0xFF38BDF8),
                                    title: 'Campus Travel & Carpools',
                                    description: 'Share autos, cabs, and weekend rides home. Save money on daily commutes with verified classmates.',
                                  ),
                                  _FeatureCard(
                                    icon: Icons.quiz_rounded,
                                    iconColor: Color(0xFFEC4899),
                                    title: 'Live Interactive Quizzes',
                                    description: 'Compete in fast-paced real-time quizzes hosted by faculty and student clubs with live scoreboards.',
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Ecosystem / Portals Section
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    key: _ecosystemKey,
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 80),
                      child: Container(
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _card,
                              const Color(0xFF161930),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'The Entire Ecosystem',
                              style: TextStyle(color: _cyan, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Built for Students, Faculty & Enterprise Partners',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Switch between specialized portals designed for administrative oversight, faculty quiz administration, and enterprise rewards.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _inkSoft, fontSize: 15),
                            ),
                            const SizedBox(height: 32),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: [
                                _PortalLinkCard(
                                  title: 'Student Portal',
                                  desc: 'Social feed, connections, tasks, notes, carpools',
                                  url: 'https://campussetu-user.pages.dev',
                                  isCurrent: true,
                                ),
                                _PortalLinkCard(
                                  title: 'Admin Portal',
                                  desc: 'City/State user segregation, content moderation, pulse stats',
                                  url: 'https://campussetu-admin.pages.dev',
                                ),
                                _PortalLinkCard(
                                  title: 'Faculty Portal',
                                  desc: 'Create real-time PIN quizzes, evaluate results, view boards',
                                  url: 'https://campussetu-faculty.pages.dev',
                                ),
                                _PortalLinkCard(
                                  title: 'Enterprise Portal',
                                  desc: 'Partner deal redemptions, student vouchers, QR verification',
                                  url: 'https://campussetu-enterprise.pages.dev',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Footer
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF07080F),
                    border: Border(top: BorderSide(color: _cardBorder)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: _cyan,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.school_rounded, color: Color(0xFF090B14), size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('CampusSetu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => context.push(AppRoutes.privacy),
                                    child: const Text('Privacy Policy', style: TextStyle(color: _inkSoft, fontSize: 13)),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: () => context.push(AppRoutes.terms),
                                    child: const Text('Terms of Service', style: TextStyle(color: _inkSoft, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: _cardBorder),
                          const SizedBox(height: 12),
                          const Text(
                            '© 2026 CampusSetu. Empowering campus connections across India.',
                            style: TextStyle(color: _inkSoft, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPortalsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _cardBorder)),
        title: const Text('CampusSetu Portals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogPortalRow('🎓 Student Portal', 'https://campussetu-user.pages.dev'),
            const SizedBox(height: 10),
            _dialogPortalRow('🛡️ Admin Portal', 'https://campussetu-admin.pages.dev'),
            const SizedBox(height: 10),
            _dialogPortalRow('👨‍🏫 Faculty Portal', 'https://campussetu-faculty.pages.dev'),
            const SizedBox(height: 10),
            _dialogPortalRow('🏢 Enterprise Portal', 'https://campussetu-enterprise.pages.dev'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _cyan)),
          ),
        ],
      ),
    );
  }

  Widget _dialogPortalRow(String name, String url) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
          Text(url.replaceFirst('https://', ''), style: const TextStyle(color: _cyan, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ──────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label, value;

  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: const Color(0xFF222640),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    const card = Color(0xFF121526);
    const cardBorder = Color(0xFF222640);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PortalLinkCard extends StatelessWidget {
  final String title;
  final String desc;
  final String url;
  final bool isCurrent;

  const _PortalLinkCard({
    required this.title,
    required this.desc,
    required this.url,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF3FD8F5);
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? cyan : const Color(0xFF222640)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: cyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Live', style: TextStyle(color: cyan, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4)),
          const SizedBox(height: 10),
          Text(url.replaceFirst('https://', ''), style: TextStyle(color: isCurrent ? cyan : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

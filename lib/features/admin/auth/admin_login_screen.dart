import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  static const _bg      = Color(0xFF0D0F1A);
  static const _card    = Color(0xFF141728);
  static const _border  = Color(0xFF252840);
  static const _cyan    = Color(0xFF3FD8F5);
  static const _red     = Color(0xFFEF4444);
  static const _ink     = Color(0xFFE9EBEE);
  static const _inkSoft = Color(0xFF9CA3AF);

  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await AuthService().signInWithGoogle();
      final isAdmin = result['is_admin'] == true;
      if (!mounted) return;
      if (isAdmin) {
        context.go('/admin-home');
      } else {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = 'Access denied. This account does not have admin privileges.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo + title
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _card,
                  border: Border.all(color: _cyan.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(color: _cyan.withValues(alpha: 0.15), blurRadius: 32, spreadRadius: 4),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.admin_panel_settings_rounded, color: _cyan, size: 48),
                ),
              ).animate().scale(begin: const Offset(0.7, 0.7), duration: 700.ms, curve: Curves.elasticOut),

              const SizedBox(height: 28),

              const Text(
                'CampusSetu',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3),

              const SizedBox(height: 6),
              const Text(
                'Admin Console',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _cyan, letterSpacing: 1.5),
              ).animate(delay: 300.ms).fadeIn(),

              const Spacer(flex: 2),

              // Info cards
              const _InfoRow(icon: Icons.people_rounded,      label: 'Manage all users & access'),
              const SizedBox(height: 12),
              const _InfoRow(icon: Icons.radar,               label: 'Real-time Pulse monitoring'),
              const SizedBox(height: 12),
              const _InfoRow(icon: Icons.inventory_2_rounded, label: 'Events, Deals & Flatmates'),
              const SizedBox(height: 12),
              const _InfoRow(icon: Icons.shield_rounded,      label: 'Detect & block suspicious activity'),

              const Spacer(flex: 3),

              // Error banner
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _red.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.block_rounded, color: _red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: _red, fontSize: 13))),
                  ]),
                ).animate().fadeIn().slideY(begin: -0.2),

              // Sign-in button
              GestureDetector(
                onTap: _loading ? null : _signIn,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 60,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_loading)
                        const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: _cyan))
                      else ...[
                        const Text('G', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4285F4), fontSize: 22)),
                        const SizedBox(width: 12),
                        const Text('Sign in with Google',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
                      ],
                    ],
                  ),
                ),
              ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3),

              const SizedBox(height: 16),
              const Text(
                'Admin access only. Unauthorized access is logged.',
                style: TextStyle(fontSize: 11, color: _inkSoft),
                textAlign: TextAlign.center,
              ).animate(delay: 700.ms).fadeIn(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF3FD8F5).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF3FD8F5), size: 18),
      ),
      const SizedBox(width: 14),
      Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
    ]).animate(delay: 400.ms).fadeIn().slideX(begin: -0.2);
  }
}

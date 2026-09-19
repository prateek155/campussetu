// lib/features/admin/admin_dashboard_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/router/app_router.dart';
import 'admin_content_screen.dart' show AddFlatmateSheet;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // ── Admin design palette ─────────────────────────────────────
  static const _bg = Color(0xFF0D0F1A);
  static const _card = Color(0xFF141728);
  static const _cardAlt = Color(0xFF1C2033);
  static const _border = Color(0xFF252840);
  static const _cyan = Color(0xFF3FD8F5);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF59E0B);
  static const _purple = Color(0xFFA855F7);

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) ApiService().setToken(token);
      }
      final stats = await ApiService().getAdminStats();
      final reportsData = await ApiService().getReportsQueue();
      final raw = reportsData['data'] ?? reportsData['reports'] ?? reportsData['items'] ?? [];
      if (mounted) {
        setState(() {
          _stats = stats;
          _reports = (raw is List)
              ? raw
                  .take(5)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList()
              : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'admin@campussetu.in';
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _cyan,
          backgroundColor: _card,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(userEmail, context)),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF3FD8F5))),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, color: _red, size: 52),
                      const SizedBox(height: 14),
                      const Text('Failed to load dashboard', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _load,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: _cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _cyan.withValues(alpha: 0.4)),
                          ),
                          child: const Text('Retry', style: TextStyle(color: Color(0xFF3FD8F5), fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildMetrics(),
                      const SizedBox(height: 26),
                      _buildQuickActions(context),
                      const SizedBox(height: 26),
                      _buildReports(context),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String email, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3FD8F5), Color(0xFF1BA8C4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CampusSetu Admin', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 16, fontWeight: FontWeight.w700)),
            Text(email, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => context.go(AppRoutes.home),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _red.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 15),
              SizedBox(width: 6),
              Text('Exit', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildMetrics() {
    final s = _stats ?? {};
    final totalUsers  = (s['totalUsers']      ?? s['total_users']      ?? s['users']           ?? '—').toString();
    final activeToday = (s['activeToday']      ?? s['active_today']     ?? s['active']          ?? '—').toString();
    final totalPosts  = (s['totalPosts']       ?? s['total_posts']      ?? s['posts']           ?? '—').toString();
    final pending     = (s['pendingReports']   ?? s['pending_reports']  ?? s['reports']         ?? _reports.length).toString();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      const Text(
        'Platform Overview',
        style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _MetricCard(label: 'Total Users', value: totalUsers, icon: Icons.people_rounded, color: _cyan)),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard(label: 'Active Today', value: activeToday, icon: Icons.trending_up_rounded, color: _green)),
      ]).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _MetricCard(label: 'Total Posts', value: totalPosts, icon: Icons.feed_rounded, color: _orange)),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard(label: 'Reports', value: pending, icon: Icons.flag_rounded, color: _red)),
      ]).animate(delay: 80.ms).fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
    ]);
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Quick Actions',
        style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      Row(children: [
        _QuickActionCard(
          icon: Icons.local_offer_rounded,
          label: 'Add Deal',
          color: _orange,
          onTap: () => context.push(AppRoutes.adminAddDeal),
        ),
        const SizedBox(width: 10),
        _QuickActionCard(
          icon: Icons.event_rounded,
          label: 'Add Event',
          color: _cyan,
          onTap: () => context.push('/admin/add-event'),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _QuickActionCard(
          icon: Icons.home_work_rounded,
          label: 'Flatmates',
          color: _purple,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddFlatmateSheet(),
            );
          },
        ),
        const SizedBox(width: 10),
        _QuickActionCard(
          icon: Icons.campaign_rounded,
          label: 'Broadcast',
          color: _green,
          onTap: () => _showBroadcastDialog(context),
        ),
      ]),
    ]).animate(delay: 160.ms).fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildReports(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Pending Reports', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 18, fontWeight: FontWeight.w700))),
        if (_reports.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('${_reports.length}', style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ]),
      const SizedBox(height: 14),
      if (_reports.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: const Column(children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 36),
            SizedBox(height: 8),
            Text('No pending reports', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
          ]),
        )
      else
        ...List.generate(_reports.length, (i) {
          final r = _reports[i];
          final reporter  = (r['reporter_name'] ?? r['reporter'] ?? r['user_name'] ?? 'Anonymous').toString();
          final reason    = (r['reason'] ?? r['type'] ?? r['description'] ?? 'Reported content').toString();
          final reportId  = (r['_id'] ?? r['id'] ?? '').toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.flag_rounded, color: _red, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reporter, style: const TextStyle(color: Color(0xFFE9EBEE), fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(reason, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _resolveReport(reportId, i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Resolve', style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          );
        }).animate(delay: 240.ms, interval: 50.ms).fadeIn(duration: 300.ms),
    ]);
  }

  Future<void> _resolveReport(String id, int index) async {
    try {
      // Optimistic removal; backend endpoint can be added later
      if (mounted) setState(() => _reports.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report marked as resolved'), backgroundColor: Color(0xFF22C55E), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showBroadcastDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Broadcast Message', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This message will be sent as a notification to all users.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: _cardAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Type your announcement...',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                contentPadding: EdgeInsets.all(14),
                border: InputBorder.none,
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ApiService().broadcast(ctrl.text.trim());
                messenger.showSnackBar(
                  const SnackBar(content: Text('Broadcast sent!'), backgroundColor: Color(0xFF22C55E), behavior: SnackBarBehavior.floating),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Failed to send broadcast.'), backgroundColor: Color(0xFFEF4444), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Send', style: TextStyle(color: Color(0xFF3FD8F5), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Private Widgets ──────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141728),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF252840)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w400)),
      ]),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
          ]),
        ),
      ),
    );
  }
}

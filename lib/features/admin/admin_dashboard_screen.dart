// lib/features/admin/admin_dashboard_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../../core/router/app_router.dart';
import 'widgets/admin_toast.dart';
import 'admin_content_screen.dart' show AddFlatmateSheet;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // ── Modern Dark Palette matching the design ──────────────────────────────
  static const _bg        = Color(0xFF080C14);
  static const _card      = Color(0xFF0D121E);
  static const _cardAlt   = Color(0xFF13192A);
  static const _border    = Color(0xFF172033);

  // Accent Colors
  static const _cyan      = Color(0xFF38BDF8);
  static const _green     = Color(0xFF10B981);
  static const _red       = Color(0xFFEF4444);
  static const _amber     = Color(0xFFF59E0B);
  static const _purple    = Color(0xFF818CF8);
  static const _textMuted = Color(0xFF64748B);
  static const _textLight = Color(0xFF94A3B8);

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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken(true);
        if (token != null && token.isNotEmpty) {
          ApiService().setToken(token);
        }
      }

      Map<String, dynamic>? stats;
      List<Map<String, dynamic>> reports = [];
      String? loadError;

      try {
        stats = await ApiService().getAdminStats();
      } catch (e) {
        loadError = e.toString();
        debugPrint('Admin stats fetch error: $e');
      }

      try {
        final reportsData = await ApiService().getReportsQueue();
        final rawReports = reportsData['data'] ?? reportsData['reports'] ?? reportsData['items'] ?? [];
        if (rawReports is List) {
          reports = rawReports.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (e) {
        debugPrint('Admin reports fetch error: $e');
      }

      if (mounted) {
        if (stats == null && loadError != null) {
          setState(() {
            _loading = false;
            _error = loadError;
          });
        } else {
          setState(() {
            _stats = stats ?? {};
            _reports = reports;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _formatErrorMessage(String? err) {
    if (err == null) return 'Something went wrong';
    if (err.contains('500')) {
      return 'Server is updating or encountered a temporary error. Please tap below to retry.';
    }
    if (err.contains('401') || err.contains('403')) {
      return 'Session expired or admin privileges required. Please sign in again.';
    }
    if (err.contains('SocketException') || err.contains('connection refused') || err.contains('timeout')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }
    return err;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getGreetingSubtitle(int pendingCount, int incompleteCount) {
    final reportPart = pendingCount == 0
        ? 'No reports to review.'
        : '$pendingCount ${pendingCount == 1 ? 'report' : 'reports'} to review.';
    final incompletePart = incompleteCount == 0
        ? 'All profiles are complete.'
        : '$incompleteCount ${incompleteCount == 1 ? 'profile is' : 'profiles are'} missing details.';
    return '$reportPart $incompletePart';
  }

  static Color _getAvatarColor(String name) {
    const colors = [
      Color(0xFF8B5CF6), // Purple
      Color(0xFFF59E0B), // Orange
      Color(0xFF10B981), // Green
      Color(0xFFF43F5E), // Coral / Red
      Color(0xFF38BDF8), // Cyan
      Color(0xFF3B82F6), // Blue
      Color(0xFFEC4899), // Pink
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (sum, char) => sum + char);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats ?? {};
    final totalUsers = (s['total_users'] ?? s['totalUsers'] ?? s['users'] ?? '0').toString();
    final activeToday = (s['active_today'] ?? s['activeToday'] ?? '0').toString();
    final totalPosts = (s['total_posts'] ?? s['totalPosts'] ?? '0').toString();
    final totalAuthors = (s['total_authors'] ?? totalPosts).toString();
    final pendingCount = int.tryParse((s['pending_reports'] ?? _reports.length).toString()) ?? _reports.length;
    final incompleteCount = int.tryParse((s['incomplete_profiles'] ?? '0').toString()) ?? 0;
    final bannedCount = int.tryParse((s['banned_users'] ?? '0').toString()) ?? 0;

    final recentUsers = (s['recent_users'] is List) ? (s['recent_users'] as List) : [];
    final roleDist = (s['role_distribution'] is Map)
        ? Map<String, dynamic>.from(s['role_distribution'] as Map)
        : {'students': 0, 'faculty': 0, 'admins': 0};

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
              // Greeting & Subtitle (matching Image 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getGreetingSubtitle(pendingCount, incompleteCount),
                        style: const TextStyle(
                          color: _textLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Loading or Error states
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _cyan),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: _red, size: 48),
                          const SizedBox(height: 14),
                          const Text('Failed to load dashboard data', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(_formatErrorMessage(_error), style: const TextStyle(color: _textMuted, fontSize: 13), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cyan,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Total Users Primary Banner Card (Image 1 top card)
                      _buildTotalUsersCard(
                        totalUsers: totalUsers,
                        recentUsers: recentUsers,
                        roleDist: roleDist,
                        onTap: () => context.push('/admin/users'),
                      ),
                      const SizedBox(height: 16),

                      // 2. Metrics Grid (Active today & Total posts)
                      Row(
                        children: [
                              Expanded(
                                child: _MetricCard(
                                  icon: Icons.trending_up_rounded,
                                  iconColor: _green,
                                  iconBgColor: _green.withValues(alpha: 0.12),
                                  value: activeToday,
                                  title: 'Active today',
                                  subtitle: activeToday == '—' || activeToday == '0'
                                      ? 'No activity data yet'
                                      : '$activeToday active members',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _MetricCard(
                                  icon: Icons.article_outlined,
                                  iconColor: _amber,
                                  iconBgColor: _amber.withValues(alpha: 0.12),
                                  value: totalPosts,
                                  title: 'Total posts',
                                  subtitle: 'From $totalAuthors members',
                                ),
                              ),
                            ],
                          ),
                      const SizedBox(height: 14),

                      // 3. Reports Metric Card
                      _MetricCard(
                        icon: Icons.flag_outlined,
                        iconColor: _red,
                        iconBgColor: _red.withValues(alpha: 0.12),
                        value: pendingCount.toString(),
                        title: 'Reports',
                        subtitle: pendingCount == 0 ? 'All clear' : '$pendingCount pending review',
                        onTap: () => _openReportsSheet(context),
                      ),
                      const SizedBox(height: 28),

                      // 4. Quick Actions (Image 2)
                      const Text(
                        'Quick actions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildQuickActions(context),
                      const SizedBox(height: 28),

                      // 5. Needs Attention (Image 2)
                      const Text(
                        'Needs attention',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildNeedsAttention(
                        context,
                        pendingReports: pendingCount,
                        incompleteCount: incompleteCount,
                        bannedCount: bannedCount,
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Total Users Card (Image 1 top card) ───────────────────────────────────
  Widget _buildTotalUsersCard({
    required String totalUsers,
    required List recentUsers,
    required Map<String, dynamic> roleDist,
    required VoidCallback onTap,
  }) {
    // Generate fallback avatars if list is empty
    final avatarList = recentUsers.isNotEmpty
        ? recentUsers
        : [
            {'name': 'Imperiial'},
            {'name': 'Mohit'},
            {'name': 'Karan'},
            {'name': 'Vikas'},
            {'name': 'Aman'},
          ];

    final students = (roleDist['students'] as num? ?? 4).toDouble();
    final faculty  = (roleDist['faculty'] as num? ?? 1).toDouble();
    final admins   = (roleDist['admins'] as num? ?? 1).toDouble();
    final sumRoles = students + faculty + admins;
    final totalFlex = sumRoles > 0 ? sumRoles : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top User Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.people_outline_rounded, color: _cyan, size: 20),
            ),
            const SizedBox(height: 16),

            // Giant Stat
            Text(
              totalUsers,
              style: const TextStyle(
                color: _cyan,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),

            // Label
            const Text(
              'Total users',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),

            // Avatars row (I, M, K, V, A...)
            Row(
              children: avatarList.take(6).map((u) {
                final uname = (u['name'] ?? u['full_name'] ?? 'U').toString();
                final letter = uname.isNotEmpty ? uname[0].toUpperCase() : 'U';
                final color = _getAvatarColor(uname);
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: _card, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Segmented Horizontal Progress Bar (Cyan, Purple, Amber, Green)
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Row(
                children: [
                  Expanded(
                    flex: ((students / totalFlex) * 100).toInt().clamp(1, 100),
                    child: Container(height: 5, color: _cyan),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((faculty / totalFlex) * 100).toInt().clamp(1, 100),
                    child: Container(height: 5, color: _purple),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((admins / totalFlex) * 100).toInt().clamp(1, 100),
                    child: Container(height: 5, color: _amber),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 15,
                    child: Container(height: 5, color: _green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions Grid (Image 2) ──────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.local_offer_outlined,
                iconColor: _amber,
                iconBgColor: _amber.withValues(alpha: 0.12),
                title: 'Add deal',
                subtitle: 'Offer for students',
                onTap: () => context.push(AppRoutes.adminAddDeal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.calendar_today_outlined,
                iconColor: _cyan,
                iconBgColor: _cyan.withValues(alpha: 0.12),
                title: 'Add event',
                subtitle: 'Fest, meetup, workshop',
                onTap: () => context.push('/admin/add-event'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.home_work_outlined,
                iconColor: _purple,
                iconBgColor: _purple.withValues(alpha: 0.12),
                title: 'Flatmates',
                subtitle: 'Manage listings',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddFlatmateSheet(),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.campaign_outlined,
                iconColor: _green,
                iconBgColor: _green.withValues(alpha: 0.12),
                title: 'Broadcast',
                subtitle: 'Message all users',
                onTap: () => _showBroadcastDialog(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Needs Attention Container (Image 2) ───────────────────────────────────
  Widget _buildNeedsAttention(
    BuildContext context, {
    required int pendingReports,
    required int incompleteCount,
    required int bannedCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // 1. Reports Option
          _AttentionRow(
            icon: pendingReports == 0 ? Icons.check_circle_outline_rounded : Icons.flag_rounded,
            iconColor: pendingReports == 0 ? _green : _red,
            iconBgColor: (pendingReports == 0 ? _green : _red).withValues(alpha: 0.12),
            title: pendingReports == 0 ? 'No pending reports' : '$pendingReports pending reports',
            subtitle: pendingReports == 0 ? 'Nothing to moderate right now' : 'Tap to review and moderate reported posts',
            showChevron: pendingReports > 0,
            onTap: () => _openReportsSheet(context),
          ),
          Divider(color: _border, height: 1, indent: 64, endIndent: 16),

          // 2. Incomplete Information Option
          _AttentionRow(
            icon: Icons.warning_amber_rounded,
            iconColor: _amber,
            iconBgColor: _amber.withValues(alpha: 0.12),
            title: incompleteCount == 0 ? 'All profiles complete' : '$incompleteCount incomplete profiles',
            subtitle: 'Missing college or location',
            showChevron: true,
            onTap: () => _openIncompleteProfilesSheet(context),
          ),
          Divider(color: _border, height: 1, indent: 64, endIndent: 16),

          // 3. Blocked / Banned Option
          _AttentionRow(
            icon: Icons.block_rounded,
            iconColor: _red,
            iconBgColor: _red.withValues(alpha: 0.12),
            title: bannedCount == 0 ? '0 banned users' : '$bannedCount banned users',
            subtitle: bannedCount == 0 ? 'No one is banned' : 'Tap to review blocked accounts',
            showChevron: true,
            onTap: () => _openBannedUsersSheet(context),
          ),
        ],
      ),
    );
  }

  // ── 1. REPORTED POSTS MODAL SHEET ─────────────────────────────────────────
  void _openReportsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportsModalSheet(
        reports: _reports,
        onRefreshNeeded: _load,
      ),
    );
  }

  // ── 2. INCOMPLETE PROFILES MODAL SHEET ─────────────────────────────────────
  void _openIncompleteProfilesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IncompleteProfilesModalSheet(
        onRefreshNeeded: _load,
      ),
    );
  }

  // ── 3. BANNED USERS MODAL SHEET ───────────────────────────────────────────
  void _openBannedUsersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BannedUsersModalSheet(
        onRefreshNeeded: _load,
      ),
    );
  }

  // ── Broadcast Dialog ──────────────────────────────────────────────────────
  void _showBroadcastDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _border)),
        title: const Text('Broadcast Message', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This announcement will be delivered to all registered campus members.',
              style: TextStyle(color: _textLight, fontSize: 13),
            ),
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Type announcement content...',
                  hintStyle: TextStyle(color: _textMuted),
                  contentPadding: EdgeInsets.all(14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiService().broadcast(text);
                if (context.mounted) {
                  AdminToast.success(context, 'Announcement broadcasted successfully!');
                }
              } catch (_) {
                if (context.mounted) {
                  AdminToast.error(context, 'Failed to broadcast message.');
                }
              }
            },
            child: const Text('Broadcast', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Metric Card Widget (Matching Image 1 & 2) ─────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0D121E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF172033)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 14),

            // Number Value
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),

            // Title
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),

            // Subtitle
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Action Card (Image 2) ──────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D121E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF172033)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// ── Needs Attention Row Tile (Image 2) ───────────────────────────────────────
class _AttentionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool showChevron;
  final VoidCallback onTap;

  const _AttentionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.showChevron,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 20),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. REPORTS MODERATION MODAL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _ReportsModalSheet extends StatefulWidget {
  final List<Map<String, dynamic>> reports;
  final VoidCallback onRefreshNeeded;

  const _ReportsModalSheet({required this.reports, required this.onRefreshNeeded});

  @override
  State<_ReportsModalSheet> createState() => _ReportsModalSheetState();
}

class _ReportsModalSheetState extends State<_ReportsModalSheet> {
  late List<Map<String, dynamic>> _list;
  String? _actingReportId;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.reports);
  }

  Future<void> _handleResolve(String reportId, String action) async {
    setState(() => _actingReportId = reportId);
    try {
      await ApiService().resolveReport(reportId, action);
      if (mounted) {
        setState(() {
          _list.removeWhere((r) => (r['id'] ?? r['_id']).toString() == reportId);
          _actingReportId = null;
        });
        widget.onRefreshNeeded();
        final msg = action == 'delete_content'
            ? 'Reported post has been hidden and removed from feed.'
            : action == 'ban_user'
                ? 'User has been banned.'
                : action == 'delete_and_ban'
                    ? 'Post removed and user banned.'
                    : 'Report dismissed.';
        if (mounted) {
          AdminToast.success(context, msg);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actingReportId = null);
        AdminToast.error(context, 'Action failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B101D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF1E283D))),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFF28354D), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Color(0xFFEF4444), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reported Posts Moderation',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_list.length} pending ${_list.length == 1 ? 'report' : 'reports'} to review',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF172033), height: 1),

          // Content
          Expanded(
            child: _list.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 54),
                        SizedBox(height: 12),
                        Text(
                          'No pending reports',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text('All reported content has been reviewed.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (ctx, i) {
                      final r = _list[i];
                      final reportId = (r['id'] ?? r['_id'] ?? '').toString();
                      final reason = (r['reason'] ?? 'Inappropriate content').toString();
                      final isBusy = _actingReportId == reportId;

                      // Reporter info
                      final reporter = r['reporter'] is Map ? r['reporter'] as Map : {};
                      final reporterName = (reporter['name'] ?? r['reporter_name'] ?? 'User').toString();
                      final reporterEmail = (reporter['email'] ?? '').toString();

                      // Target / Post info
                      final target = r['target_details'] is Map ? r['target_details'] as Map : {};
                      final author = target['author'] is Map ? target['author'] as Map : {};
                      final authorName = (author['name'] ?? 'Post Author').toString();
                      final authorEmail = (author['email'] ?? '').toString();
                      final postContent = (target['content'] ?? r['content'] ?? 'Post content').toString();
                      final postImage = (target['image_url'] ?? r['image_url'])?.toString();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1524),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E283D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Reporter & Reason
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                  child: const Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444), size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: 'Reported by ',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                          children: [
                                            TextSpan(
                                              text: reporterName,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                            ),
                                            if (reporterEmail.isNotEmpty)
                                              TextSpan(
                                                text: ' ($reporterEmail)',
                                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2C1014),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Reason: $reason',
                                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Reported Post Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A0E18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF1A2234)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, color: Color(0xFF38BDF8), size: 15),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Author: $authorName ${authorEmail.isNotEmpty ? '($authorEmail)' : ''}',
                                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    postContent,
                                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, height: 1.3),
                                  ),
                                  if (postImage != null && postImage.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        postImage,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Action Buttons
                            if (isBusy)
                              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Color(0xFF38BDF8))))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // 1. Hide / Remove Post button
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                    label: const Text('Hide / Remove Post', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    onPressed: () => _handleResolve(reportId, 'delete_content'),
                                  ),

                                  // 2. Ban Author button
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444),
                                      side: const BorderSide(color: Color(0xFF3B151C)),
                                      backgroundColor: const Color(0xFF1E1114),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.block_rounded, size: 15),
                                    label: const Text('Ban Author', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    onPressed: () => _handleResolve(reportId, 'ban_user'),
                                  ),

                                  // 3. Dismiss Report
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF64748B),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                                    onPressed: () => _handleResolve(reportId, 'dismiss'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. INCOMPLETE PROFILES MODAL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _IncompleteProfilesModalSheet extends StatefulWidget {
  final VoidCallback onRefreshNeeded;
  const _IncompleteProfilesModalSheet({required this.onRefreshNeeded});

  @override
  State<_IncompleteProfilesModalSheet> createState() => _IncompleteProfilesModalSheetState();
}

class _IncompleteProfilesModalSheetState extends State<_IncompleteProfilesModalSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchIncompleteUsers();
  }

  Future<void> _fetchIncompleteUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().getAdminUsers(incomplete: true, limit: 100);
      final raw = res['data'] ?? res['users'] ?? [];
      if (mounted) {
        setState(() {
          _users = (raw is List) ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _contactEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=CampusSetu%20Profile%20Completion&body=Hi%2C%20please%20complete%20your%20CampusSetu%20profile%20details.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: email));
      if (mounted) {
        AdminToast.info(context, 'Email copied to clipboard: $email');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B101D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF1E283D))),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFF28354D), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Incomplete Profiles',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_users.length} members with missing registration info',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF172033), height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
                    : _users.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 52),
                                SizedBox(height: 12),
                                Text(
                                  'All profiles complete!',
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 4),
                                Text('Every registered member has filled their details.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final u = _users[i];
                              final name = (u['name'] ?? 'Unknown').toString();
                              final email = (u['email'] ?? '').toString();
                              final college = (u['college'] ?? u['college_name'] ?? '').toString().trim();
                              final state = (u['state'] ?? '').toString().trim();
                              final city = (u['city'] ?? '').toString().trim();
                              final branch = (u['branch'] ?? '').toString().trim();
                              final year = (u['year_of_study'] ?? u['year'] ?? '').toString().trim();

                              final missingFields = <String>[];
                              if (college.isEmpty) missingFields.add('College');
                              if (state.isEmpty || city.isEmpty) missingFields.add('City/State');
                              if (branch.isEmpty) missingFields.add('Branch');
                              if (year.isEmpty || year == 'null') missingFields.add('Year');

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1524),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF1E283D)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: _AdminDashboardScreenState._getAvatarColor(name),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 2),
                                          Text(email, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: missingFields.map((f) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  'Missing: $f',
                                                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      tooltip: 'Contact via Email',
                                      icon: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8), size: 20),
                                      onPressed: () => _contactEmail(email),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. BANNED USERS MODAL SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _BannedUsersModalSheet extends StatefulWidget {
  final VoidCallback onRefreshNeeded;
  const _BannedUsersModalSheet({required this.onRefreshNeeded});

  @override
  State<_BannedUsersModalSheet> createState() => _BannedUsersModalSheetState();
}

class _BannedUsersModalSheetState extends State<_BannedUsersModalSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bannedUsers = [];
  String? _actingUserId;

  @override
  void initState() {
    super.initState();
    _fetchBannedUsers();
  }

  Future<void> _fetchBannedUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().getAdminUsers(isBanned: true, limit: 100);
      final raw = res['data'] ?? res['users'] ?? [];
      if (mounted) {
        setState(() {
          _bannedUsers = (raw is List) ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _unblock(String userId, String name) async {
    setState(() => _actingUserId = userId);
    try {
      await ApiService().unblockUser(userId);
      if (mounted) {
        setState(() {
          _bannedUsers.removeWhere((u) => u['id'].toString() == userId);
          _actingUserId = null;
        });
        widget.onRefreshNeeded();
        if (mounted) {
          AdminToast.success(context, '$name has been unblocked.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actingUserId = null);
        AdminToast.error(context, 'Failed to unblock: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B101D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF1E283D))),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFF28354D), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blocked Accounts',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_bannedUsers.length} banned ${_bannedUsers.length == 1 ? 'user' : 'users'}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF172033), height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
                    : _bannedUsers.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 52),
                                SizedBox(height: 12),
                                Text(
                                  'No banned users',
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 4),
                                Text('All community members are active and unblocked.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _bannedUsers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final u = _bannedUsers[i];
                              final uid = u['id'].toString();
                              final name = (u['name'] ?? 'Unknown').toString();
                              final email = (u['email'] ?? '').toString();
                              final college = (u['college'] ?? u['college_name'] ?? '').toString();
                              final isBusy = _actingUserId == uid;

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1524),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF1E283D)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 2),
                                          Text(email, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                          if (college.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(college, style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (isBusy)
                                      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2))
                                    else
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          foregroundColor: const Color(0xFF10B981),
                                          side: const BorderSide(color: Color(0xFF10B981)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                        icon: const Icon(Icons.lock_open_rounded, size: 15),
                                        label: const Text('Unblock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        onPressed: () => _unblock(uid, name),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

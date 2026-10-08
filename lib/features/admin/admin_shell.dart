// lib/features/admin/admin_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import 'widgets/admin_toast.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_tasks_screen.dart';
import 'admin_events_screen.dart';
import 'admin_faculty_screen.dart';
import 'admin_wallpapers_screen.dart';
import 'admin_content_screen.dart';
import 'admin_ambassadors_screen.dart';
import 'admin_points_transfers_screen.dart';
import 'admin_pulse_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  bool _isCollapsed = true; // Collapsed by default matching user image

  static const _bg     = Color(0xFF080C14);
  static const _card   = Color(0xFF0D121E);
  static const _border = Color(0xFF172033);

  final _navDefinitions = const [
    (Icons.grid_view_rounded, Icons.grid_view_rounded, 'Overview', Color(0xFF38BDF8)),
    (Icons.people_outline_rounded, Icons.people_rounded, 'Users', Color(0xFF38BDF8)),
    (Icons.assignment_outlined, Icons.assignment_rounded, 'Tasks', Color(0xFF10B981)),
    (Icons.event_outlined, Icons.event_rounded, 'Events', Color(0xFF38BDF8)),
    (Icons.school_outlined, Icons.school_rounded, 'Faculty', Color(0xFF818CF8)),
    (Icons.wallpaper_outlined, Icons.wallpaper_rounded, 'Wallpapers', Color(0xFFA855F7)),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Deals', Color(0xFFF59E0B)),
    (Icons.campaign_outlined, Icons.campaign_rounded, 'Ambassadors', Color(0xFFF59E0B)),
    (Icons.swap_horiz_rounded, Icons.swap_horiz_rounded, 'Transfers', Color(0xFF10B981)),
    (Icons.track_changes_outlined, Icons.track_changes_rounded, 'Pulse', Color(0xFF10B981)),
  ];

  Future<void> _handleSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1524),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E283D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out from the Admin Console?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && context.mounted) {
      try {
        await AuthService().signOut();
        if (context.mounted) {
          AdminToast.success(context, 'Signed out successfully');
          try {
            context.go('/admin-login');
          } catch (_) {
            context.go(AppRoutes.welcome);
          }
        }
      } catch (e) {
        if (context.mounted) {
          try {
            context.go('/admin-login');
          } catch (_) {
            context.go(AppRoutes.welcome);
          }
        }
      }
    }
  }

  void _showUsers() {
    if (!mounted || _tab == 1) return;
    setState(() => _tab = 1);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    final screens = [
      AdminDashboardScreen(onNavigateToUsers: _showUsers),
      const AdminUsersScreen(),
      const AdminTasksScreen(),
      const AdminEventsScreen(),
      const AdminFacultyScreen(),
      const AdminWallpapersScreen(),
      const AdminContentScreen(),
      const AdminAmbassadorsScreen(),
      const AdminPointsTransfersScreen(),
      const AdminPulseScreen(),
    ];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: _bg,
        body: Row(
          children: [
            // ── Desktop Left Sidebar (Collapsible with matching design) ───────
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              width: _isCollapsed ? 58 : 220,
              decoration: const BoxDecoration(
                color: _card,
                border: Border(right: BorderSide(color: _border, width: 1)),
              ),
              child: Column(
                children: [
                  SizedBox(height: _isCollapsed ? 8 : 16),

                  // Header / Toggle Icon
                  if (_isCollapsed)
                    IconButton(
                      tooltip: 'Expand Sidebar',
                      icon: const Icon(Icons.menu_rounded, color: Color(0xFF94A3B8), size: 20),
                      onPressed: () => setState(() => _isCollapsed = false),
                      splashRadius: 18,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'CampusSetu',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF64748B), size: 20),
                            onPressed: () => setState(() => _isCollapsed = true),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: _isCollapsed ? 6 : 12),
                  const Divider(color: _border, height: 1),
                  SizedBox(height: _isCollapsed ? 8 : 14),

                  // Sidebar Navigation Items
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 6 : 10),
                      itemCount: _navDefinitions.length,
                      itemBuilder: (ctx, i) {
                        final def = _navDefinitions[i];
                        final isSelected = _tab == i;
                        final accent = def.$4;

                        if (_isCollapsed) {
                          // Icon-only compact collapsed view
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Tooltip(
                              message: def.$3,
                              preferBelow: false,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(() => _tab = i),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF092330) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(color: const Color(0xFF0369A1).withValues(alpha: 0.7), width: 1.5)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isSelected ? def.$2 : def.$1,
                                      color: isSelected ? accent : const Color(0xFF64748B),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        // Expanded view with text labels
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _tab = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? accent.withValues(alpha: 0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? Border.all(color: accent.withValues(alpha: 0.3)) : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? def.$2 : def.$1,
                                    color: isSelected ? accent : const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      def.$3,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Controls (Signout + Green Shield)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isCollapsed ? 6 : 10,
                      vertical: _isCollapsed ? 8 : 14,
                    ),
                    child: Column(
                      children: [
                        // Signout Button
                        if (_isCollapsed)
                          Tooltip(
                            message: 'Sign Out',
                            preferBelow: false,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _handleSignOut(context),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1114),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF3B151C)),
                                ),
                                child: const Center(
                                  child: Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 17),
                                ),
                              ),
                            ),
                          )
                        else
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _handleSignOut(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1114),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF3B151C)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 18),
                                  SizedBox(width: 10),
                                  Text(
                                    'Sign Out',
                                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        SizedBox(height: _isCollapsed ? 6 : 12),

                        // Bottom Green Shield Icon Container
                        if (_isCollapsed)
                          Tooltip(
                            message: 'Super Admin Security Active',
                            preferBelow: false,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF06231A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: const Center(
                                child: Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 18),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06231A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Super Admin Active',
                                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Content Area ─────────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile View
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: const Text('CampusSetu Admin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 20),
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _card,
          border: Border(top: BorderSide(color: _border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: List.generate(_navDefinitions.length, (i) {
                  final def = _navDefinitions[i];
                  return _NavItem(
                    icon: def.$1,
                    activeIcon: def.$2,
                    label: def.$3,
                    index: i,
                    current: _tab,
                    accentColor: def.$4,
                    onTap: (idx) => setState(() => _tab = idx),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;
  final Color? accentColor;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final color = accentColor ?? const Color(0xFF38BDF8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? color : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : const Color(0xFF64748B),
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

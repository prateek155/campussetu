// lib/features/admin/admin_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_content_screen.dart';
import 'admin_pulse_screen.dart';
import 'admin_faculty_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  static const _bg = Color(0xFF0D0F1A);
  static const _card = Color(0xFF141728);
  static const _border = Color(0xFF252840);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    final navDefinitions = [
      (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Overview', const Color(0xFF3FD8F5)),
      (Icons.people_outline, Icons.people_rounded, 'Users', const Color(0xFF3FD8F5)),
      (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Content', const Color(0xFF3FD8F5)),
      (Icons.radar_outlined, Icons.radar, 'Pulse', const Color(0xFF22C55E)),
      (Icons.school_outlined, Icons.school_rounded, 'Faculty', const Color(0xFF6C63FF)),
    ];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: _bg,
        body: Row(
          children: [
            // ── Desktop Left Sidebar ────────────────────────
            Container(
              width: 230,
              decoration: const BoxDecoration(
                color: _card,
                border: Border(right: BorderSide(color: _border, width: 1)),
              ),
              child: Column(
                children: [
                  // Logo header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF3FD8F5), Color(0xFF1BA8C4)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('CampusSetu', style: TextStyle(color: Color(0xFFE9EBEE), fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('ADMIN CONSOLE', style: TextStyle(color: Color(0xFF3FD8F5), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: _border, height: 1),
                  const SizedBox(height: 16),

                  // Sidebar Nav Items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: navDefinitions.length,
                      itemBuilder: (ctx, i) {
                        final def = navDefinitions[i];
                        final isSelected = _tab == i;
                        final accent = def.$4;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _tab = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: isSelected ? accent.withValues(alpha: 0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? Border.all(color: accent.withValues(alpha: 0.3)) : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? def.$2 : def.$1,
                                    color: isSelected ? accent : const Color(0xFF9CA3AF),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    def.$3,
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFFE9EBEE) : const Color(0xFF9CA3AF),
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 14,
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

                  // Sidebar Footer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.verified_user_rounded, color: Color(0xFF22C55E), size: 16),
                          SizedBox(width: 8),
                          Text('Super Admin Active', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Content ────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  AdminDashboardScreen(),
                  AdminUsersScreen(),
                  AdminContentScreen(),
                  AdminPulseScreen(),
                  AdminFacultyScreen(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _tab,
        children: const [
          AdminDashboardScreen(),
          AdminUsersScreen(),
          AdminContentScreen(),
          AdminPulseScreen(),
          AdminFacultyScreen(),
        ],
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
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Overview',
                  index: 0,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                _NavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people_rounded,
                  label: 'Users',
                  index: 1,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                _NavItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: 'Content',
                  index: 2,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                _NavItem(
                  icon: Icons.radar_outlined,
                  activeIcon: Icons.radar,
                  label: 'Pulse',
                  index: 3,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                  accentColor: const Color(0xFF22C55E),
                ),
                _NavItem(
                  icon: Icons.school_outlined,
                  activeIcon: Icons.school_rounded,
                  label: 'Faculty',
                  index: 4,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                  accentColor: const Color(0xFF6C63FF),
                ),
              ],
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
    final color = accentColor ?? const Color(0xFF3FD8F5);
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? color : const Color(0xFF9CA3AF),
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? color : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

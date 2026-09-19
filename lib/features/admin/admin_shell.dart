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

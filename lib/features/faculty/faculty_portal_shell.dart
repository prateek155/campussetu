import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const facultyBg = Color(0xFF0F172A);
const facultySurface = Color(0xFF17233F);
const facultyBorder = Color(0xFF263654);
const facultyAccent = Color(0xFFE28B16);

class FacultyPortalShell extends StatelessWidget {
  final Widget child;
  const FacultyPortalShell({super.key, required this.child});

  static const _items = <({String label, String path, IconData icon, String group})>[
    (label: 'Dashboard', path: '/faculty/dashboard', icon: Icons.dashboard_outlined, group: 'Overview'),
    (label: 'Live Quiz', path: '/faculty/quizzes', icon: Icons.bolt_rounded, group: 'Assessments'),
    (label: 'Paper Tests', path: '/faculty/tests', icon: Icons.fact_check_outlined, group: 'Assessments'),
    (label: 'Question Bank', path: '/faculty/question-bank', icon: Icons.menu_book_outlined, group: 'Assessments'),
    (label: 'Results & Analytics', path: '/faculty/analytics', icon: Icons.query_stats_rounded, group: 'Assessments'),
    (label: 'File Converter', path: '/faculty/tools', icon: Icons.swap_horiz_rounded, group: 'Tools'),
  ];

  int _selectedIndex(String location) {
    for (var i = 0; i < _items.length; i++) {
      if (location == _items[i].path || location.startsWith('${_items[i].path}/')) return i;
    }
    if (location.startsWith('/faculty/quizzes/create')) return 1;
    return 0;
  }

  void _go(BuildContext context, int index) => context.go(_items[index].path);

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _selectedIndex(location);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 950;

    if (!isWide) {
      return Scaffold(
        backgroundColor: facultyBg,
        body: SafeArea(child: child),
        bottomNavigationBar: NavigationBar(
          height: 66,
          backgroundColor: const Color(0xFF0B1222),
          indicatorColor: facultyAccent.withValues(alpha: 0.2),
          selectedIndex: switch (selected) { 0 => 0, 1 => 1, 2 => 2, 4 => 3, _ => 4 },
          onDestinationSelected: (index) {
            const routes = [0, 1, 2, 4];
            if (index < routes.length) {
              _go(context, routes[index]);
            } else {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: facultySurface,
                builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(leading: const Icon(Icons.menu_book_outlined), title: const Text('Question Bank'), onTap: () { Navigator.pop(sheetContext); _go(context, 3); }),
                  ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: const Text('File Converter'), onTap: () { Navigator.pop(sheetContext); _go(context, 5); }),
                  ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('Sign out'), onTap: () async {
                    Navigator.pop(sheetContext);
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go('/faculty/login');
                  }),
                ])),
              );
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt_rounded), label: 'Live'),
            NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check_rounded), label: 'Tests'),
            NavigationDestination(icon: Icon(Icons.query_stats_outlined), selectedIcon: Icon(Icons.query_stats_rounded), label: 'Results'),
            NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: 'More'),
          ],
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Faculty');
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: facultyBg,
      body: Row(
        children: [
          Container(
            width: 254,
            decoration: const BoxDecoration(
              color: Color(0xFF0A1222),
              border: Border(right: BorderSide(color: facultyBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 16, 24),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: facultyAccent, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.school_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 11),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('CampusSetu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('Faculty Portal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ]),
                  ]),
                ),
                for (var i = 0; i < _items.length; i++) ...[
                  if (i == 0 || _items[i].group != _items[i - 1].group)
                    Padding(
                      padding: EdgeInsets.fromLTRB(22, i == 0 ? 0 : 18, 18, 7),
                      child: Text(_items[i].group.toUpperCase(), style: const TextStyle(color: Color(0xFF718096), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                    ),
                  _NavigationItem(
                    label: _items[i].label,
                    icon: _items[i].icon,
                    selected: selected == i,
                    onTap: () => _go(context, i),
                  ),
                ],
                const Spacer(),
                const Divider(color: facultyBorder, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 18),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: const Color(0xFF247C70), radius: 18, child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(user?.email ?? 'Faculty account', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                    ])),
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) context.go('/faculty/login');
                      },
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 18),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: const BoxDecoration(color: Color(0xFF101A30), border: Border(bottom: BorderSide(color: facultyBorder))),
                child: Row(children: [
                  const Icon(Icons.school_outlined, color: Color(0xFF94A3B8), size: 19),
                  const SizedBox(width: 9),
                  const Text('Faculty workspace', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
                  const Spacer(),
                  CircleAvatar(backgroundColor: const Color(0xFF247C70), radius: 17, child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
              ),
              Expanded(child: child),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavigationItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
        child: Material(
          color: selected ? const Color(0xFF17233F) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              height: 42,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border(left: BorderSide(color: selected ? facultyAccent : Colors.transparent, width: 3))),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(children: [
                Icon(icon, size: 19, color: selected ? Colors.white : const Color(0xFF9CAFC7)),
                const SizedBox(width: 11),
                Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFFB4C0D2), fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );
}

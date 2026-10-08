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
        appBar: AppBar(
          backgroundColor: const Color(0xFF101A30),
          elevation: 0,
          title: const Text('Faculty Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              tooltip: 'Notifications',
              onPressed: () => _showFacultyNotifications(context),
            ),
          ],
        ),
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
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFCBD5E1), size: 21),
                    tooltip: 'Notifications',
                    onPressed: () => _showFacultyNotifications(context),
                  ),
                  const SizedBox(width: 12),
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

  void _showFacultyNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF1E293B)),
      ),
      builder: (ctx) {
        final notifications = [
          {
            'icon': Icons.bolt_rounded,
            'color': const Color(0xFFE28B16),
            'title': 'Live Quiz Completed',
            'desc': '32 students submitted Database Systems Chapter 3 quiz',
            'time': '10m ago',
          },
          {
            'icon': Icons.fact_check_outlined,
            'color': const Color(0xFF34A783),
            'title': 'Paper Test Generated',
            'desc': 'Mid-Term Exam (Set A & B) ready for PDF download & print',
            'time': '1h ago',
          },
          {
            'icon': Icons.analytics_outlined,
            'color': const Color(0xFF38BDF8),
            'title': 'Analytics Report Ready',
            'desc': 'Class average score increased by 14% this week',
            'time': '3h ago',
          },
          {
            'icon': Icons.campaign_outlined,
            'color': const Color(0xFFA855F7),
            'title': 'Campus Academic Notice',
            'desc': 'Department review meeting scheduled for Friday 3:00 PM',
            'time': '1d ago',
          },
        ];

        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFFE28B16), size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Faculty Notifications',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE28B16).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${notifications.length} New',
                          style: const TextStyle(color: Color(0xFFE28B16), fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E293B), height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final n = notifications[idx];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF233252)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (n['color'] as Color).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(n['icon'] as IconData, color: n['color'] as Color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n['title'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    n['desc'] as String,
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              n['time'] as String,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
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

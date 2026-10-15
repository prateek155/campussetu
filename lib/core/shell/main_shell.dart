// lib/core/shell/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_providers.dart';
import '../providers/theme_provider.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bottom_nav_dock.dart';
import '../widgets/user_avatar.dart';
import '../router/app_router.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _baseNavItems = [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    NavItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, label: 'Connect'),
    NavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Money'),
    NavItem(icon: Icons.work_outline, activeIcon: Icons.work_rounded, label: 'Work'),
    NavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  static const _routes = [
    AppRoutes.home,
    AppRoutes.connect,
    AppRoutes.money,
    AppRoutes.jobs,
    AppRoutes.profile,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.helping)) return 3;
    for (int i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i].split('/:').first)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final jobsNew = ref.watch(jobsNewCountProvider).value ?? 0;
    final updateAsync = ref.watch(updateAvailableProvider);
    final updateInfo = updateAsync.value;
    final hasUpdate = updateInfo?.hasUpdate ?? false;
    final navItems = [
      _baseNavItems[0],
      _baseNavItems[1],
      _baseNavItems[2],
      _baseNavItems[3].copyWith(badgeCount: jobsNew),
      _baseNavItems[4],
    ];

    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        if (hasUpdate && updateInfo != null)
          Container(
            width: double.infinity,
            color: AppColors.cyanDeep,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, bottom: 8, left: 16, right: 16),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                const Icon(Icons.system_update_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Update v${updateInfo.latestVersion} available', style: AppTypography.interButton(color: Colors.white, size: 12))),
                GestureDetector(
                  onTap: () => showDialog(context: context, barrierDismissible: false, builder: (_) => _UpdateProgressDialog(info: updateInfo)),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text('Update', style: AppTypography.interButton(color: AppColors.cyanDeep, size: 12))),
                ),
              ]),
            ),
          ),

        // Desktop Web Top Header
        if (isDesktop)
          _DesktopHeader(
            navItems: navItems,
            selectedIndex: index,
            routes: _routes,
          ),

        // Main Body (Centered on Desktop)
        Expanded(
          child: isDesktop
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: child,
                  ),
                )
              : child,
        ),
      ]),
      extendBody: !isDesktop,
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavDock(
              currentIndex: index,
              items: navItems,
              onTap: (i) => context.go(_routes[i]),
            ),
    );
  }
}

class _UpdateProgressDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateProgressDialog({required this.info});
  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  double _progress = 0;
  String _status = 'Starting download...';
  bool _failed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      setState(() { _status = 'Downloading v${widget.info.latestVersion}...'; });
      final path = await UpdateService.downloadApk(widget.info.apkUrl!, onProgress: (r, t) {
        if (t > 0 && mounted) setState(() { _progress = r / t; _status = '${(_progress * 100).toInt()}% downloaded'; });
      });
      if (!mounted) return;
      setState(() { _status = 'Download complete, installing...'; });
      await UpdateService.installApk(path);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() { _failed = true; _error = e.toString(); _status = 'Failed'; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(_failed ? 'Update failed' : 'Updating...', style: AppTypography.soraHeading3()),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      if (!_failed) ...[
        LinearProgressIndicator(value: _progress == 0 ? null : _progress, color: AppColors.cyanDeep, backgroundColor: AppColors.shadowDark.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text(_status, style: AppTypography.interCaption(), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Please keep app open. You may need to allow "Install unknown apps" when prompted.', style: AppTypography.interCaption(color: AppColors.inkSoft), textAlign: TextAlign.center),
      ] else ...[
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
        const SizedBox(height: 8),
        Text(_error ?? 'Unknown error', style: AppTypography.interBody(color: AppColors.error, size: 13), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Try again or download manually from GitHub Releases.', style: AppTypography.interCaption(), textAlign: TextAlign.center),
      ],
    ]),
    actions: _failed
        ? [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: AppTypography.interButton(color: AppColors.inkSoft))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanDeep),
              onPressed: () { Navigator.pop(context); if (_error != null && _error!.contains('Install unknown apps')) { openAppSettings(); } },
              child: Text(_error != null && _error!.contains('Install unknown apps') ? 'Open Settings' : 'Retry', style: AppTypography.interButton(color: Colors.white, size: 13)),
            ),
          ]
        : [TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: AppTypography.interCaption()))],
  );
}

// ── Desktop Web Header ───────────────────────────────────────────────────────

class _DesktopHeader extends ConsumerWidget {
  final List<NavItem> navItems;
  final int selectedIndex;
  final List<String> routes;

  const _DesktopHeader({
    required this.navItems,
    required this.selectedIndex,
    required this.routes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final userAsync = ref.watch(currentUserProvider);

    // Header colors
    final headerBg = isDark ? const Color(0xFF161926) : Colors.white;
    final borderColor = isDark ? const Color(0xFF252A40) : const Color(0xFFE5E7EB);
    final inkColor = isDark ? const Color(0xFFE9EBEE) : const Color(0xFF1A1D24);
    final inkSoft = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    const accent = Color(0xFF3FD8F5);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                // ── Brand ────────────────────────────────────────
                GestureDetector(
                  onTap: () => context.go(AppRoutes.home),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3FD8F5), Color(0xFF1BA8C4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 19),
                      ),
                      const SizedBox(width: 10),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Campus',
                              style: TextStyle(
                                color: inkColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const TextSpan(
                              text: 'Setu',
                              style: TextStyle(
                                color: accent,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 40),

                // ── Navigation Links ─────────────────────────────
                Row(
                  children: List.generate(routes.length, (i) {
                    final item = navItems[i];
                    final isSelected = selectedIndex == i;
                    return _DesktopNavItem(
                      item: item,
                      isSelected: isSelected,
                      isDark: isDark,
                      accent: accent,
                      inkColor: inkColor,
                      inkSoft: inkSoft,
                      onTap: () => context.go(routes[i]),
                    );
                  }),
                ),

                const Spacer(),

                // ── Right Controls ───────────────────────────────
                Row(
                  children: [
                    // Theme toggle
                    _HeaderIconBtn(
                      icon: isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      tooltip: isDark ? 'Light mode' : 'Dark mode',
                      color: inkSoft,
                      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                    ),
                    const SizedBox(width: 4),
                    // Notifications
                    _HeaderIconBtn(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Notifications',
                      color: inkSoft,
                      onTap: () => context.push(AppRoutes.notifications),
                    ),
                    const SizedBox(width: 12),
                    // Profile avatar
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.profile),
                      child: userAsync.when(
                        data: (u) => Row(
                          children: [
                            UserAvatar(
                              name: u.name,
                              size: 34,
                              isVerified: u.isVerified,
                              imageUrl: u.photoUrl,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  u.name.split(' ').first,
                                  style: TextStyle(
                                    color: inkColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  u.college?.isNotEmpty == true
                                      ? (u.college!.length > 20
                                          ? '${u.college!.substring(0, 20)}…'
                                          : u.college!)
                                      : 'View Profile',
                                  style: TextStyle(
                                    color: inkSoft,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        loading: () => UserAvatar(name: '?', size: 34),
                        error: (_, __) => UserAvatar(name: '?', size: 34),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final bool isDark;
  final Color accent;
  final Color inkColor;
  final Color inkSoft;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.accent,
    required this.inkColor,
    required this.inkSoft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: isSelected
              ? Border(
                  bottom: BorderSide(color: accent, width: 2.5),
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 2),
            Badge(
              isLabelVisible: item.badgeCount > 0,
              label: Text('${item.badgeCount}',
                  style: const TextStyle(fontSize: 10)),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 17,
                color: isSelected ? accent : inkSoft,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                color: isSelected ? accent : inkSoft,
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

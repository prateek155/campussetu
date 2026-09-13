// lib/core/shell/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_providers.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bottom_nav_dock.dart';
import '../router/app_router.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _baseNavItems = [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    NavItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, label: 'Connect'),
    NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble_rounded, label: 'Chat'),
    NavItem(icon: Icons.work_outline, activeIcon: Icons.work_rounded, label: 'Work'),
    NavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  static const _routes = [
    AppRoutes.home,
    AppRoutes.connect,
    AppRoutes.chat,
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
    final chatUnread = ref.watch(chatUnreadCountProvider).value ?? 0;
    final jobsNew = ref.watch(jobsNewCountProvider).value ?? 0;
    final updateAsync = ref.watch(updateAvailableProvider);
    final updateInfo = updateAsync.value;
    final hasUpdate = updateInfo?.hasUpdate ?? false;
    final navItems = [
      _baseNavItems[0],
      _baseNavItems[1],
      _baseNavItems[2].copyWith(badgeCount: chatUnread),
      _baseNavItems[3].copyWith(badgeCount: jobsNew),
      _baseNavItems[4],
    ];
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
        Expanded(child: child),
      ]),
      extendBody: true,
      bottomNavigationBar: BottomNavDock(
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

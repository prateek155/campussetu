// lib/features/profile/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = 'v1.0.0';
  UpdateInfo? _updateInfo;
  bool _checking = true;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkUpdate();
  }

  Future<void> _loadVersion() async {
    try {
      final v = await UpdateService.getCurrentVersion();
      if (mounted) setState(() => _appVersion = 'v${v.split('+').first}');
    } catch (_) {}
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final info = await UpdateService.checkForUpdate();
    if (mounted) {
      setState(() {
        _updateInfo = info;
        _checking = false;
      });
    }
  }

  Future<void> _doUpdate() async {
    if (_updateInfo == null || !_updateInfo!.hasUpdate) return;
    if (_updateInfo!.latestVersion == 'PlayStore') {
      final ok = await UpdateService.performPlayStoreUpdate();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Play Store update not available')),
        );
      }
      return;
    }
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      final path = await UpdateService.downloadApk(
        _updateInfo!.apkUrl!,
        onProgress: (r, t) {
          if (t > 0 && mounted) setState(() => _progress = r / t);
        },
      );
      await UpdateService.installApk(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out?', style: AppTypography.soraHeading3()),
        content: Text(
          'Are you sure you want to sign out of your CampusSetu account?',
          style: AppTypography.interBody(color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.interButton(color: AppColors.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
              if (mounted) context.go(AppRoutes.welcome);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.soraHeading3()),
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        children: [
          // ── Section 1: Account & Security ─────────────
          _sectionHeader('ACCOUNT & SECURITY'),
          NeuCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _settingRow(
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Password & sign-in',
                  subtitle: 'Set or update account password',
                  trailing: Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
                  onTap: () => context.push(AppRoutes.accountPassword),
                ),
                Divider(color: AppColors.shadowDark.withValues(alpha: 0.15), height: 1),
                _settingRow(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Notifications',
                  subtitle: 'Push alerts & message preferences',
                  trailing: Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
                  onTap: () => context.push(AppRoutes.notificationPreferences),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: Preferences ────────────────────
          _sectionHeader('PREFERENCES'),
          NeuCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _settingRow(
                  icon: Icons.dark_mode_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Dark Mode',
                  subtitle: isDark ? 'Dark theme active' : 'Light theme active',
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                    activeThumbColor: AppColors.cyanDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 3: Legal & Information ───────────
          _sectionHeader('LEGAL & INFORMATION'),
          NeuCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _settingRow(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'Privacy Policy',
                  subtitle: 'How we handle and protect your data',
                  trailing: Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.inkSoft),
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                Divider(color: AppColors.shadowDark.withValues(alpha: 0.15), height: 1),
                _settingRow(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Terms & Conditions',
                  subtitle: 'Service terms and community guidelines',
                  trailing: Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.inkSoft),
                  onTap: () => context.push(AppRoutes.terms),
                ),
                Divider(color: AppColors.shadowDark.withValues(alpha: 0.15), height: 1),
                _settingRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.inkSoft,
                  title: 'App Version',
                  subtitle: 'Installed CampusSetu release',
                  trailing: Text(
                    _appVersion,
                    style: AppTypography.interCaption(color: AppColors.inkSoft).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 4: App Updates ────────────────────
          _sectionHeader('SOFTWARE UPDATES'),
          NeuCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_checking)
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text('Checking for updates...', style: AppTypography.interCaption()),
                    ],
                  ),

                if (!_checking && _updateInfo != null && _updateInfo!.hasUpdate) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Update available',
                              style: AppTypography.interButton(color: Colors.white, size: 14),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _updateInfo!.latestVersion,
                                style: AppTypography.interBadge(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        if (_updateInfo!.releaseNotes != null && _updateInfo!.releaseNotes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _updateInfo!.releaseNotes!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (_downloading) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_progress * 100).toInt()}% downloading...',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ] else
                          InkWell(
                            onTap: _doUpdate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Update Now →',
                                style: AppTypography.interButton(color: AppColors.cyanDeep, size: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                if (!_checking && (_updateInfo == null || !_updateInfo!.hasUpdate)) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your app is up to date',
                          style: AppTypography.interBody(size: 13).copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkUpdate,
                        child: Text('Check again', style: AppTypography.interCaption(color: AppColors.cyanDeep)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Section 5: Account Actions ────────────────
          NeuCard(
            padding: const EdgeInsets.all(16),
            onTap: _confirmSignOut,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign Out', style: AppTypography.interButton(color: AppColors.error)),
                      Text('Log out from this device', style: AppTypography.interCaption(color: AppColors.inkSoft)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.error.withValues(alpha: 0.6)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('To delete your account, please contact support@campussetu.in')),
                );
              },
              child: Text(
                'Delete Account',
                style: AppTypography.interCaption(color: AppColors.error).copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.interCaption(color: AppColors.inkSoft).copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: AppTypography.interBody(size: 14).copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTypography.interCaption(color: AppColors.inkSoft)),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      dense: false,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../alarm/alarm_service.dart';
import 'notification_preferences_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> with WidgetsBindingObserver {
  bool _loading = true;
  bool _announcements = false;
  bool _notificationPermission = false;
  bool _deviceAlertsInApp = true;
  bool _exactAlarm = false;
  bool _fullScreenAlarm = false;
  bool _alarmAlertsInApp = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final values = await Future.wait<bool>([
      NotificationPreferencesService.instance.announcementsEnabled(),
      _hasNotificationPermission(),
      AlarmService.hasExactAlarmAccess(),
      AlarmService.hasFullScreenAlarmAccess(),
      NotificationPreferencesService.instance.deviceAlertsEnabled(),
      NotificationPreferencesService.instance.alarmAlertsEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      _announcements = values[0];
      _notificationPermission = values[1];
      _exactAlarm = values[2];
      _fullScreenAlarm = values[3];
      _deviceAlertsInApp = values[4];
      _alarmAlertsInApp = values[5];
      _loading = false;
    });
  }

  Future<bool> _hasNotificationPermission() async {
    if (kIsWeb) return false;
    return (await Permission.notification.status).isGranted;
  }

  Future<void> _toggleAnnouncements(bool enabled) async {
    setState(() => _loading = true);
    try {
      final allowed = await NotificationPreferencesService.instance
          .setAnnouncementsEnabled(enabled);
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(kIsWeb
              ? 'Web push is not configured for this CampusSetu build.'
              : 'Allow notifications in device settings to turn this on.'),
        ));
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update notifications: $error')),
        );
      }
      await _refresh();
    }
  }

  Future<void> _toggleDeviceAlerts(bool enabled) async {
    if (!_notificationPermission) {
      // First time: request permission or open device settings
      final status = await Permission.notification.request();
      if (status.isGranted) {
        await NotificationPreferencesService.instance.setDeviceAlertsEnabled(true);
      } else {
        await openAppSettings();
      }
      await _refresh();
      return;
    }

    // Already allowed at device level: simply toggle in-app without going to settings
    await NotificationPreferencesService.instance.setDeviceAlertsEnabled(enabled);
    if (mounted) {
      setState(() => _deviceAlertsInApp = enabled);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enabled
            ? 'Device notifications active'
            : 'Device notifications muted in CampusSetu'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _toggleAlarmAlerts(bool enabled) async {
    if (!_exactAlarm) {
      await _requestAlarmPermissions();
      return;
    }

    // Already allowed on device: toggle in-app directly
    await NotificationPreferencesService.instance.setAlarmAlertsEnabled(enabled);
    if (mounted) {
      setState(() => _alarmAlertsInApp = enabled);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enabled
            ? 'Alarm alerts & ringtones active'
            : 'Alarm alerts muted in CampusSetu'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _requestAlarmPermissions() async {
    setState(() => _loading = true);
    try {
      final granted = await AlarmService.preparePermissions();
      if (granted) {
        await NotificationPreferencesService.instance.setAlarmAlertsEnabled(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enable exact alarms and full-screen alerts in device settings.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update alarm permissions: $error')),
        );
      }
    } finally {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Notification settings', style: AppTypography.soraHeading3()),
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
              children: [
                // ── Card 1: Campus Announcements ──
                NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cyanDeep.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: AppColors.cyanDeep, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Campus announcements', style: AppTypography.interButton(size: 14)),
                            const SizedBox(height: 2),
                            Text(
                              kIsWeb
                                  ? 'Web push is not configured for this build.'
                                  : 'Admin notices and broadcasts on this device.',
                              style: AppTypography.interCaption(color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: _announcements,
                        onChanged: kIsWeb ? null : _toggleAnnouncements,
                        activeThumbColor: AppColors.cyanDeep,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Card 2: Device Notification Alerts ──
                if (!kIsWeb) ...[
                  NeuCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (_notificationPermission && _deviceAlertsInApp)
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.inkSoft.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                (_notificationPermission && _deviceAlertsInApp)
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_off_rounded,
                                color: (_notificationPermission && _deviceAlertsInApp)
                                    ? AppColors.success
                                    : AppColors.inkSoft,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Device notification alerts', style: AppTypography.interButton(size: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    !_notificationPermission
                                        ? 'Permission required in device settings'
                                        : (_deviceAlertsInApp
                                            ? 'Active · Push notifications allowed'
                                            : 'Temporarily muted in app'),
                                    style: AppTypography.interCaption(
                                      color: !_notificationPermission
                                          ? AppColors.warning
                                          : AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: _notificationPermission && _deviceAlertsInApp,
                              onChanged: _toggleDeviceAlerts,
                              activeThumbColor: AppColors.cyanDeep,
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _notificationPermission
                                    ? AppColors.success.withValues(alpha: 0.12)
                                    : AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _notificationPermission ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                    size: 13,
                                    color: _notificationPermission ? AppColors.success : AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _notificationPermission ? 'Device permission: Allowed' : 'Device permission: Required',
                                    style: AppTypography.interCaption(
                                      color: _notificationPermission ? AppColors.success : AppColors.warning,
                                    ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: openAppSettings,
                              icon: const Icon(Icons.settings_outlined, size: 14),
                              label: const Text('Device settings', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Card 3: Alarm Alerts & Exact Alarms ──
                  NeuCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (_exactAlarm && _alarmAlertsInApp)
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                                    : AppColors.inkSoft.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                (_exactAlarm && _alarmAlertsInApp)
                                    ? Icons.alarm_on_rounded
                                    : Icons.alarm_off_rounded,
                                color: (_exactAlarm && _alarmAlertsInApp)
                                    ? const Color(0xFF8B5CF6)
                                    : AppColors.inkSoft,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Alarm alerts & ringtones', style: AppTypography.interButton(size: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    !_exactAlarm
                                        ? 'Exact alarm permission required'
                                        : (_alarmAlertsInApp
                                            ? 'Active · Ringing on schedule'
                                            : 'Temporarily muted in app'),
                                    style: AppTypography.interCaption(
                                      color: !_exactAlarm ? AppColors.warning : AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: _exactAlarm && _alarmAlertsInApp,
                              onChanged: _toggleAlarmAlerts,
                              activeThumbColor: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _exactAlarm
                                    ? AppColors.success.withValues(alpha: 0.12)
                                    : AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _exactAlarm ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                    size: 13,
                                    color: _exactAlarm ? AppColors.success : AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _exactAlarm
                                        ? (_fullScreenAlarm
                                            ? 'Exact & Full-screen: Allowed'
                                            : 'Exact alarms: Allowed')
                                        : 'Exact alarms: Needs setup',
                                    style: AppTypography.interCaption(
                                      color: _exactAlarm ? AppColors.success : AppColors.warning,
                                    ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _requestAlarmPermissions,
                              icon: const Icon(Icons.tune_rounded, size: 14),
                              label: Text(_exactAlarm ? 'Permission status' : 'Grant permission', style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Once enabled on your device, you can toggle notifications and alarm alerts directly inside CampusSetu anytime without revisiting device settings.',
                    style: AppTypography.interCaption(color: AppColors.inkSoft).copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}

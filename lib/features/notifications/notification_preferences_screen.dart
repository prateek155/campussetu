import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../alarm/alarm_service.dart';
import 'notification_preferences_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _loading = true;
  bool _announcements = false;
  bool _notificationPermission = false;
  bool _exactAlarm = false;
  bool _fullScreenAlarm = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final values = await Future.wait<bool>([
      NotificationPreferencesService.instance.announcementsEnabled(),
      _hasNotificationPermission(),
      AlarmService.hasExactAlarmAccess(),
      AlarmService.hasFullScreenAlarmAccess(),
    ]);
    if (!mounted) return;
    setState(() {
      _announcements = values[0];
      _notificationPermission = values[1];
      _exactAlarm = values[2];
      _fullScreenAlarm = values[3];
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

  Future<void> _requestAlarmPermissions() async {
    setState(() => _loading = true);
    try {
      final granted = await AlarmService.preparePermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enable notifications, exact alarms, and full-screen alerts in device settings.'),
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
        title: const Text('Notification settings'),
        backgroundColor: AppColors.bg,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: SwitchListTile.adaptive(
                    value: _announcements,
                    onChanged: kIsWeb ? null : _toggleAnnouncements,
                    title: const Text('Campus announcements'),
                    subtitle: Text(kIsWeb
                        ? 'Web push is not configured for this build.'
                        : 'Admin notices and broadcasts on this device.'),
                  ),
                ),
                const SizedBox(height: 12),
                if (!kIsWeb) Card(
                  child: ListTile(
                    leading: Icon(_notificationPermission
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined),
                    title: const Text('Device notification permission'),
                    subtitle: Text(_notificationPermission ? 'Allowed' : 'Not allowed'),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: openAppSettings,
                  ),
                ),
                const SizedBox(height: 12),
                if (!kIsWeb) Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.alarm_rounded),
                        title: const Text('Alarm alerts'),
                        subtitle: Text(
                          'Exact alarms: ' +
                              (_exactAlarm ? 'allowed' : 'not allowed') +
                              ' · Full-screen: ' +
                              (_fullScreenAlarm ? 'allowed' : 'not allowed'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _requestAlarmPermissions,
                            child: const Text('Set alarm permissions'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Android controls the device-wide notification permission. Alarm sounds and full-screen alerts also depend on Android alarm and lock-screen settings.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
    );
  }
}

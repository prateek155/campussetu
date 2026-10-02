import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesService {
  NotificationPreferencesService._();
  static final instance = NotificationPreferencesService._();

  static const _announcementsKey = 'notifications_campus_announcements_v1';
  static const _deviceAlertsKey = 'notifications_device_alerts_v1';
  static const _alarmAlertsKey = 'notifications_alarm_alerts_v1';
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return;
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _initialized = true;
  }

  Future<bool> announcementsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_announcementsKey) ?? false;
  }

  Future<bool> deviceAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deviceAlertsKey) ?? true;
  }

  Future<void> setDeviceAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceAlertsKey, enabled);
  }

  Future<bool> alarmAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alarmAlertsKey) ?? true;
  }

  Future<void> setAlarmAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmAlertsKey, enabled);
  }

  Future<bool> setAnnouncementsEnabled(bool enabled) async {
    if (kIsWeb) return false;
    final messaging = FirebaseMessaging.instance;
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }
      await messaging.subscribeToTopic('all_students');
    } else {
      await messaging.unsubscribeFromTopic('all_students');
    }
    await prefs.setBool(_announcementsKey, enabled);
    return true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!await announcementsEnabled()) return;
    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'CampusSetu',
      message.notification?.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'campus_announcements',
          'Campus announcements',
          channelDescription: 'Announcements sent by CampusSetu administrators',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

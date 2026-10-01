import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_model.dart';
import 'alarm_asset_storage.dart';

class AlarmService {
  AlarmService._();
  static const _bridge = MethodChannel('com.campussetu/alarm');
  static const _alarmKey = 'campussetu_local_alarms_v1';
  static const _nextIdKey = 'campussetu_local_alarms_next_id';
  static final StreamController<int> _ringRequests = StreamController<int>.broadcast();
  static Stream<int> get ringRequests => _ringRequests.stream;
  static ValueChanged<int>? onRingRequested;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    const events = EventChannel('com.campussetu/alarm_events');
    events.receiveBroadcastStream().listen((event) {
      if (event is Map && event['type'] == 'ring') {
        final id = int.tryParse(event['id']?.toString() ?? '');
        if (id != null) {
          _ringRequests.add(id);
          onRingRequested?.call(id);
        }
      }
    });
  }

  static Future<int> nextId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_nextIdKey) ?? 1;
    await prefs.setInt(_nextIdKey, id + 1);
    return id;
  }

  static Future<List<CampusAlarm>> load() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(_alarmKey);
    if (!kIsWeb) {
      try {
        raw = await _bridge.invokeMethod<String>('getAlarms') ?? raw;
        if (raw != null) await prefs.setString(_alarmKey, raw);
      } on PlatformException {
        // The local copy remains usable if Android cannot read its alarm store.
      }
    }
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => CampusAlarm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> save(List<CampusAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final json = CampusAlarm.encodeList(alarms);
    final scheduled = kIsWeb
        ? false
        : (await _bridge.invokeMethod<bool>('saveAlarms', json) ?? false);
    await prefs.setString(_alarmKey, json);
    return scheduled;
  }

  static Future<bool> preparePermissions() async {
    if (kIsWeb) return false;
    final notification = await Permission.notification.request();
    if (!notification.isGranted) return false;
    final exact = await _bridge.invokeMethod<bool>('requestExactAlarmAccess') ?? false;
    if (!exact) return false;
    return await _bridge.invokeMethod<bool>('requestFullScreenAlarmAccess') ?? false;
  }

  static Future<bool> hasExactAlarmAccess() async {
    if (kIsWeb) return false;
    return await _bridge.invokeMethod<bool>('hasExactAlarmAccess') ?? false;
  }

  static Future<bool> hasFullScreenAlarmAccess() async {
    if (kIsWeb) return false;
    return await _bridge.invokeMethod<bool>('hasFullScreenAlarmAccess') ?? false;
  }

  static Future<Map<String, String>?> pickSound({String currentUri = ''}) async {
    if (kIsWeb) return null;
    final result = await _bridge.invokeMapMethod<String, String>('pickAlarmSound', currentUri);
    return result;
  }

  static Future<Map<String, String>?> pickCustomSound({required int alarmId}) async {
    if (kIsWeb) return null;
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false, withReadStream: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final path = await persistAlarmAsset(
      alarmId: alarmId,
      kind: 'sound',
      originalName: file.name,
      sourcePath: file.path,
      bytes: file.bytes,
      dataStream: file.readStream,
    );
    if (path == null) return null;
    final name = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return {'path': path, 'name': name.isEmpty ? 'Custom sound' : name};
  }

  static Future<String?> pickWallpaper({required int alarmId}) async {
    if (kIsWeb) return null;
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withReadStream: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    return persistAlarmAsset(
      alarmId: alarmId,
      kind: 'wallpaper',
      originalName: file.name,
      sourcePath: file.path,
      bytes: file.bytes,
      dataStream: file.readStream,
    );
  }

  static Future<void> deleteManagedAsset(String? path) => deleteAlarmAsset(path);

  static Future<void> stop(int id) async {
    if (!kIsWeb) await _bridge.invokeMethod<void>('stopAlarm', id);
  }

  static Future<void> snooze(int id, int minutes) async {
    if (!kIsWeb) await _bridge.invokeMethod<void>('snoozeAlarm', {'id': id, 'minutes': minutes});
  }

  static Stream<List<double>> motionEvents() {
    if (kIsWeb) return const Stream<List<double>>.empty();
    return const EventChannel('com.campussetu/alarm_motion')
        .receiveBroadcastStream()
        .map((event) => (event as List<dynamic>).map((v) => (v as num).toDouble()).toList());
  }
}

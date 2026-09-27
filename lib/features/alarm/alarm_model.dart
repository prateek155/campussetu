import 'dart:convert';

enum AlarmMission { math, memory, typing, shake }

class CampusAlarm {
  const CampusAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = 'Alarm',
    this.days = const [],
    this.enabled = true,
    this.snoozeMinutes = 5,
    this.mission = AlarmMission.math,
    this.soundUri = '',
    this.soundName = 'Default alarm',
    this.customSoundPath = '',
    this.wallpaperPath = '',
    this.volume = 1.0,
    this.vibration = true,
  });

  final int id;
  final int hour;
  final int minute;
  final String label;
  /// Dart weekday values: Monday = 1 ... Sunday = 7. Empty means one-time.
  final List<int> days;
  final bool enabled;
  final int snoozeMinutes;
  final AlarmMission mission;
  final String soundUri;
  final String soundName;
  final String customSoundPath;
  final String wallpaperPath;
  final double volume;
  final bool vibration;

  CampusAlarm copyWith({
    int? hour,
    int? minute,
    String? label,
    List<int>? days,
    bool? enabled,
    int? snoozeMinutes,
    AlarmMission? mission,
    String? soundUri,
    String? soundName,
    String? customSoundPath,
    String? wallpaperPath,
    double? volume,
    bool? vibration,
  }) => CampusAlarm(
    id: id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    label: label ?? this.label,
    days: days ?? this.days,
    enabled: enabled ?? this.enabled,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    mission: mission ?? this.mission,
    soundUri: soundUri ?? this.soundUri,
    soundName: soundName ?? this.soundName,
    customSoundPath: customSoundPath ?? this.customSoundPath,
    wallpaperPath: wallpaperPath ?? this.wallpaperPath,
    volume: volume ?? this.volume,
    vibration: vibration ?? this.vibration,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'label': label,
    'days': days,
    'enabled': enabled,
    'snoozeMinutes': snoozeMinutes,
    'mission': mission.name,
    'soundUri': soundUri,
    'soundName': soundName,
    'customSoundPath': customSoundPath,
    'wallpaperPath': wallpaperPath,
    'volume': volume,
    'vibration': vibration,
  };

  factory CampusAlarm.fromJson(Map<String, dynamic> json) => CampusAlarm(
    id: (json['id'] as num).toInt(),
    hour: (json['hour'] as num).toInt(),
    minute: (json['minute'] as num).toInt(),
    label: json['label']?.toString() ?? 'Alarm',
    days: (json['days'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()).toList(),
    enabled: json['enabled'] as bool? ?? true,
    snoozeMinutes: (json['snoozeMinutes'] as num?)?.toInt() ?? 5,
    mission: AlarmMission.values.firstWhere(
      (m) => m.name == json['mission'],
      orElse: () => AlarmMission.math,
    ),
    soundUri: json['soundUri']?.toString() ?? '',
    soundName: json['soundName']?.toString() ?? 'Default alarm',
    customSoundPath: json['customSoundPath']?.toString() ?? '',
    wallpaperPath: json['wallpaperPath']?.toString() ?? '',
    volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    vibration: json['vibration'] as bool? ?? true,
  );

  static String encodeList(List<CampusAlarm> alarms) => jsonEncode(alarms.map((a) => a.toJson()).toList());
}

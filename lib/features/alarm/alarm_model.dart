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
    this.difficulty = 1, // 0 = Easy, 1 = Medium, 2 = Hard
    this.gentleStart = false,
    this.snoozeCount = 0,
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
  final int difficulty; // 0 = Easy, 1 = Medium, 2 = Hard
  final bool gentleStart;
  final int snoozeCount;

  bool get isOnce => days.isEmpty;
  bool get isWeekdays => days.length == 5 && [1, 2, 3, 4, 5].every(days.contains);
  bool get isWeekends => days.length == 2 && [6, 7].every(days.contains);
  bool get isEveryDay => days.length == 7;

  String get repeatLabel {
    if (isOnce) return 'One time';
    if (isEveryDay) return 'Every day';
    if (isWeekdays) return 'Weekdays';
    if (isWeekends) return 'Weekends';
    const dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final sorted = [...days]..sort();
    return sorted.map((d) => dayNames[d - 1]).join(' · ');
  }

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
    int? difficulty,
    bool? gentleStart,
    int? snoozeCount,
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
    difficulty: difficulty ?? this.difficulty,
    gentleStart: gentleStart ?? this.gentleStart,
    snoozeCount: snoozeCount ?? this.snoozeCount,
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
    'difficulty': difficulty,
    'gentleStart': gentleStart,
    'snoozeCount': snoozeCount,
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
    difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
    gentleStart: json['gentleStart'] as bool? ?? false,
    snoozeCount: (json['snoozeCount'] as num?)?.toInt() ?? 0,
  );

  static String encodeList(List<CampusAlarm> alarms) => jsonEncode(alarms.map((a) => a.toJson()).toList());
}

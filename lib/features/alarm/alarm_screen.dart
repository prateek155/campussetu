import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_router.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'alarm_model.dart';
import 'alarm_service.dart';
import 'alarm_wallpaper_image.dart';

// ── Screen 1: Main Alarms List Screen (Matches Design Image 4) ────────────────
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});
  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  List<CampusAlarm> _alarms = [];
  bool _loading = true;
  bool _exactAccess = false;

  @override
  void initState() {
    super.initState();
    AlarmService.initialize();
    _load();
  }

  Future<void> _load() async {
    final alarms = await AlarmService.load();
    final exact = !kIsWeb && await AlarmService.hasExactAlarmAccess();
    if (!mounted) return;
    setState(() {
      _alarms = alarms..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      _exactAccess = exact;
      _loading = false;
    });
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.cyanDeep,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool> _persist(List<CampusAlarm> alarms) async {
    try {
      final scheduled = await AlarmService.save(alarms);
      if (!scheduled && alarms.any((alarm) => alarm.enabled) && mounted) {
        _message('Settings saved, but active alarms are paused until Android alarm access is restored.', error: true);
      }
      return scheduled || alarms.every((alarm) => !alarm.enabled);
    } catch (_) {
      if (mounted) _message('Could not save the alarm. Check Android alarm access and try again.', error: true);
      return false;
    }
  }

  Future<void> _edit([CampusAlarm? current]) async {
    if (kIsWeb) {
      _message('Alarms need the CampusSetu Android app to ring reliably.', error: true);
      return;
    }
    final id = current?.id ?? await AlarmService.nextId();
    if (!mounted) return;
    final draft = await showModalBottomSheet<CampusAlarm>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlarmEditor(alarm: current, id: id),
    );
    if (draft == null) return;
    if (!mounted) {
      await _discardDraftAssets(draft, current);
      return;
    }
    if (draft.enabled) {
      final granted = await _requestPermissions();
      if (!granted) {
        _message('Allow notifications and exact-alarm access in Android settings to enable this alarm.', error: true);
        await _discardDraftAssets(draft, current);
        await _load();
        return;
      }
    }
    final next = [..._alarms.where((a) => a.id != draft.id), draft]
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    if (!await _persist(next)) {
      await _load();
      return;
    }
    final kept = {draft.customSoundPath, draft.wallpaperPath};
    for (final path in [current?.customSoundPath, current?.wallpaperPath]) {
      if (path != null && path.isNotEmpty && !kept.contains(path)) await AlarmService.deleteManagedAsset(path);
    }
    if (!mounted) return;
    setState(() {
      _alarms = next;
      _exactAccess = true;
    });
    _message(current == null ? 'Alarm scheduled' : 'Alarm updated');
  }

  Future<void> _discardDraftAssets(CampusAlarm draft, CampusAlarm? keep) async {
    final retained = {keep?.customSoundPath, keep?.wallpaperPath};
    for (final path in [draft.customSoundPath, draft.wallpaperPath]) {
      if (path.isNotEmpty && !retained.contains(path)) await AlarmService.deleteManagedAsset(path);
    }
  }

  Future<void> _toggle(CampusAlarm alarm, bool enabled) async {
    if (enabled) {
      if (!await _requestPermissions()) {
        _message('Allow notifications and alarm access in Android settings to enable alarms.', error: true);
        await _load();
        return;
      }
    }
    final next = _alarms.map((a) => a.id == alarm.id ? a.copyWith(enabled: enabled) : a).toList();
    if (!await _persist(next)) {
      await _load();
      return;
    }
    if (mounted) setState(() {
      _alarms = next;
      _exactAccess = enabled || _exactAccess;
    });
  }

  Future<bool> _requestPermissions() async {
    final explained = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow alarms to ring on time'),
        content: const Text('Android needs notification and exact-alarm access so alarms you create can ring while CampusSetu is closed or your phone is offline. Alarm times and settings stay on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (explained != true) return false;
    return AlarmService.preparePermissions();
  }

  Future<void> _delete(CampusAlarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete alarm?'),
        content: Text('Remove "${alarm.label}" and its scheduled alerts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final next = _alarms.where((a) => a.id != alarm.id).toList();
    if (!await _persist(next)) {
      await _load();
      return;
    }
    await AlarmService.deleteManagedAsset(alarm.customSoundPath);
    await AlarmService.deleteManagedAsset(alarm.wallpaperPath);
    if (mounted) setState(() => _alarms = next);
  }

  String _nextAlarmSubtitle() {
    final active = _alarms.where((a) => a.enabled).toList();
    if (active.isEmpty) return 'No active alarms scheduled';
    final now = DateTime.now();
    int minDiffMinutes = 9999999;
    for (final a in active) {
      var next = DateTime(now.year, now.month, now.day, a.hour, a.minute);
      if (next.isBefore(now)) next = next.add(const Duration(days: 1));
      if (a.days.isNotEmpty) {
        while (!a.days.contains(next.weekday)) {
          next = next.add(const Duration(days: 1));
        }
      }
      final diff = next.difference(now).inMinutes;
      if (diff < minDiffMinutes) minDiffMinutes = diff;
    }
    if (minDiffMinutes >= 9999999) return 'No active alarms';
    final hours = minDiffMinutes ~/ 60;
    final mins = minDiffMinutes % 60;
    if (hours > 0) return 'Next alarm rings in ${hours}h ${mins}m';
    return 'Next alarm rings in ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.cyanDeep))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                children: [
                  // ── Top Header with Title, Subtitle and '+' Button ──────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E232A)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.home);
                          }
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alarms',
                              style: AppTypography.soraHeading1(color: const Color(0xFF1E232A)).copyWith(fontSize: 32, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _nextAlarmSubtitle(),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      // '+' Circle Button (Neu / Soft card style)
                      GestureDetector(
                        onTap: isWeb ? null : () => _edit(),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add, color: Color(0xFF1E232A), size: 26),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // ── List of Alarms Cards ──────────────────────────────────
                  if (_alarms.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.cyanDeep.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.alarm_add_rounded, size: 34, color: AppColors.cyanDeep),
                          ),
                          const SizedBox(height: 16),
                          Text('No alarms set yet', style: AppTypography.soraHeading3(color: const Color(0xFF1E232A))),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first wake-up mission alarm with wallpapers and sound.',
                            textAlign: TextAlign.center,
                            style: AppTypography.interBodySmall(color: const Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: () => _edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('Create an alarm'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.cyanDeep,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._alarms.map((alarm) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _AlarmCardTile(
                            alarm: alarm,
                            onChanged: (enabled) => _toggle(alarm, enabled),
                            onEdit: () => _edit(alarm),
                            onDelete: () => _delete(alarm),
                          ),
                        )),

                  const SizedBox(height: 24),
                  // ── Footer text ──────────────────────────────────────────
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Alarms stay on this device. They ring without internet or a CampusSetu login.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Alarm Card (Matches Design Image 4) ───────────────────────────────────────
class _AlarmCardTile extends StatelessWidget {
  const _AlarmCardTile({
    required this.alarm,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final CampusAlarm alarm;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = getWallpaperColors(alarm.wallpaperPath);
    final hour12 = alarm.hour == 0 ? 12 : (alarm.hour > 12 ? alarm.hour - 12 : alarm.hour);
    final minuteStr = alarm.minute.toString().padLeft(2, '0');
    final period = alarm.hour >= 12 ? 'PM' : 'AM';

    final missionIcon = switch (alarm.mission) {
      AlarmMission.math => '🧮 Math',
      AlarmMission.memory => '🧠 Memory',
      AlarmMission.shake => '📱 Shake',
      AlarmMission.typing => '⌨️ Typing',
    };

    return GestureDetector(
      onTap: onEdit,
      onLongPress: onDelete,
      child: AnimatedOpacity(
        opacity: alarm.enabled ? 1.0 : 0.65,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 18, 18, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(alarm.enabled ? 0.35 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Label and Switch
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      alarm.label.trim().isEmpty ? 'Wake up' : alarm.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: alarm.enabled,
                      onChanged: onChanged,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF00C7E5),
                      inactiveThumbColor: Colors.white70,
                      inactiveTrackColor: Colors.black26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Middle: Large Time display
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$hour12:$minuteStr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    period,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bottom pills: Repeat & Mission
              Row(
                children: [
                  _CardPill(text: alarm.repeatLabel),
                  const SizedBox(width: 8),
                  _CardPill(text: missionIcon),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardPill extends StatelessWidget {
  const _CardPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

// ── Screen 2: Alarm Editor Sheet (Matches Design Images 2 & 3) ────────────────
class _AlarmEditor extends StatefulWidget {
  const _AlarmEditor({required this.id, this.alarm});
  final int id;
  final CampusAlarm? alarm;

  @override
  State<_AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<_AlarmEditor> {
  late final TextEditingController _label;
  late TimeOfDay _time;
  late Set<int> _days;
  late AlarmMission _mission;
  late int _difficulty; // 0=Easy, 1=Medium, 2=Hard
  late String _soundUri;
  late String _soundName;
  late String _customSoundPath;
  late String _wallpaperPath;
  late double _volume;
  late bool _gentleStart;
  late bool _vibration;
  late bool _enabled;
  bool _saved = false;
  final List<String> _createdAssets = [];

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _label = TextEditingController(text: a?.label ?? 'Wake up');
    _time = TimeOfDay(hour: a?.hour ?? 7, minute: a?.minute ?? 0);
    _days = {...?a?.days};
    _mission = a?.mission ?? AlarmMission.math;
    _difficulty = a?.difficulty ?? 1; // Default Medium
    _soundUri = a?.soundUri ?? '';
    _soundName = a?.soundName ?? 'Default alarm';
    _customSoundPath = a?.customSoundPath ?? '';
    _wallpaperPath = a?.wallpaperPath ?? '__builtin__:sunset'; // Default sunset
    _volume = a?.volume ?? 1.0;
    _gentleStart = a?.gentleStart ?? true;
    _vibration = a?.vibration ?? true;
    _enabled = a?.enabled ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    if (!_saved) {
      for (final path in _createdAssets) {
        unawaited(AlarmService.deleteManagedAsset(path));
      }
    }
    super.dispose();
  }

  String _formatRingsIn() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    if (_days.isNotEmpty) {
      while (!_days.contains(next.weekday)) {
        next = next.add(const Duration(days: 1));
      }
    }
    final diff = next.difference(now).inMinutes;
    final hours = diff ~/ 60;
    final mins = diff % 60;
    if (hours > 0) return 'Rings in ${hours}h ${mins}m';
    return 'Rings in ${mins}m';
  }

  String _repeatDescription() {
    final timeStr = DateFormat('h:mm a').format(DateTime(2026, 1, 1, _time.hour, _time.minute));
    if (_days.isEmpty) return 'Rings once at the next $timeStr';
    if (_days.length == 7) return 'Rings every day at $timeStr';
    if (_days.length == 5 && [1, 2, 3, 4, 5].every(_days.contains)) return 'Rings on weekdays (Mon-Fri) at $timeStr';
    if (_days.length == 2 && [6, 7].every(_days.contains)) return 'Rings on weekends (Sat-Sun) at $timeStr';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [..._days]..sort();
    return 'Rings on ${sorted.map((d) => names[d - 1]).join(', ')}';
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF00A3C4)),
        ),
        child: child!,
      ),
    );
    if (time != null && mounted) setState(() => _time = time);
  }

  Future<void> _openWallpaperPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WallpaperPickerSheet(
        alarmId: widget.id,
        currentPath: _wallpaperPath,
        onPicked: (path, {bool isBuiltIn = false}) {
          if (!mounted) return;
          final prev = _wallpaperPath;
          setState(() {
            _wallpaperPath = path;
            if (!isBuiltIn) _createdAssets.add(path);
          });
          if (!isBuiltIn && prev.isNotEmpty && !_createdAssets.contains(prev)) {
            unawaited(AlarmService.deleteManagedAsset(prev));
          }
        },
      ),
    );
  }

  Future<void> _chooseSound() async {
    final source = await showModalBottomSheet<_AlarmSoundSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF00A3C4)),
              title: const Text('Phone alarm sounds'),
              subtitle: const Text('Choose a tone installed on this device'),
              onTap: () => Navigator.pop(context, _AlarmSoundSource.system),
            ),
            ListTile(
              leading: const Icon(Icons.audio_file_outlined, color: Color(0xFF00A3C4)),
              title: const Text('Choose my audio file'),
              subtitle: const Text('Use an audio file stored on this device'),
              onTap: () => Navigator.pop(context, _AlarmSoundSource.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == _AlarmSoundSource.system) {
      final selected = await AlarmService.pickSound(currentUri: _soundUri);
      if (selected != null && mounted) {
        setState(() {
          _soundUri = selected['uri'] ?? '';
          _soundName = selected['name'] ?? 'Alarm sound';
          _customSoundPath = '';
        });
      }
      return;
    }
    try {
      final selected = await AlarmService.pickCustomSound(alarmId: widget.id);
      if (selected != null && mounted) {
        setState(() {
          _customSoundPath = selected['path'] ?? '';
          _soundUri = '';
          _soundName = selected['name'] ?? 'Custom sound';
          if (_customSoundPath.isNotEmpty) _createdAssets.add(_customSoundPath);
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that audio file.')));
    }
  }

  void _tryMissionPreview() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _MissionDialog(
        mission: _mission,
        difficulty: _difficulty,
        isPreview: true,
        onSuccess: () => Navigator.pop(ctx),
      ),
    );
  }

  void _previewRinging() {
    final previewAlarm = CampusAlarm(
      id: widget.id,
      hour: _time.hour,
      minute: _time.minute,
      label: _label.text.trim().isEmpty ? 'Wake up' : _label.text.trim(),
      days: _days.toList(),
      mission: _mission,
      difficulty: _difficulty,
      wallpaperPath: _wallpaperPath,
      soundName: _soundName,
      soundUri: _soundUri,
      customSoundPath: _customSoundPath,
      volume: _volume,
      vibration: _vibration,
      gentleStart: _gentleStart,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmRingingScreen(
          alarmId: widget.id,
          overrideAlarm: previewAlarm,
          isPreview: true,
        ),
      ),
    );
  }

  void _save() {
    _saved = true;
    final draft = CampusAlarm(
      id: widget.id,
      hour: _time.hour,
      minute: _time.minute,
      label: _label.text.trim().isEmpty ? 'Wake up' : _label.text.trim(),
      days: _days.toList()..sort(),
      enabled: _enabled,
      snoozeMinutes: 5, // Strictly 5 min
      mission: _mission,
      difficulty: _difficulty,
      soundUri: _soundUri,
      soundName: _soundName,
      customSoundPath: _customSoundPath,
      wallpaperPath: _wallpaperPath,
      volume: _volume,
      vibration: _vibration,
      gentleStart: _gentleStart,
    );
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final hour12 = _time.hour == 0 ? 12 : (_time.hour > 12 ? _time.hour - 12 : _time.hour);
    final minuteStr = _time.minute.toString().padLeft(2, '0');
    final period = _time.hour >= 12 ? 'PM' : 'AM';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── TOP BANNER: Wallpaper, Time & Compact Badges ──
          Stack(
            children: [
              // Wallpaper background
              SizedBox(
                height: 205,
                width: double.infinity,
                child: AlarmWallpaperImage(path: _wallpaperPath),
              ),
              // Dark gradient overlay
              Container(
                height: 205,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x55000000), Color(0x99000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Banner Content
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Large Time Display
                      GestureDetector(
                        onTap: _chooseTime,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$hour12:$minuteStr',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              period,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Compact 'Wake up' label badge (styled exactly like Rings in badge)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded, color: Colors.white70, size: 13),
                            const SizedBox(width: 6),
                            IntrinsicWidth(
                              child: TextField(
                                controller: _label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  hintText: 'Wake up',
                                  hintStyle: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Row with 'Rings in Xh Ym' badge & 'Change wallpaper' side-by-side
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: Text(
                              _formatRingsIn(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openWallpaperPicker,
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_outlined, color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Change wallpaper',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── BODY: Scrollable Configuration Sections ──────────────────────────
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                children: [
                  // ── SECTION 1: REPEAT ───────────────────────────────────────
                  const Text('Repeat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E232A))),
                  const SizedBox(height: 12),

                  // Quick selection chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickChip(
                        label: 'Once',
                        selected: _days.isEmpty,
                        onTap: () => setState(() => _days.clear()),
                      ),
                      _QuickChip(
                        label: 'Weekdays',
                        selected: _days.length == 5 && [1, 2, 3, 4, 5].every(_days.contains),
                        onTap: () => setState(() => _days = {1, 2, 3, 4, 5}),
                      ),
                      _QuickChip(
                        label: 'Weekends',
                        selected: _days.length == 2 && [6, 7].every(_days.contains),
                        onTap: () => setState(() => _days = {6, 7}),
                      ),
                      _QuickChip(
                        label: 'Every day',
                        selected: _days.length == 7,
                        onTap: () => setState(() => _days = {1, 2, 3, 4, 5, 6, 7}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Days circle row: Mo Tu We Th Fr Sa Su
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final dayNum = index + 1;
                      const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      const sub = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
                      final isSelected = _days.contains(dayNum);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _days.remove(dayNum);
                            } else {
                              _days.add(dayNum);
                            }
                          });
                        },
                        child: Container(
                          width: 42,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF00A3C4) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00A3C4) : const Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                letters[index],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                sub[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white70 : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(_repeatDescription(), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  const SizedBox(height: 24),

                  // ── SECTION 2: WAKE-UP MISSION ──────────────────────────────
                  const Text('Wake-up mission', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E232A))),
                  const SizedBox(height: 12),

                  // Horizontal Cards
                  Row(
                    children: [
                      _MissionOptionCard(
                        icon: '🧮',
                        title: 'Math',
                        selected: _mission == AlarmMission.math,
                        onTap: () => setState(() => _mission = AlarmMission.math),
                      ),
                      const SizedBox(width: 8),
                      _MissionOptionCard(
                        icon: '🧠',
                        title: 'Memory',
                        selected: _mission == AlarmMission.memory,
                        onTap: () => setState(() => _mission = AlarmMission.memory),
                      ),
                      const SizedBox(width: 8),
                      _MissionOptionCard(
                        icon: '📱',
                        title: 'Shake',
                        selected: _mission == AlarmMission.shake,
                        onTap: () => setState(() => _mission = AlarmMission.shake),
                      ),
                      const SizedBox(width: 8),
                      _MissionOptionCard(
                        icon: '⌨️',
                        title: 'Typing',
                        selected: _mission == AlarmMission.typing,
                        onTap: () => setState(() => _mission = AlarmMission.typing),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Subtitle enforcing 2 tasks
                  const Text('Solve 2 quick tasks to stop the alarm.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  const SizedBox(height: 14),

                  // Difficulty level selector (Easy, Medium, Hard)
                  Row(
                    children: [
                      _DifficultyChip(
                        label: 'Easy',
                        selected: _difficulty == 0,
                        onTap: () => setState(() => _difficulty = 0),
                      ),
                      const SizedBox(width: 8),
                      _DifficultyChip(
                        label: 'Medium',
                        selected: _difficulty == 1,
                        onTap: () => setState(() => _difficulty = 1),
                      ),
                      const SizedBox(width: 8),
                      _DifficultyChip(
                        label: 'Hard',
                        selected: _difficulty == 2,
                        onTap: () => setState(() => _difficulty = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 'Try this mission' dashed outline button
                  GestureDetector(
                    onTap: _tryMissionPreview,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5, style: BorderStyle.solid),
                      ),
                      child: const Center(
                        child: Text(
                          'Try this mission',
                          style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── SECTION 3: SOUND & SNOOZE ───────────────────────────────
                  const Text('Sound and snooze', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E232A))),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Row 1: Alarm sound
                        ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: const Color(0xFFE0F7FA), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.music_note_rounded, color: Color(0xFF00A3C4), size: 20),
                          ),
                          title: const Text('Alarm sound', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: Text(_soundName, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                          onTap: _chooseSound,
                        ),
                        const Divider(height: 1, indent: 64, color: Color(0xFFF3F4F6)),

                        // Row 2: Snooze length (Fixed 5 min, strictly 1 time only)
                        ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: const Color(0xFFE0F7FA), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.snooze_rounded, color: Color(0xFF00A3C4), size: 20),
                          ),
                          title: const Text('Snooze length', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Only 1 snooze allowed', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                            child: const Text('5 min', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E232A))),
                          ),
                        ),
                        const Divider(height: 1, indent: 64, color: Color(0xFFF3F4F6)),

                        // Row 3: Volume Slider
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Volume', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Text('${(_volume * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                ],
                              ),
                              Slider(
                                value: _volume,
                                min: 0.2,
                                max: 1.0,
                                activeColor: const Color(0xFF00A3C4),
                                inactiveColor: const Color(0xFFE5E7EB),
                                onChanged: (v) => setState(() => _volume = v),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, indent: 16, color: Color(0xFFF3F4F6)),

                        // Row 4: Gentle start
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          secondary: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: const Color(0xFFE0F7FA), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.trending_up_rounded, color: Color(0xFF00A3C4), size: 20),
                          ),
                          title: const Text('Gentle start', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Volume rises over 30 seconds', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          value: _gentleStart,
                          activeColor: const Color(0xFF00A3C4),
                          onChanged: (v) => setState(() => _gentleStart = v),
                        ),
                        const Divider(height: 1, indent: 64, color: Color(0xFFF3F4F6)),

                        // Row 5: Vibrate while ringing
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          secondary: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: const Color(0xFFE0F7FA), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.vibration_rounded, color: Color(0xFF00A3C4), size: 20),
                          ),
                          title: const Text('Vibrate while ringing', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          value: _vibration,
                          activeColor: const Color(0xFF00A3C4),
                          onChanged: (v) => setState(() => _vibration = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM ACTIONS: Preview & Save (Matches Design Image 2 & 3) ────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                // 'Preview' button
                GestureDetector(
                  onTap: _previewRinging,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Color(0xFF1E232A), size: 18),
                        SizedBox(width: 4),
                        Text('Preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E232A))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 'Save alarm' button (Cyan full button)
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3C4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Save alarm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _AlarmSoundSource { system, file }

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE0F7FA) : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? const Color(0xFF00A3C4) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF00A3C4) : const Color(0xFF374151),
            ),
          ),
        ),
      );
}

class _MissionOptionCard extends StatelessWidget {
  const _MissionOptionCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF5F3FF) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? const Color(0xFF7C3AED) : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF7C3AED) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Screen 3: Choose Wallpaper Sheet (Matches Design Image 1) ─────────────────
class _WallpaperPickerSheet extends StatefulWidget {
  const _WallpaperPickerSheet({
    required this.alarmId,
    required this.currentPath,
    required this.onPicked,
  });

  final int alarmId;
  final String currentPath;
  final void Function(String path, {bool isBuiltIn}) onPicked;

  @override
  State<_WallpaperPickerSheet> createState() => _WallpaperPickerSheetState();
}

class _WallpaperPickerSheetState extends State<_WallpaperPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late String _selectedPath;
  bool _selectedIsBuiltIn = true;

  List<dynamic> _remoteImages = [];
  List<dynamic> _remoteAnimated = [];
  List<dynamic> _remoteVideos = [];
  @override
  void initState() {
    super.initState();
    _selectedPath = widget.currentPath;
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadRemoteWallpapers();
  }

  Future<void> _loadRemoteWallpapers() async {
    // 1. Instant local offline cache (0ms load time)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_remote_alarm_wallpapers');
      if (cachedJson != null && mounted) {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        setState(() {
          _remoteImages = (data['image'] as List<dynamic>?) ?? [];
          _remoteAnimated = (data['animated'] as List<dynamic>?) ?? [];
          _remoteVideos = (data['video'] as List<dynamic>?) ?? [];
        });
      }
    } catch (_) {}

    // 2. Fetch latest from Redis-backed API (<1ms from Redis memory)
    try {
      final data = await ApiService().getAlarmWallpapers();
      if (!mounted) return;
      setState(() {
        _remoteImages = (data['image'] as List<dynamic>?) ?? [];
        _remoteAnimated = (data['animated'] as List<dynamic>?) ?? [];
        _remoteVideos = (data['video'] as List<dynamic>?) ?? [];
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_remote_alarm_wallpapers', jsonEncode(data));
    } catch (_) {
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final path = await AlarmService.pickWallpaper(alarmId: widget.alarmId);
      if (path != null && mounted) {
        setState(() {
          _selectedPath = path;
          _selectedIsBuiltIn = false;
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open image.')));
    }
  }

  void _applySelection() {
    widget.onPicked(_selectedPath, isBuiltIn: _selectedIsBuiltIn);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Header: "Choose wallpaper" with close (X)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 14, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose wallpaper',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E232A)),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Color(0xFF374151), size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Categories Tabs / Pills (Matches Image 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.transparent,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                _TabPill(text: '🎨 Gradients', index: 0, controller: _tabCtrl),
                _TabPill(text: '🖼️ Photos', index: 1, controller: _tabCtrl),
                _TabPill(text: '✨ Animated', index: 2, controller: _tabCtrl),
                _TabPill(text: '🎬 Video', index: 3, controller: _tabCtrl),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Gradients tab (12 built-in gradients)
                _GradientsGridView(
                  selectedPath: _selectedPath,
                  onSelect: (path) => setState(() {
                    _selectedPath = path;
                    _selectedIsBuiltIn = true;
                  }),
                ),

                // Photos tab (Local asset + Remote API + Gallery)
                _PhotosGridView(
                  selectedPath: _selectedPath,
                  remoteItems: _remoteImages,
                  onSelect: (path) => setState(() {
                    _selectedPath = path;
                    _selectedIsBuiltIn = true;
                  }),
                  onGalleryTap: _pickFromGallery,
                ),

                // Animated tab (Rive .riv)
                _AnimatedGridView(
                  selectedPath: _selectedPath,
                  remoteItems: _remoteAnimated,
                  onSelect: (path) => setState(() {
                    _selectedPath = path;
                    _selectedIsBuiltIn = true;
                  }),
                ),

                // Video tab (MP4)
                _VideoGridView(
                  selectedPath: _selectedPath,
                  remoteItems: _remoteVideos,
                  onSelect: (path) => setState(() {
                    _selectedPath = path;
                    _selectedIsBuiltIn = true;
                  }),
                ),
              ],
            ),
          ),

          // Bottom button: "Use this wallpaper" (Cyan pill)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.12))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _applySelection,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00A3C4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text('Use this wallpaper', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.text, required this.index, required this.controller});
  final String text;
  final int index;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final isSelected = controller.index == index;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00A3C4) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        );
      },
    );
  }
}

class _GradientsGridView extends StatelessWidget {
  const _GradientsGridView({required this.selectedPath, required this.onSelect});
  final String selectedPath;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final list = builtInGradients.entries.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final path = '__builtin__:${item.key}';
        final isSelected = selectedPath == path;
        final name = item.key[0].toUpperCase() + item.key.substring(1);
        return GestureDetector(
          onTap: () => onSelect(path),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: item.value,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00A3C4) : Colors.transparent,
                    width: isSelected ? 3 : 0,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, shadows: [Shadow(blurRadius: 4)]),
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A3C4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotosGridView extends StatelessWidget {
  const _PhotosGridView({
    required this.selectedPath,
    required this.remoteItems,
    required this.onSelect,
    required this.onGalleryTap,
  });

  final String selectedPath;
  final List<dynamic> remoteItems;
  final ValueChanged<String> onSelect;
  final VoidCallback onGalleryTap;

  @override
  Widget build(BuildContext context) {
    // Items: 0 is Gallery tile, 1 is local sample galaxy, rest are remote
    final total = 2 + remoteItems.length;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: total,
      itemBuilder: (_, i) {
        if (i == 0) {
          // My Gallery Tile
          return GestureDetector(
            onTap: onGalleryTap,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 34, color: Color(0xFF00A3C4)),
                  SizedBox(height: 8),
                  Text('My Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                ],
              ),
            ),
          );
        }
        if (i == 1) {
          // Bundled Galaxy Sample
          const path = '__asset_img__:assets/alarm_wallpapers/sample_galaxy.jpg';
          final isSelected = selectedPath == path;
          return _WallpaperTile(
            label: 'Galaxy',
            path: path,
            isSelected: isSelected,
            onTap: () => onSelect(path),
          );
        }
        // Remote images
        final remote = Map<String, dynamic>.from(remoteItems[i - 2] as Map);
        final url = remote['url']?.toString() ?? '';
        final label = remote['label']?.toString() ?? 'Wallpaper';
        final path = '__remote_img__:$url';
        final isSelected = selectedPath == path || selectedPath == url;
        return _WallpaperTile(
          label: label,
          path: path,
          isSelected: isSelected,
          onTap: () => onSelect(path),
        );
      },
    );
  }
}

class _AnimatedGridView extends StatelessWidget {
  const _AnimatedGridView({
    required this.selectedPath,
    required this.remoteItems,
    required this.onSelect,
  });

  final String selectedPath;
  final List<dynamic> remoteItems;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // 1 local sample + remote items
    final total = 1 + remoteItems.length;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: total,
      itemBuilder: (_, i) {
        if (i == 0) {
          const path = '__asset_rive__:assets/alarm_wallpapers/sample_animated.riv';
          final isSelected = selectedPath == path;
          return _WallpaperTile(
            label: 'Vehicles',
            path: path,
            isSelected: isSelected,
            isAnimated: true,
            onTap: () => onSelect(path),
          );
        }
        final remote = Map<String, dynamic>.from(remoteItems[i - 1] as Map);
        final url = remote['url']?.toString() ?? '';
        final label = remote['label']?.toString() ?? 'Animated';
        final path = '__remote_rive__:$url';
        final isSelected = selectedPath == path || selectedPath == url;
        return _WallpaperTile(
          label: label,
          path: path,
          isSelected: isSelected,
          isAnimated: true,
          onTap: () => onSelect(path),
        );
      },
    );
  }
}

class _VideoGridView extends StatelessWidget {
  const _VideoGridView({
    required this.selectedPath,
    required this.remoteItems,
    required this.onSelect,
  });

  final String selectedPath;
  final List<dynamic> remoteItems;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final total = 1 + remoteItems.length;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: total,
      itemBuilder: (_, i) {
        if (i == 0) {
          const path = '__asset_video__:assets/alarm_wallpapers/sample_video.mp4';
          final isSelected = selectedPath == path;
          return _WallpaperTile(
            label: 'Video Loop',
            path: path,
            isSelected: isSelected,
            isVideo: true,
            onTap: () => onSelect(path),
          );
        }
        final remote = Map<String, dynamic>.from(remoteItems[i - 1] as Map);
        final url = remote['url']?.toString() ?? '';
        final label = remote['label']?.toString() ?? 'Video';
        final path = '__remote_video__:$url';
        final isSelected = selectedPath == path || selectedPath == url;
        return _WallpaperTile(
          label: label,
          path: path,
          isSelected: isSelected,
          isVideo: true,
          onTap: () => onSelect(path),
        );
      },
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.label,
    required this.path,
    required this.isSelected,
    required this.onTap,
    this.isAnimated = false,
    this.isVideo = false,
  });

  final String label;
  final String path;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAnimated;
  final bool video = false;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF00A3C4) : const Color(0xFFE5E7EB),
                width: isSelected ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: AlarmWallpaperImage(path: path),
          ),
          // Type badge top right
          if (isAnimated || isVideo)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isVideo ? Icons.play_arrow_rounded : Icons.auto_awesome,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          // Gradient and Label at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF00A3C4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Screen 4: Alarm Ringing Screen (Matches Design Image 5) ───────────────────
class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({
    super.key,
    required this.alarmId,
    this.overrideAlarm,
    this.isPreview = false,
  });

  final int alarmId;
  final CampusAlarm? overrideAlarm;
  final bool isPreview;

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> {
  CampusAlarm? _alarm;
  bool _snoozed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.overrideAlarm != null) {
      setState(() => _alarm = widget.overrideAlarm);
      return;
    }
    final alarms = await AlarmService.load();
    final matches = alarms.where((a) => a.id == widget.alarmId).toList();
    if (!mounted) return;
    setState(() {
      _alarm = matches.isNotEmpty ? matches.first : null;
    });
  }

  Future<void> _handleSnooze() async {
    if (_snoozed) return;
    setState(() => _snoozed = true);
    if (!widget.isPreview) {
      await AlarmService.snooze(widget.alarmId, 5); // Strictly 5 min
    }
    if (mounted) context.go('/alarms');
  }

  void _openMissionSolver() {
    final alarm = _alarm;
    if (alarm == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MissionDialog(
        mission: alarm.mission,
        difficulty: alarm.difficulty,
        isPreview: widget.isPreview,
        onSuccess: () async {
          Navigator.pop(ctx);
          if (!widget.isPreview) {
            await AlarmService.stop(widget.alarmId);
          }
          if (mounted) context.go('/alarms');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarm = _alarm;
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM d EEE').format(now);
    final timeStr = DateFormat('h:mm').format(now);
    final wallpaperPath = alarm?.wallpaperPath ?? '__builtin__:sunset';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Wallpaper background (fullscreen)
          Positioned.fill(
            child: AlarmWallpaperImage(path: wallpaperPath),
          ),

          // 2. Subtle overlay for contrast
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black38, Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 3. UI Content (Top Date & Time, Center Art, Bottom Snooze & Start Mission)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Date (e.g. September 28 Mon)
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Huge Time (e.g. 2:19)
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 78,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      height: 1.0,
                      shadows: [Shadow(blurRadius: 16, color: Colors.black45)],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pill Badge with label: "🐥 Wake up early"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🐥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          alarm?.label ?? 'Wake up',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center Area: Spacer so wallpaper is fully visible
                  const Spacer(),

                  // Snooze Button (White pill - allowed ONLY 1 time, 5 min)
                  if (!_snoozed)
                    GestureDetector(
                      onTap: _handleSnooze,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.snooze_rounded, color: Colors.black87, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Snooze (5 min)',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'Snooze used (Only 1 snooze allowed)',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Big Prominent "Start Mission" Red Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _openMissionSolver,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B5C), // Bold coral/red
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      child: const Text(
                        'Start Mission',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2-Step Mission Solver Dialog (User MUST complete 2 tasks to turn off) ─────
class _MissionDialog extends StatefulWidget {
  const _MissionDialog({
    required this.mission,
    required this.difficulty,
    required this.onSuccess,
    this.isPreview = false,
  });

  final AlarmMission mission;
  final int difficulty;
  final VoidCallback onSuccess;
  final bool isPreview;

  @override
  State<_MissionDialog> createState() => _MissionDialogState();
}

class _MissionDialogState extends State<_MissionDialog> {
  int _currentTask = 1; // 1 or 2
  final math.Random _rng = math.Random();
  final TextEditingController _textCtrl = TextEditingController();

  // Math state
  int _mathLeft = 0;
  int _mathRight = 0;
  String _mathOp = '+';
  int _mathExpected = 0;

  // Memory state
  String _memoryCode = '';
  bool _memoryRevealed = true;
  Timer? _memoryTimer;

  // Shake state
  int _shakesCount = 0;
  StreamSubscription<List<double>>? _motionSub;
  int? _lastMagnitude;
  DateTime? _lastShakeAt;

  // Typing state
  String _targetPhrase = '';

  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initTask(1);
    if (widget.mission == AlarmMission.shake) {
      _motionSub = AlarmService.motionEvents().listen(_onMotion, onError: (_) {});
    }
  }

  void _initTask(int taskNum) {
    _textCtrl.clear();
    _errorMessage = '';
    _currentTask = taskNum;

    switch (widget.mission) {
      case AlarmMission.math:
        if (widget.difficulty == 0) {
          // Easy: 10..40 + 2..15
          _mathLeft = 10 + _rng.nextInt(30);
          _mathRight = 2 + _rng.nextInt(15);
          _mathOp = '+';
          _mathExpected = _mathLeft + _mathRight;
        } else if (widget.difficulty == 1) {
          // Medium: 20..70 + 15..50
          _mathLeft = 20 + _rng.nextInt(50);
          _mathRight = 15 + _rng.nextInt(35);
          _mathOp = '+';
          _mathExpected = _mathLeft + _mathRight;
        } else {
          // Hard: multiplication or 3 digits
          _mathLeft = 12 + _rng.nextInt(30);
          _mathRight = 4 + _rng.nextInt(8);
          _mathOp = '×';
          _mathExpected = _mathLeft * _mathRight;
        }
        break;

      case AlarmMission.memory:
        _memoryCode = List.generate(4, (_) => _rng.nextInt(10)).join();
        _memoryRevealed = true;
        _memoryTimer?.cancel();
        _memoryTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _memoryRevealed = false);
        });
        break;

      case AlarmMission.shake:
        _shakesCount = 0;
        break;

      case AlarmMission.typing:
        const phrasesTask1 = ['I am wide awake and ready', 'Good morning CampusSetu', 'Time to start the day'];
        const phrasesTask2 = ['Today is full of opportunities', 'Success begins right now', 'I am fully awake and focused'];
        _targetPhrase = taskNum == 1 ? phrasesTask1[_rng.nextInt(phrasesTask1.length)] : phrasesTask2[_rng.nextInt(phrasesTask2.length)];
        break;
    }
  }

  void _onMotion(List<double> v) {
    if (v.length < 3 || widget.mission != AlarmMission.shake) return;
    final mag = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).round();
    final last = _lastMagnitude;
    _lastMagnitude = mag;
    final now = DateTime.now();
    if (last != null && (mag - last).abs() >= 4 && mounted &&
        (_lastShakeAt == null || now.difference(_lastShakeAt!).inMilliseconds >= 250) &&
        _shakesCount < 20) {
      _lastShakeAt = now;
      setState(() => _shakesCount++);
      if (_shakesCount >= 20) {
        _completeTask();
      }
    }
  }

  void _submitAnswer() {
    switch (widget.mission) {
      case AlarmMission.math:
        final entered = int.tryParse(_textCtrl.text.trim());
        if (entered == _mathExpected) {
          _completeTask();
        } else {
          setState(() {
            _errorMessage = 'Wrong answer. Try again!';
            _initTask(_currentTask);
          });
        }
        break;

      case AlarmMission.memory:
        if (_textCtrl.text.trim() == _memoryCode) {
          _completeTask();
        } else {
          setState(() {
            _errorMessage = 'Incorrect code. New code generated!';
            _initTask(_currentTask);
          });
        }
        break;

      case AlarmMission.typing:
        if (_textCtrl.text.trim().toLowerCase() == _targetPhrase.toLowerCase()) {
          _completeTask();
        } else {
          setState(() {
            _errorMessage = 'Match the phrase exactly.';
          });
        }
        break;

      case AlarmMission.shake:
        if (_shakesCount >= 20) _completeTask();
        break;
    }
  }

  void _completeTask() {
    if (_currentTask == 1) {
      // Advance to Task 2 of 2!
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Task 1 completed! 1 more task to turn off alarm.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _initTask(2);
      });
    } else {
      // Both tasks finished!
      widget.onSuccess();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _memoryTimer?.cancel();
    _motionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Progress "Task 1 of 2" or "Task 2 of 2"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Task $_currentTask of 2',
                  style: const TextStyle(
                    color: Color(0xFF00C7E5),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                // 2 Step Progress Dots
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C7E5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _currentTask == 2 ? const Color(0xFF00C7E5) : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mission Content Widget
            if (widget.mission == AlarmMission.math) ...[
              const Text('Solve the math problem', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 14),
              Text(
                '$_mathLeft $_mathOp $_mathRight = ?',
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _textCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'Answer',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _submitAnswer(),
              ),
            ] else if (widget.mission == AlarmMission.memory) ...[
              Text(
                _memoryRevealed ? 'Memorize this 4-digit code:' : 'Enter the code from memory:',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (_memoryRevealed)
                Text(
                  _memoryCode,
                  style: const TextStyle(color: Color(0xFF00C7E5), fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 10),
                )
              else
                TextField(
                  controller: _textCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF374151),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _submitAnswer(),
                ),
            ] else if (widget.mission == AlarmMission.typing) ...[
              const Text('Type the phrase exactly:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 14),
              Text(
                '"$_targetPhrase"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _textCtrl,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type phrase here',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _submitAnswer(),
              ),
            ] else if (widget.mission == AlarmMission.shake) ...[
              const Text('Shake your phone vigorously!', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              Text(
                '$_shakesCount / 20',
                style: const TextStyle(color: Color(0xFF00C7E5), fontSize: 44, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _shakesCount / 20.0,
                  color: const Color(0xFF00C7E5),
                  backgroundColor: Colors.white12,
                  minHeight: 12,
                ),
              ),
            ],

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_errorMessage, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.w600)),
            ],

            const SizedBox(height: 24),
            // Submit Button
            if (widget.mission != AlarmMission.shake)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submitAnswer,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00A3C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _currentTask == 1 ? 'Verify & Continue' : 'Finish & Turn Off Alarm',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

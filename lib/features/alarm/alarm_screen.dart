import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import 'alarm_model.dart';
import 'alarm_service.dart';
import 'alarm_wallpaper_image.dart';

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
      useSafeArea: true,
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
      // Android may have stored the alarm but reported that scheduling is paused.
      // Keep its media paths valid while the alarm is visible in the local store.
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
        content: Text('Remove ${alarm.label} and its scheduled alerts?'),
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

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('Alarms', style: AppTypography.soraHeading2()),
        actions: [
          IconButton(
            tooltip: 'Add alarm',
            onPressed: isWeb ? null : () => _edit(),
            icon: const Icon(Icons.add_alarm_rounded),
          ),
        ],
      ),
      floatingActionButton: isWeb ? null : FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: AppColors.cyanDeep,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('New alarm'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
              children: [
                NeuCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: const Color(0xFFDB2777).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.alarm_rounded, color: Color(0xFFDB2777)),
                    ),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Wake up on your terms', style: AppTypography.soraHeading3()),
                      const SizedBox(height: 4),
                      Text('Choose a wallpaper and sound, repeat days, snooze, and a mission.', style: AppTypography.interBodySmall()),
                    ])),
                  ]),
                ),
                if (isWeb) ...[
                  const SizedBox(height: 12),
                  _InfoBanner(text: 'Browser tabs can sleep or close, so web alarms cannot guarantee a ring. Use the CampusSetu Android app for scheduled alarms.'),
                ] else if (!_exactAccess) ...[
                  const SizedBox(height: 12),
                  _InfoBanner(text: 'Android requires alarm and notification access. CampusSetu asks when you save your first active alarm.'),
                ],
                const SizedBox(height: 18),
                if (_alarms.isEmpty)
                  NeuCard(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
                    child: Column(children: [
                      Icon(Icons.alarm_off_rounded, size: 38, color: AppColors.inkSoft),
                      const SizedBox(height: 12),
                      Text('No alarms yet', style: AppTypography.soraHeading3()),
                      const SizedBox(height: 6),
                      Text(isWeb ? 'Open CampusSetu on Android to create a reliable alarm.' : 'Create one for class, study time, or your morning routine.', textAlign: TextAlign.center, style: AppTypography.interBodySmall()),
                      if (!isWeb) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Set an alarm')),
                      ],
                    ]),
                  )
                else
                  ..._alarms.map((alarm) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _AlarmTile(
                      alarm: alarm,
                      onChanged: (enabled) => _toggle(alarm, enabled),
                      onEdit: () => _edit(alarm),
                      onDelete: () => _delete(alarm),
                    ),
                  )),
                const SizedBox(height: 8),
                Text('Alarms stay on this device. They do not need a CampusSetu account session or internet connection to ring.', style: AppTypography.interCaption(), textAlign: TextAlign.center),
              ],
            ),
    );
  }
}

class _AlarmTile extends StatelessWidget {
  const _AlarmTile({required this.alarm, required this.onChanged, required this.onEdit, required this.onDelete});
  final CampusAlarm alarm;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: alarm.hour, minute: alarm.minute).format(context);
    final days = alarm.days.isEmpty ? 'One time' : alarm.days.map((d) => _dayShort[d - 1]).join(' · ');
    final mission = _missionName(alarm.mission);
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(16, 13, 10, 12),
      onTap: onEdit,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(time, style: AppTypography.soraDisplay(size: 36, color: alarm.enabled ? AppColors.ink : AppColors.inkMuted)),
          const SizedBox(height: 1),
          Text(alarm.label.trim().isEmpty ? 'Wake-up' : alarm.label, style: AppTypography.interButton(size: 14, color: alarm.enabled ? AppColors.ink : AppColors.inkSoft)),
          const SizedBox(height: 5),
          Wrap(spacing: 6, runSpacing: 5, children: [
            _Pill(text: days, color: AppColors.cyanDeep),
            _Pill(text: mission, color: const Color(0xFF7C3AED)),
          ]),
        ])),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Switch(value: alarm.enabled, onChanged: onChanged, activeTrackColor: AppColors.cyanDeep),
          PopupMenuButton<String>(
            tooltip: 'Alarm options',
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            icon: Icon(Icons.more_horiz_rounded, color: AppColors.inkSoft),
          ),
        ]),
      ]),
    );
  }
}

class _AlarmEditor extends StatefulWidget {
  const _AlarmEditor({required this.id, this.alarm});
  final int id;
  final CampusAlarm? alarm;
  @override
  State<_AlarmEditor> createState() => _AlarmEditorState();
}

enum _AlarmSoundSource { system, file }

class _AlarmEditorState extends State<_AlarmEditor> {
  late final TextEditingController _label;
  late TimeOfDay _time;
  late Set<int> _days;
  late int _snooze;
  late AlarmMission _mission;
  late String _soundUri;
  late String _soundName;
  late String _customSoundPath;
  late String _wallpaperPath;
  late double _volume;
  late bool _vibration;
  bool _enabled = true;
  bool _saving = false;
  bool _saved = false;
  final List<String> _createdAssets = [];

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _label = TextEditingController(text: a?.label ?? 'Wake up');
    _time = TimeOfDay(hour: a?.hour ?? 7, minute: a?.minute ?? 0);
    _days = {...?a?.days};
    _snooze = a?.snoozeMinutes ?? 5;
    _mission = a?.mission ?? AlarmMission.math;
    _soundUri = a?.soundUri ?? '';
    _soundName = a?.soundName ?? 'Default alarm';
    _customSoundPath = a?.customSoundPath ?? '';
    _wallpaperPath = a?.wallpaperPath ?? '';
    _volume = a?.volume ?? 1.0;
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

  Future<void> _chooseTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null && mounted) setState(() => _time = time);
  }

  Future<void> _chooseSound() async {
    final source = await showModalBottomSheet<_AlarmSoundSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Phone alarm sounds'),
          subtitle: const Text('Choose a tone installed on this device'),
          onTap: () => Navigator.pop(context, _AlarmSoundSource.system),
        ),
        ListTile(
          leading: const Icon(Icons.audio_file_outlined),
          title: const Text('Choose my audio file'),
          subtitle: const Text('Use an audio file stored on this device'),
          onTap: () => Navigator.pop(context, _AlarmSoundSource.file),
        ),
        const SizedBox(height: 8),
      ])),
    );
    if (source == null || !mounted) return;
    if (source == _AlarmSoundSource.system) {
      final selected = await AlarmService.pickSound(currentUri: _soundUri);
      if (selected != null && mounted) {
        final previousCustomPath = _customSoundPath;
        setState(() {
          _soundUri = selected['uri'] ?? '';
          _soundName = selected['name'] ?? 'Alarm sound';
          _customSoundPath = '';
        });
        await _discardDraftAsset(previousCustomPath);
      }
      return;
    }
    try {
      final selected = await AlarmService.pickCustomSound(alarmId: widget.id);
      if (selected != null && mounted) {
        final previousCustomPath = _customSoundPath;
        setState(() {
          _customSoundPath = selected['path'] ?? '';
          _soundUri = '';
          _soundName = selected['name'] ?? 'Custom sound';
          if (_customSoundPath.isNotEmpty) _createdAssets.add(_customSoundPath);
        });
        await _discardDraftAsset(previousCustomPath);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that audio file. Try another file.')));
    }
  }

  Future<void> _chooseWallpaper() async {
    try {
      final path = await AlarmService.pickWallpaper(alarmId: widget.id);
      if (path != null && mounted) {
        final previousWallpaperPath = _wallpaperPath;
        setState(() {
          _wallpaperPath = path;
          _createdAssets.add(path);
        });
        await _discardDraftAsset(previousWallpaperPath);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that image. Try another photo.')));
    }
  }

  Future<void> _discardDraftAsset(String path) async {
    if (path.isEmpty || !_createdAssets.remove(path)) return;
    await AlarmService.deleteManagedAsset(path);
  }

  Future<void> _removeWallpaper() async {
    final previous = _wallpaperPath;
    setState(() => _wallpaperPath = '');
    await _discardDraftAsset(previous);
  }

  void _save() {
    if (_saving) return;
    setState(() => _saving = true);
    _saved = true;
    Navigator.pop(context, CampusAlarm(
      id: widget.id,
      hour: _time.hour,
      minute: _time.minute,
      label: _label.text.trim().isEmpty ? 'Wake up' : _label.text.trim(),
      days: _days.toList()..sort(),
      enabled: _enabled,
      snoozeMinutes: _snooze,
      mission: _mission,
      soundUri: _soundUri,
      soundName: _soundName,
      customSoundPath: _customSoundPath,
      wallpaperPath: _wallpaperPath,
      volume: _volume,
      vibration: _vibration,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
          child: Row(children: [
            Expanded(child: Text(widget.alarm == null ? 'New alarm' : 'Edit alarm', style: AppTypography.soraHeading2())),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          NeuCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            onTap: _chooseTime,
            child: Row(children: [
              Icon(Icons.schedule_rounded, color: AppColors.cyanDeep, size: 22),
              const SizedBox(width: 14),
              Text(_time.format(context), style: AppTypography.soraDisplay(size: 38, color: AppColors.cyanDeep)),
              const Spacer(),
              Text('CHANGE', style: AppTypography.interBadge(color: AppColors.cyanDeep)),
            ]),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'LABEL'),
          const SizedBox(height: 8),
          TextField(
            controller: _label,
            maxLength: 40,
            decoration: const InputDecoration(hintText: 'Wake up', prefixIcon: Icon(Icons.label_outline_rounded), counterText: ''),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'REPEAT'),
          const SizedBox(height: 9),
          Wrap(spacing: 7, children: List.generate(7, (index) {
            final day = index + 1;
            final selected = _days.contains(day);
            return ChoiceChip(
              label: Text(_dayShort[index]),
              selected: selected,
              onSelected: (v) => setState(() => v ? _days.add(day) : _days.remove(day)),
              selectedColor: AppColors.cyanDeep.withValues(alpha: 0.22),
              labelStyle: TextStyle(color: selected ? AppColors.cyanDeep : AppColors.inkSoft, fontWeight: FontWeight.w700),
              side: BorderSide(color: selected ? AppColors.cyanDeep : AppColors.inkMuted.withValues(alpha: 0.22)),
              shape: const CircleBorder(),
            );
          })),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_days.isEmpty ? 'Rings once at the next matching time' : 'Repeats every ${_days.length == 7 ? 'day' : 'selected day'}', style: AppTypography.interCaption()),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'RINGING SCREEN WALLPAPER'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 150,
              width: double.infinity,
              color: AppColors.inkMuted.withValues(alpha: 0.12),
              child: _wallpaperPath.isEmpty
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.wallpaper_rounded, size: 30, color: AppColors.inkSoft),
                      const SizedBox(height: 7),
                      Text('Default alarm background', style: AppTypography.interCaption()),
                    ])
                  : Stack(fit: StackFit.expand, children: [
                      AlarmWallpaperImage(path: _wallpaperPath),
                      const ColoredBox(color: Color(0x55000000)),
                      Center(child: Text('Alarm preview', style: AppTypography.soraHeading3(color: Colors.white))),
                    ]),
            ),
          ),
          Row(children: [
            Expanded(child: Text('Choose a photo for this alarm’s ringing screen. It stays on this device.', style: AppTypography.interCaption())),
            TextButton.icon(
              onPressed: _chooseWallpaper,
              icon: Icon(_wallpaperPath.isEmpty ? Icons.add_photo_alternate_outlined : Icons.edit_outlined),
              label: Text(_wallpaperPath.isEmpty ? 'Choose' : 'Change'),
            ),
            if (_wallpaperPath.isNotEmpty)
              IconButton(tooltip: 'Remove wallpaper', onPressed: _removeWallpaper, icon: const Icon(Icons.delete_outline_rounded)),
          ]),
          const SizedBox(height: 18),
          _SectionTitle(title: 'WAKE-UP MISSION'),
          const SizedBox(height: 8),
          DropdownButtonFormField<AlarmMission>(
            value: _mission,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.psychology_alt_rounded)),
            items: AlarmMission.values.map((m) => DropdownMenuItem(value: m, child: Text(_missionName(m)))).toList(),
            onChanged: (v) { if (v != null) setState(() => _mission = v); },
          ),
          const SizedBox(height: 7),
          Text('Complete the mission in CampusSetu to stop the alarm. Shake uses the phone motion sensor.', style: AppTypography.interCaption()),
          const SizedBox(height: 18),
          _SectionTitle(title: 'SOUND & SNOOZE'),
          const SizedBox(height: 8),
          NeuCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.music_note_rounded, color: AppColors.cyanDeep),
                title: const Text('Alarm sound'),
                subtitle: Text(_soundName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _chooseSound,
              ),
              Divider(height: 1, color: AppColors.inkMuted.withValues(alpha: 0.16)),
              ListTile(
                leading: Icon(Icons.snooze_rounded, color: AppColors.cyanDeep),
                title: const Text('Snooze length'),
                trailing: DropdownButton<int>(
                  value: _snooze,
                  underline: const SizedBox.shrink(),
                  items: const [0, 5, 10, 15, 20].map((m) => DropdownMenuItem(value: m, child: Text(m == 0 ? 'Off' : '$m min'))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _snooze = v); },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.volume_up_rounded, color: AppColors.cyanDeep),
                    const SizedBox(width: 14),
                    const Text('Alarm volume'),
                    const Spacer(),
                    Text('${(_volume * 100).round()}%'),
                  ]),
                  Slider(value: _volume, min: 0.2, max: 1, onChanged: (v) => setState(() => _volume = v)),
                ]),
              ),
            ]),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibrate while ringing'),
            value: _vibration,
            onChanged: (v) => setState(() => _vibration = v),
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alarm enabled'),
            subtitle: const Text('You can turn it off without deleting it'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ])),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(width: double.infinity, height: 52, child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(backgroundColor: AppColors.cyanDeep, foregroundColor: Colors.white),
            child: Text(widget.alarm == null ? 'Save alarm' : 'Save changes'),
          )),
        )),
      ]),
    );
  }
}

class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({super.key, required this.alarmId});
  final int alarmId;
  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> {
  CampusAlarm? _alarm;
  final TextEditingController _answer = TextEditingController();
  final math.Random _random = math.Random();
  StreamSubscription<List<double>>? _motionSub;
  Timer? _memoryTimer;
  bool _memoryVisible = true;
  bool _ringLoaded = false;
  int _left = 0;
  int _right = 0;
  int _shakeCount = 0;
  int? _lastMagnitude;
  DateTime? _lastShakeAt;
  String _memorySequence = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alarms = await AlarmService.load();
    final matches = alarms.where((a) => a.id == widget.alarmId).toList();
    final found = matches.isEmpty ? null : matches.first;
    if (!mounted) return;
    setState(() {
      _alarm = found;
      _ringLoaded = true;
      _left = 11 + _random.nextInt(48);
      _right = 2 + _random.nextInt(19);
      _memorySequence = List.generate(4, (_) => _random.nextInt(10)).join();
    });
    if (found?.mission == AlarmMission.memory) {
      _memoryTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _memoryVisible = false); });
    } else if (found?.mission == AlarmMission.shake) {
      _motionSub = AlarmService.motionEvents().listen(_onMotion, onError: (_) {});
    }
  }

  void _onMotion(List<double> v) {
    if (v.length < 3) return;
    final magnitude = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).round();
    final last = _lastMagnitude;
    _lastMagnitude = magnitude;
    final now = DateTime.now();
    if (last != null && (magnitude - last).abs() >= 4 && mounted &&
        (_lastShakeAt == null || now.difference(_lastShakeAt!).inMilliseconds >= 300) &&
        _shakeCount < 20) {
      _lastShakeAt = now;
      setState(() => _shakeCount++);
    }
  }

  bool get _isCorrect {
    switch (_alarm?.mission ?? AlarmMission.math) {
      case AlarmMission.math:
        return int.tryParse(_answer.text.trim()) == _left + _right;
      case AlarmMission.memory:
      case AlarmMission.typing:
        return _answer.text.trim() == _memorySequenceOrPhrase;
      case AlarmMission.shake:
        return _shakeCount >= 20;
    }
  }

  String get _memorySequenceOrPhrase => _alarm?.mission == AlarmMission.memory ? _memorySequence : 'I am awake';

  Future<void> _dismiss() async {
    if (!_isCorrect) {
      setState(() => _error = _alarm?.mission == AlarmMission.shake ? 'Keep shaking until the counter reaches 20.' : 'That answer is not correct yet.');
      return;
    }
    await AlarmService.stop(widget.alarmId);
    if (mounted) context.go('/alarms');
  }

  Future<void> _snooze() async {
    await AlarmService.snooze(widget.alarmId, _alarm?.snoozeMinutes ?? 5);
    if (mounted) context.go('/alarms');
  }

  @override
  void dispose() {
    _answer.dispose();
    _memoryTimer?.cancel();
    _motionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alarm = _alarm;
    final mission = alarm?.mission ?? AlarmMission.math;
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      body: Stack(fit: StackFit.expand, children: [
        if (alarm != null && alarm.wallpaperPath.isNotEmpty)
          Positioned.fill(child: AlarmWallpaperImage(path: alarm.wallpaperPath)),
        if (alarm != null && alarm.wallpaperPath.isNotEmpty)
          const Positioned.fill(child: ColoredBox(color: Color(0x99000000))),
        SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(padding: const EdgeInsets.fromLTRB(26, 20, 26, 28), child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm_rounded, size: 62, color: Color(0xFFFB7185)),
            const SizedBox(height: 18),
            Text(alarm?.label ?? 'Wake up', style: AppTypography.interButton(color: Colors.white, size: 19)),
            const SizedBox(height: 6),
            Text(alarm == null ? TimeOfDay.now().format(context) : TimeOfDay(hour: alarm.hour, minute: alarm.minute).format(context), style: AppTypography.soraDisplay(size: 56, color: Colors.white)),
            const SizedBox(height: 35),
            if (!_ringLoaded)
              const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Colors.white))
            else
              _missionWidget(mission),
            const Spacer(),
            SizedBox(width: double.infinity, height: 54, child: FilledButton(
              onPressed: _ringLoaded ? _dismiss : null,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDB2777), foregroundColor: Colors.white),
              child: const Text('Complete mission & dismiss'),
            )),
            const SizedBox(height: 10),
            if (_error.isNotEmpty) ...[
              Text(_error, style: const TextStyle(color: Color(0xFFFDA4AF)), textAlign: TextAlign.center),
              const SizedBox(height: 6),
            ],
            if ((alarm?.snoozeMinutes ?? 5) > 0)
              TextButton.icon(onPressed: _snooze, icon: const Icon(Icons.snooze_rounded, color: Colors.white70), label: Text('Snooze ${alarm?.snoozeMinutes ?? 5} minutes', style: const TextStyle(color: Colors.white70))),
          ],
        )),
      ))),
      ]),
    );
  }

  Widget _missionWidget(AlarmMission mission) {
    switch (mission) {
      case AlarmMission.math:
        return _MissionCard(
          icon: Icons.calculate_outlined,
          title: 'Solve to wake up',
          detail: '$_left + $_right = ?',
          child: TextField(
            controller: _answer,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24),
            decoration: const InputDecoration(hintText: 'Your answer', hintStyle: TextStyle(color: Colors.white38)),
          ),
        );
      case AlarmMission.memory:
        return _MissionCard(
          icon: Icons.psychology_alt_outlined,
          title: 'Remember the code',
          detail: _memoryVisible ? _memorySequence : 'Enter the 4 digits you saw',
          child: _memoryVisible ? const SizedBox(height: 50) : TextField(
            controller: _answer,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(hintText: '••••', hintStyle: TextStyle(color: Colors.white38)),
          ),
        );
      case AlarmMission.typing:
        return _MissionCard(
          icon: Icons.keyboard_alt_outlined,
          title: 'Type the phrase',
          detail: 'I am awake',
          child: TextField(
            controller: _answer,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17),
            decoration: const InputDecoration(hintText: 'Type it here', hintStyle: TextStyle(color: Colors.white38)),
          ),
        );
      case AlarmMission.shake:
        return _MissionCard(
          icon: Icons.vibration_rounded,
          title: 'Shake to wake',
          detail: '$_shakeCount / 20',
          child: LinearProgressIndicator(value: _shakeCount / 20, color: const Color(0xFFFB7185), backgroundColor: Colors.white12),
        );
    }
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.icon, required this.title, required this.detail, this.child});
  final IconData icon;
  final String title;
  final String detail;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: const Color(0xFF1A263A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
    child: Column(children: [
      Icon(icon, size: 28, color: const Color(0xFFFB7185)),
      const SizedBox(height: 12),
      Text(title, style: AppTypography.soraHeading3(color: Colors.white)),
      const SizedBox(height: 14),
      Text(detail, textAlign: TextAlign.center, style: AppTypography.soraDisplay(size: 29, color: Colors.white)),
      if (child != null) ...[const SizedBox(height: 14), child!],
    ]),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: AppTypography.interBodySmall(color: AppColors.ink))),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: AppTypography.interBadge(color: AppColors.inkSoft));
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
    child: Text(text, style: AppTypography.interBadge(color: color)),
  );
}

const _dayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _missionName(AlarmMission mission) => switch (mission) {
  AlarmMission.math => 'Math',
  AlarmMission.memory => 'Memory',
  AlarmMission.typing => 'Typing',
  AlarmMission.shake => 'Shake',
};

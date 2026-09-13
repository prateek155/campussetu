// lib/features/admin/admin_pulse_screen.dart
// CampusSetu Pulse — Real-time activity monitor with suspicious activity detection
import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/api_service.dart';

class AdminPulseScreen extends StatefulWidget {
  const AdminPulseScreen({super.key});
  @override
  State<AdminPulseScreen> createState() => _AdminPulseScreenState();
}

class _AdminPulseScreenState extends State<AdminPulseScreen>
    with TickerProviderStateMixin {
  // ── Palette ─────────────────────────────────────────────────
  static const _bg        = Color(0xFF0D0F1A);
  static const _card      = Color(0xFF141728);
  static const _cardAlt   = Color(0xFF1C2033);
  static const _border    = Color(0xFF252840);
  static const _cyan      = Color(0xFF3FD8F5);
  static const _green     = Color(0xFF22C55E);
  static const _red       = Color(0xFFEF4444);
  static const _orange    = Color(0xFFF59E0B);
  static const _purple    = Color(0xFFA855F7);
  static const _yellow    = Color(0xFFEAB308);
  static const _ink       = Color(0xFFE9EBEE);
  static const _inkSoft   = Color(0xFF9CA3AF);

  // ── State ────────────────────────────────────────────────────
  Map<String, dynamic> _stats      = {};
  List<Map<String, dynamic>> _feed = [];
  List<Map<String, dynamic>> _sus  = [];
  bool _incidentMode               = false;
  Map<String, dynamic>? _incident;
  bool _actioning                  = false;

  // ── Animations ───────────────────────────────────────────────
  late final AnimationController _netCtrl;
  late final AnimationController _pulseCtrl;
  late Timer _ticker;

  // 60-point rolling activity chart buffer (0.0 – 1.0)
  final _chartData = List<double>.filled(60, 0.05);

  @override
  void initState() {
    super.initState();
    _netCtrl   = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _fetch();
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _netCtrl.dispose();
    _pulseCtrl.dispose();
    _ticker.cancel();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────
  Future<void> _ensureToken() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      final t = await u.getIdToken();
      if (t != null) ApiService().setToken(t);
    }
  }

  Future<void> _fetch() async {
    try {
      await _ensureToken();
      final results = await Future.wait([
        ApiService().getPulseStats()      .catchError((_) => <String, dynamic>{}),
        ApiService().getPulseLiveFeed(limit: 25).catchError((_) => <String, dynamic>{}),
        ApiService().getPulseSuspicious() .catchError((_) => <String, dynamic>{}),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final feed  = ((results[1] as Map<String, dynamic>)['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final sus   = ((results[2] as Map<String, dynamic>)['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Push a new chart sample
      final events = (stats['total_events'] as num?)?.toDouble() ?? 0;
      final sample = (events / 120.0 + math.Random().nextDouble() * 0.25).clamp(0.04, 0.96);
      _chartData.removeAt(0);
      _chartData.add(sample);

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _feed  = feed;
        _sus   = sus;
        // Auto-switch to incident view when a HIGH risk appears
        if (!_incidentMode && sus.any((s) => s['risk_level'] == 'HIGH')) {
          _incidentMode = true;
          _incident = sus.firstWhere((s) => s['risk_level'] == 'HIGH');
        }
        // Auto-clear incident view when no more threats
        if (sus.isEmpty) {
          _incidentMode = false;
          _incident = null;
        }
      });
    } catch (_) {}
  }

  // ── Actions ──────────────────────────────────────────────────
  Future<void> _freeze(String uid) async {
    setState(() => _actioning = true);
    try {
      await _ensureToken();
      await ApiService().freezeUser(uid);
      await ApiService().dismissSuspicious(uid);
      if (!mounted) return;
      setState(() {
        _sus.removeWhere((s) => (s['user_id'] ?? s['id']) == uid);
        _incidentMode = false;
        _incident = null;
        _actioning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account frozen — user blocked'), backgroundColor: _red));
    } catch (e) {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _restrict(String uid) async {
    setState(() => _actioning = true);
    try {
      await _ensureToken();
      await ApiService().restrictUser(uid);
      await ApiService().dismissSuspicious(uid);
      if (!mounted) return;
      setState(() {
        _sus.removeWhere((s) => (s['user_id'] ?? s['id']) == uid);
        _incidentMode = false;
        _incident = null;
        _actioning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Access restricted'), backgroundColor: _orange));
    } catch (e) {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _dismiss(String uid) async {
    try {
      await _ensureToken();
      await ApiService().dismissSuspicious(uid);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _sus.removeWhere((s) => (s['user_id'] ?? s['id']) == uid);
        _incidentMode = false;
        _incident = null;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          _Header(
            hasSuspicious: _sus.isNotEmpty,
            incidentMode: _incidentMode,
            pulseCtrl: _pulseCtrl,
            onNormal: () => setState(() { _incidentMode = false; _incident = null; }),
            onIncident: () {
              if (_sus.isNotEmpty) setState(() { _incidentMode = true; _incident = _sus.first; });
            },
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _incidentMode && _incident != null
                  ? _IncidentView(
                      key: ValueKey(_incident!['user_id'] ?? _incident!['id']),
                      incident: _incident!,
                      actioning: _actioning,
                      onFreeze: _freeze,
                      onRestrict: _restrict,
                      onDismiss: _dismiss,
                    )
                  : _NormalView(
                      key: const ValueKey('normal'),
                      stats: _stats,
                      feed: _feed,
                      chartData: _chartData,
                      hasSuspicious: _sus.isNotEmpty,
                      netCtrl: _netCtrl,
                      onRefresh: _fetch,
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool hasSuspicious, incidentMode;
  final AnimationController pulseCtrl;
  final VoidCallback onNormal, onIncident;
  const _Header({
    required this.hasSuspicious,
    required this.incidentMode,
    required this.pulseCtrl,
    required this.onNormal,
    required this.onIncident,
  });

  static const _card   = Color(0xFF141728);
  static const _border = Color(0xFF252840);
  static const _green  = Color(0xFF22C55E);
  static const _red    = Color(0xFFEF4444);
  static const _ink    = Color(0xFFE9EBEE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pulse', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
              color: _ink, letterSpacing: -0.5, fontFamily: 'monospace')),
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: (hasSuspicious ? _red : _green)
                      .withValues(alpha: 0.5 + 0.5 * pulseCtrl.value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                hasSuspicious ? 'Incident detected' : 'Monitoring',
                style: TextStyle(fontSize: 11, color: hasSuspicious ? _red : _green,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ]),
        const Spacer(),
        if (hasSuspicious) ...[
          _ModeChip(label: 'Normal', isActive: !incidentMode, color: _green, onTap: onNormal),
          const SizedBox(width: 8),
          _ModeChip(label: 'Incident', isActive: incidentMode, color: _red, onTap: onIncident),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _green.withValues(alpha: 0.3)),
            ),
            child: const Text('● Monitoring', style: TextStyle(fontSize: 11, color: _green, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Normal View
// ─────────────────────────────────────────────────────────────
class _NormalView extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> feed;
  final List<double> chartData;
  final bool hasSuspicious;
  final AnimationController netCtrl;
  final Future<void> Function() onRefresh;

  const _NormalView({
    super.key,
    required this.stats,
    required this.feed,
    required this.chartData,
    required this.hasSuspicious,
    required this.netCtrl,
    required this.onRefresh,
  });

  static const _cyan   = Color(0xFF3FD8F5);
  static const _orange = Color(0xFFF59E0B);
  static const _purple = Color(0xFFA855F7);
  static const _yellow = Color(0xFFEAB308);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _cyan,
      backgroundColor: const Color(0xFF141728),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats pills
          Row(children: [
            _StatPill(label: 'FEED',    pct: (stats['feed_pct']    as num?)?.toInt() ?? 0, color: _cyan),
            const SizedBox(width: 8),
            _StatPill(label: 'WALLET',  pct: (stats['wallet_pct']  as num?)?.toInt() ?? 0, color: _orange),
            const SizedBox(width: 8),
            _StatPill(label: 'CHAT',    pct: (stats['chat_pct']    as num?)?.toInt() ?? 0, color: _purple),
            const SizedBox(width: 8),
            _StatPill(label: 'CONNECT', pct: (stats['connect_pct'] as num?)?.toInt() ?? 0, color: _yellow),
          ]).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),

          // Network graph
          _NetworkGraph(ctrl: netCtrl, hasSuspicious: hasSuspicious)
              .animate().fadeIn(duration: 500.ms, delay: 100.ms),
          const SizedBox(height: 16),

          // Activity chart
          _ActivityChart(data: chartData).animate().fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 16),

          // Live feed
          _LiveFeedSection(feed: feed).animate().fadeIn(duration: 500.ms, delay: 300.ms),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Incident View
// ─────────────────────────────────────────────────────────────
class _IncidentView extends StatelessWidget {
  final Map<String, dynamic> incident;
  final bool actioning;
  final Future<void> Function(String) onFreeze, onRestrict, onDismiss;

  const _IncidentView({
    super.key,
    required this.incident,
    required this.actioning,
    required this.onFreeze,
    required this.onRestrict,
    required this.onDismiss,
  });

  static const _card    = Color(0xFF141728);
  static const _cardAlt = Color(0xFF1C2033);
  static const _red     = Color(0xFFEF4444);
  static const _ink     = Color(0xFFE9EBEE);
  static const _inkSoft = Color(0xFF9CA3AF);
  static const _orange  = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final name     = incident['user_name']?.toString() ?? 'Unknown';
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final risk     = incident['risk_level']?.toString() ?? 'HIGH';
    final uid      = (incident['user_id'] ?? incident['id'] ?? '').toString();
    final touched  = incident['accounts_touched'] ?? 0;
    final window   = incident['time_window_s'] ?? 0;
    final points   = incident['points_moved'] ?? 0;
    final actions  = (incident['recent_actions'] as List? ?? [])
        .map((a) => Map<String, dynamic>.from(a as Map)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Alert banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _red.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_rounded, color: _red, size: 20),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Suspicious activity detected',
                  style: TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 13)),
              SizedBox(height: 2),
              Text('Network view isolated to this account',
                  style: TextStyle(color: _inkSoft, fontSize: 11)),
            ]),
          ]),
        ).animate().fadeIn().slideY(begin: -0.3, duration: 350.ms),
        const SizedBox(height: 14),

        // User card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _red.withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // User row
            Row(children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _red.withValues(alpha: 0.5), width: 2),
                ),
                child: Center(child: Text(initial,
                    style: const TextStyle(color: _red, fontSize: 24, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('ID: ${uid.length > 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase()}',
                    style: const TextStyle(color: _inkSoft, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  risk == 'HIGH' ? '🔴  HIGH RISK' : '🟡  MEDIUM',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 18),

            // Stats grid
            Row(children: [
              _IncStat(value: '$touched', label: 'Accounts touched'),
              const SizedBox(width: 10),
              _IncStat(value: '${window}s', label: 'Time window'),
              const SizedBox(width: 10),
              _IncStat(value: '₹$points', label: 'Points moved'),
            ]),
            const SizedBox(height: 18),

            // Actions
            const Text('WHAT THEY\'RE DOING RIGHT NOW',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: _inkSoft, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            ...actions.map((a) => _IncActionTile(action: a)),
            const SizedBox(height: 18),

            // Buttons
            if (actioning)
              const Center(child: SizedBox(width: 36, height: 36,
                  child: CircularProgressIndicator(color: _red, strokeWidth: 2)))
            else ...[
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onFreeze(uid),
                    icon: const Icon(Icons.ac_unit_rounded, size: 16),
                    label: const Text('Freeze account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onRestrict(uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cardAlt, foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFF252840)),
                      ),
                    ),
                    child: const Text('Restrict access'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: () => onDismiss(uid),
                  child: const Text('Dismiss — this looks fine',
                      style: TextStyle(color: _inkSoft, fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF9CA3AF))),
                ),
              ),
            ],
          ]),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
        const SizedBox(height: 60),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Network Graph Widget
// ─────────────────────────────────────────────────────────────
class _NetworkGraph extends StatelessWidget {
  final AnimationController ctrl;
  final bool hasSuspicious;
  const _NetworkGraph({required this.ctrl, required this.hasSuspicious});

  static const _card   = Color(0xFF141728);
  static const _border = Color(0xFF252840);
  static const _cyan   = Color(0xFF3FD8F5);
  static const _orange = Color(0xFFF59E0B);
  static const _purple = Color(0xFFA855F7);
  static const _yellow = Color(0xFFEAB308);
  static const _green  = Color(0xFF22C55E);
  static const _red    = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // Legend
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _Dot(color: _cyan,   label: 'Post'),
              const SizedBox(width: 14),
              _Dot(color: _orange, label: 'Points'),
              const SizedBox(width: 14),
              _Dot(color: _purple, label: 'Chat'),
              const SizedBox(width: 14),
              _Dot(color: _yellow, label: 'Connect'),
              const SizedBox(width: 14),
              _Dot(color: _red,    label: 'Flagged'),
            ]),
          ),
        ),
        // Graph
        Expanded(
          child: Stack(children: [
            AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) => CustomPaint(
                painter: _NetPainter(t: ctrl.value, suspicious: hasSuspicious),
                child: const SizedBox.expand(),
              ),
            ),
            // Corner labels
            const Positioned(left: 8,  top: 4,    child: _CornerLabel(label: 'Feed',    icon: Icons.feed_outlined,                      color: _cyan)),
            const Positioned(right: 8, top: 4,    child: _CornerLabel(label: 'Wallet',  icon: Icons.account_balance_wallet_outlined,     color: _orange)),
            const Positioned(left: 8,  bottom: 4, child: _CornerLabel(label: 'Chat',    icon: Icons.chat_bubble_outline,                 color: _purple)),
            const Positioned(right: 8, bottom: 4, child: _CornerLabel(label: 'Connect', icon: Icons.people_outline,                      color: _yellow)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Activity Chart Widget
// ─────────────────────────────────────────────────────────────
class _ActivityChart extends StatelessWidget {
  final List<double> data;
  const _ActivityChart({required this.data});

  static const _card    = Color(0xFF141728);
  static const _border  = Color(0xFF252840);
  static const _cardAlt = Color(0xFF1C2033);
  static const _cyan    = Color(0xFF3FD8F5);
  static const _inkSoft = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('ACTIVITY LOAD',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _inkSoft, letterSpacing: 1.5)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _cardAlt, borderRadius: BorderRadius.circular(6)),
            child: const Text('last 60s', style: TextStyle(fontSize: 10, color: _inkSoft)),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 72,
          child: CustomPaint(
            painter: _ChartPainter(data: data, color: _cyan),
            child: const SizedBox.expand(),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Live Feed Section
// ─────────────────────────────────────────────────────────────
class _LiveFeedSection extends StatelessWidget {
  final List<Map<String, dynamic>> feed;
  const _LiveFeedSection({required this.feed});

  static const _card   = Color(0xFF141728);
  static const _border = Color(0xFF252840);
  static const _ink    = Color(0xFFE9EBEE);
  static const _inkSoft= Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Live feed',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
      const SizedBox(height: 12),
      if (feed.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border)),
          child: const Center(child: Text('No recent activity',
              style: TextStyle(color: _inkSoft, fontSize: 13))),
        )
      else
        ...List.generate(feed.length, (i) => _FeedTile(item: feed[i], index: i)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Small Widgets
// ─────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.isActive, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.14) : const Color(0xFF141728),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color.withValues(alpha: 0.5) : const Color(0xFF252840)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: isActive ? color : const Color(0xFF9CA3AF))),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int pct;
  final Color color;
  const _StatPill({required this.label, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF141728),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF252840)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
            const Spacer(),
            Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100.0).clamp(0, 1),
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 3,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
  ]);
}

class _CornerLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _CornerLabel({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color, size: 13),
    Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
  ]);
}

class _FeedTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  const _FeedTile({required this.item, required this.index});

  Color get _typeColor {
    switch (item['type']?.toString()) {
      case 'post':          return const Color(0xFF3FD8F5);
      case 'points':        return const Color(0xFFF59E0B);
      case 'chat':          return const Color(0xFFA855F7);
      case 'connect':       return const Color(0xFFEAB308);
      case 'flagged':
      case 'admin_attempt': return const Color(0xFFEF4444);
      default:              return const Color(0xFF9CA3AF);
    }
  }

  String get _timeAgo {
    final ts = item['created_at']?.toString();
    if (ts == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(ts));
      if (diff.inSeconds < 10)  return 'now';
      if (diff.inSeconds < 60)  return '${diff.inSeconds}s';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m';
      return '${diff.inHours}h';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final name   = item['user_name']?.toString() ?? 'User';
    final action = item['action']?.toString()    ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141728),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF252840)),
      ),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _typeColor, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(text: TextSpan(children: [
            TextSpan(text: name,
                style: const TextStyle(color: Color(0xFFE9EBEE), fontWeight: FontWeight.w700, fontSize: 13)),
            TextSpan(text: '  $action',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ])),
        ),
        const SizedBox(width: 8),
        Text(_timeAgo, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      ]),
    ).animate(delay: Duration(milliseconds: index * 40)).fadeIn(duration: 250.ms);
  }
}

class _IncStat extends StatelessWidget {
  final String value, label;
  const _IncStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1C2033), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _IncActionTile extends StatelessWidget {
  final Map<String, dynamic> action;
  const _IncActionTile({required this.action});

  IconData get _icon {
    switch (action['type']?.toString()) {
      case 'points':        return Icons.account_balance_wallet_outlined;
      case 'admin_attempt': return Icons.admin_panel_settings_outlined;
      case 'profile_view':  return Icons.person_outline;
      case 'connect':       return Icons.people_outline;
      default:              return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionText = action['action']?.toString() ?? '';
    final agoS       = (action['ago_s'] as num?)?.toInt() ?? 0;
    final agoStr     = agoS < 60 ? '${agoS}s ago' : '${agoS ~/ 60}m ago';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1C2033), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icon, size: 15, color: const Color(0xFFEF4444)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(actionText, style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 12, fontWeight: FontWeight.w600)),
          Text(agoStr, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────────────────────

/// Animated network node graph
class _NetPainter extends CustomPainter {
  final double t;
  final bool suspicious;
  const _NetPainter({required this.t, required this.suspicious});

  static const _colors = [
    Color(0xFF3FD8F5), Color(0xFFF59E0B), Color(0xFFA855F7),
    Color(0xFFEAB308), Color(0xFF22C55E), Color(0xFFEF4444),
    Color(0xFF3FD8F5), Color(0xFFF59E0B), Color(0xFFA855F7),
    Color(0xFFEAB308), Color(0xFF22C55E), Color(0xFF3FD8F5),
    Color(0xFFF59E0B), Color(0xFFA855F7), Color(0xFFEAB308),
  ];

  static const _basePos = [
    Offset(0.36, 0.35), Offset(0.56, 0.25), Offset(0.44, 0.55),
    Offset(0.65, 0.44), Offset(0.28, 0.60), Offset(0.70, 0.30),
    Offset(0.50, 0.72), Offset(0.40, 0.44), Offset(0.60, 0.60),
    Offset(0.25, 0.44), Offset(0.75, 0.55), Offset(0.55, 0.40),
    Offset(0.34, 0.72), Offset(0.64, 0.72), Offset(0.50, 0.28),
  ];

  static const _edges = [
    [0,1],[1,2],[2,3],[3,4],[0,4],[5,6],[6,7],[7,8],[1,5],
    [2,6],[3,7],[4,8],[9,10],[10,11],[9,0],[10,2],[11,3],
    [12,13],[13,14],[12,0],[13,5],[14,7],[0,14],[1,9],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Animate node positions with gentle drift
    final positions = List.generate(_basePos.length, (i) {
      final phase = i * 0.42 + t * math.pi * 2;
      return Offset(
        (_basePos[i].dx + math.sin(phase)          * 0.022) * w,
        (_basePos[i].dy + math.cos(phase * 0.73)   * 0.022) * h,
      );
    });

    // Corner anchor positions
    final corners = [
      Offset(w * 0.13, h * 0.20),
      Offset(w * 0.87, h * 0.20),
      Offset(w * 0.13, h * 0.82),
      Offset(w * 0.87, h * 0.82),
    ];
    const cornerColors = [
      Color(0xFF3FD8F5), Color(0xFFF59E0B),
      Color(0xFFA855F7), Color(0xFFEAB308),
    ];

    final edgePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.7;

    // Inner-node edges
    for (final e in _edges) {
      if (e[0] < positions.length && e[1] < positions.length) {
        edgePaint.color = _colors[e[0]].withValues(alpha: 0.22);
        canvas.drawLine(positions[e[0]], positions[e[1]], edgePaint);
      }
    }

    // Corner-to-inner edges
    for (int ci = 0; ci < 4; ci++) {
      for (int ni = ci * 2; ni < math.min(ci * 2 + 4, positions.length); ni++) {
        edgePaint.color = cornerColors[ci].withValues(alpha: 0.13);
        canvas.drawLine(corners[ci], positions[ni], edgePaint);
      }
    }

    // Draw inner nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < positions.length; i++) {
      final c     = _colors[i % _colors.length];
      final pulse = 0.7 + 0.3 * math.sin(i * 0.6 + t * math.pi * 2);
      final r     = 3.8 * pulse;
      nodePaint.color = c.withValues(alpha: 0.12 * pulse);
      canvas.drawCircle(positions[i], r * 2.4, nodePaint);
      nodePaint.color = c.withValues(alpha: 0.82);
      canvas.drawCircle(positions[i], r, nodePaint);
    }

    // Draw corner nodes
    final cornerFill   = Paint()..style = PaintingStyle.fill;
    final cornerBorder = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (int i = 0; i < 4; i++) {
      final c     = cornerColors[i];
      final pulse = 0.92 + 0.08 * math.sin(i * 1.2 + t * math.pi * 2);
      final size2 = 44.0 * pulse;
      final rr    = RRect.fromRectAndRadius(Rect.fromCenter(center: corners[i], width: size2, height: size2), const Radius.circular(12));
      cornerFill.color   = c.withValues(alpha: 0.13);
      cornerBorder.color = c.withValues(alpha: 0.4);
      canvas.drawRRect(rr, cornerFill);
      canvas.drawRRect(rr, cornerBorder);
      nodePaint.color = c;
      canvas.drawCircle(corners[i], 4.5, nodePaint);
    }

    // Red alert dot on Feed corner when suspicious
    if (suspicious) {
      nodePaint.color = const Color(0xFFEF4444);
      canvas.drawCircle(Offset(corners[0].dx + 14, corners[0].dy - 14), 5.5, nodePaint);
    }
  }

  @override
  bool shouldRepaint(_NetPainter old) => old.t != t || old.suspicious != suspicious;
}

/// Rolling activity load line chart
class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  const _ChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final w = size.width, h = size.height;
    final stepX = w / (data.length - 1);

    final linePath = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = h - (data[i] * h * 0.85) - 4;
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        final px  = (i - 1) * stepX;
        final py  = h - (data[i - 1] * h * 0.85) - 4;
        final cpx = (px + x) / 2;
        linePath.cubicTo(cpx, py, cpx, y, x, y);
        fillPath.cubicTo(cpx, py, cpx, y, x, y);
      }
    }
    fillPath.lineTo(w, h);
    fillPath.close();

    // Fill
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill);

    // Line
    canvas.drawPath(linePath, Paint()
      ..color = color..strokeWidth = 2.0
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Live dot
    final lx = (data.length - 1) * stepX;
    final ly = h - (data.last * h * 0.85) - 4;
    canvas.drawCircle(Offset(lx, ly), 6.0, Paint()..color = color.withValues(alpha: 0.28));
    canvas.drawCircle(Offset(lx, ly), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.data != data;
}

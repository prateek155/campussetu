import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'faculty_api.dart';
import 'faculty_portal_shell.dart';

class FacultyDashboardScreen extends StatefulWidget {
  const FacultyDashboardScreen({super.key});
  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  List<Map<String, dynamic>> _assessments = const [];
  Map<String, dynamic> _faculty = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        FacultyApi.list('/quiz/my'),
        FacultyApi.get('/quiz/faculty/profile'),
      ]);
      if (!mounted) return;
      setState(() {
        _assessments = results[0] as List<Map<String, dynamic>>;
        _faculty = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load your dashboard. Check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _assessments.where((item) => item['mode'] != 'paper' && (item['status'] == 'waiting' || item['status'] == 'live')).length;
    final paperTests = _assessments.where((item) => item['mode'] == 'paper').length;
    final attempts = _assessments.fold<int>(0, (sum, item) => sum + _asInt(item['participant_count']) + _asInt(item['submission_count']));
    final active = _assessments.where((item) => item['status'] == 'live' || item['status'] == 'waiting').length;
    final name = (_faculty['name'] ?? '').toString().trim();
    final firstName = name.isEmpty ? 'Faculty' : name.split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: facultyBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: facultyAccent))
          : _error != null
              ? _ErrorPanel(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: facultyAccent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(26, 25, 26, 36),
                    children: [
                      Text('Namaste, $firstName', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.6)),
                      const SizedBox(height: 6),
                      Text('Your classes and assessments at a glance.', style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14)),
                      const SizedBox(height: 22),
                      LayoutBuilder(builder: (context, constraints) {
                        final count = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
                        final cardWidth = (constraints.maxWidth - (count - 1) * 14) / count;
                        return Wrap(spacing: 14, runSpacing: 14, children: [
                          _MetricCard(width: cardWidth, icon: Icons.bolt_rounded, color: facultyAccent, value: '$live', label: 'Active live quizzes', hint: 'Waiting or in progress'),
                          _MetricCard(width: cardWidth, icon: Icons.fact_check_outlined, color: const Color(0xFF34A783), value: '$paperTests', label: 'Paper tests', hint: 'Drafts and published'),
                          _MetricCard(width: cardWidth, icon: Icons.assignment_turned_in_outlined, color: const Color(0xFFDC5571), value: '$attempts', label: 'Student attempts', hint: 'Across your assessments'),
                          _MetricCard(width: cardWidth, icon: Icons.quiz_outlined, color: const Color(0xFF7F91B4), value: '${_assessments.length}', label: 'All assessments', hint: '$active currently active'),
                        ]);
                      }),
                      const SizedBox(height: 18),
                      _Panel(
                        title: 'Quick actions',
                        child: Wrap(spacing: 10, runSpacing: 10, children: [
                          _ActionButton(icon: Icons.add_rounded, label: 'Create live quiz', onTap: () => context.go('/faculty/quizzes/create')),
                          _ActionButton(icon: Icons.fact_check_outlined, label: 'Create paper test', onTap: () => context.go('/faculty/tests/create')),
                          _ActionButton(icon: Icons.swap_horiz_rounded, label: 'Convert a file', onTap: () => context.go('/faculty/tools'), outlined: true),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      _Panel(
                        title: 'Recent assessments',
                        trailing: TextButton(onPressed: () => context.go('/faculty/quizzes'), child: const Text('View all')),
                        child: _assessments.isEmpty
                            ? const _EmptyState(message: 'Your assessments will appear here after you create one.')
                            : Column(children: [
                                for (final item in _assessments.take(6))
                                  _AssessmentRow(item: item, onTap: () {
                                    final id = item['id'];
                                    if (id == null) return;
                                    if (item['mode'] == 'paper') {
                                      context.go('/faculty/tests');
                                      return;
                                    }
                                    context.go('/faculty/quizzes/$id/dashboard');
                                  }),
                              ]),
                      ),
                    ],
                  ),
                ),
    );
  }
}

int _asInt(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

class _MetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String hint;
  const _MetricCard({required this.width, required this.icon, required this.color, required this.value, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 142,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: facultySurface, borderRadius: BorderRadius.circular(17), border: Border.all(color: facultyBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: Color(0xFFD6DFEF), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(hint, style: const TextStyle(color: Color(0xFF8FA0BB), fontSize: 11)),
        ]),
      );
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Panel({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: facultySurface, borderRadius: BorderRadius.circular(17), border: Border.all(color: facultyBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)), const Spacer(), if (trailing != null) trailing!]),
          const SizedBox(height: 13),
          child,
        ]),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.outlined = false});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: outlined ? const Color(0xFFD5DFF0) : Colors.white,
          backgroundColor: outlined ? Colors.transparent : facultyAccent,
          side: BorderSide(color: outlined ? facultyBorder : facultyAccent),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      );
}

class _AssessmentRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _AssessmentRow({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'draft').toString();
    final isPaper = item['mode'] == 'paper';
    final created = DateTime.tryParse((item['created_at'] ?? '').toString());
    final color = status == 'live' ? const Color(0xFF36B990) : status == 'waiting' ? facultyAccent : const Color(0xFF91A1BA);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: facultyBorder))),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)), child: Icon(isPaper ? Icons.fact_check_outlined : Icons.bolt_rounded, color: color, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((item['title'] ?? 'Untitled').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${isPaper ? 'Paper test' : 'Live quiz'} · ${item['question_count'] ?? 0} questions · ${created == null ? 'Recently created' : DateFormat('d MMM, h:mm a').format(created.toLocal())}', style: const TextStyle(color: Color(0xFF91A1BA), fontSize: 11)),
          ])),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(message, style: const TextStyle(color: Color(0xFF91A1BA), fontSize: 13)));
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(26), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, color: Color(0xFF94A3B8), size: 38),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFCBD5E1))),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ])));
}

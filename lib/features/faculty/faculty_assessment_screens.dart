import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'faculty_api.dart';
import 'faculty_portal_shell.dart';

class FacultyTestsScreen extends StatefulWidget {
  const FacultyTestsScreen({super.key});
  @override
  State<FacultyTestsScreen> createState() => _FacultyTestsScreenState();
}

class _FacultyTestsScreenState extends State<FacultyTestsScreen> {
  List<Map<String, dynamic>> _tests = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await FacultyApi.list('/quiz/my');
      if (!mounted) return;
      setState(() { _tests = all.where((item) => item['mode'] == 'paper').toList(); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load paper tests.'; });
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> test, {required bool publish}) async {
    final id = test['id'];
    if (id == null) return;
    try {
      if (publish) {
        await FacultyApi.post('/quiz/$id/publish');
      } else {
        await FacultyApi.post('/quiz/$id/end');
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      final data = error is DioException ? error.response?.data : null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data is Map ? (data['error'] ?? 'Could not update test').toString() : 'Could not update test')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: facultyBg,
        appBar: AppBar(title: const Text('Paper tests'), actions: [
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
          Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton.icon(onPressed: () => context.go('/faculty/tests/create'), icon: const Icon(Icons.add, size: 18), label: const Text('Create test'))),
        ]),
        body: _loading ? const Center(child: CircularProgressIndicator(color: facultyAccent))
            : _error != null ? _PortalError(message: _error!, onRetry: _load)
            : _tests.isEmpty ? const _PortalEmpty(message: 'You have not created any paper tests yet.')
            : RefreshIndicator(color: facultyAccent, onRefresh: _load, child: ListView(padding: const EdgeInsets.all(22), children: [
                Text('Form-style assessments', style: TextStyle(color: Colors.blueGrey.shade200)),
                const SizedBox(height: 14),
                for (final test in _tests) _PortalAssessmentCard(
                  item: test,
                  onEdit: test['status'] == 'draft' ? () => context.go('/faculty/tests/${test['id']}/edit') : null,
                  onPublish: test['status'] == 'draft' ? () => _changeStatus(test, publish: true) : null,
                  onClose: test['status'] == 'live' ? () => _changeStatus(test, publish: false) : null,
                  onResults: test['status'] == 'ended' || test['status'] == 'live' ? () => context.go('/faculty/quizzes/${test['id']}/results') : null,
                ),
              ])),
      );
}

class FacultyAnalyticsScreen extends StatefulWidget {
  const FacultyAnalyticsScreen({super.key});
  @override
  State<FacultyAnalyticsScreen> createState() => _FacultyAnalyticsScreenState();
}

class _FacultyAnalyticsScreenState extends State<FacultyAnalyticsScreen> {
  List<Map<String, dynamic>> _assessments = const [];
  final Map<String, Map<String, dynamic>> _results = {};
  bool _loading = true;
  String? _error;
  String _mode = 'live';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final responses = await Future.wait([
        FacultyApi.list('/quiz/my'),
        FacultyApi.get('/quiz/analytics'),
      ]);
      final assessments = responses[0] as List<Map<String, dynamic>>;
      final summary = responses[1] as Map<String, dynamic>;
      final summaryRows = (summary['assessments'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item));
      if (!mounted) return;
      setState(() {
        _assessments = assessments;
        _results
          ..clear()
          ..addEntries(summaryRows.map((item) => MapEntry(item['quiz_id'].toString(), item)));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load assessment analytics.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _assessments.where((item) => item['mode'] == (_mode == 'paper' ? 'paper' : 'live')).toList();
    var participants = 0;
    var scoreSum = 0.0;
    var scoreCount = 0;
    for (final test in visible) {
      final summary = _results[test['id']?.toString()];
      final count = _int(summary?['participant_count']);
      participants += count;
      final averageScore = num.tryParse((summary?['average_score'] ?? '').toString());
      if (averageScore != null && count > 0) { scoreSum += (averageScore * count).toDouble(); scoreCount += count; }
    }
    final average = scoreCount == 0 ? '—' : (scoreSum / scoreCount).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: facultyBg,
      appBar: AppBar(title: const Text('Results & analytics'), actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: facultyAccent))
          : _error != null ? _PortalError(message: _error!, onRetry: _load)
          : ListView(padding: const EdgeInsets.all(22), children: [
              const Text('Performance by assessment type', style: TextStyle(color: Color(0xFFDAE3F0), fontSize: 14)),
              const SizedBox(height: 15),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'live', label: Text('Kahoot-style quiz'), icon: Icon(Icons.bolt_rounded)),
                  ButtonSegment(value: 'paper', label: Text('Paper test'), icon: Icon(Icons.fact_check_outlined)),
                ],
                selected: {_mode},
                onSelectionChanged: (value) => setState(() => _mode = value.first),
              ),
              const SizedBox(height: 15),
              LayoutBuilder(builder: (context, box) {
                final columns = box.maxWidth >= 750 ? 3 : 1;
                final width = (box.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  _AnalyticsMetric(width: width, label: 'Assessments', value: '${visible.length}', icon: Icons.assignment_outlined),
                  _AnalyticsMetric(width: width, label: 'Student submissions', value: '$participants', icon: Icons.people_outline),
                  _AnalyticsMetric(width: width, label: 'Average score', value: average, icon: Icons.trending_up_rounded),
                ]);
              }),
              const SizedBox(height: 18),
              if (visible.isEmpty)
                const _PortalEmpty(message: 'No assessments of this type yet.')
              else
                for (final item in visible) _PortalAssessmentCard(
                  item: item,
                  participantCount: _int(_results[item['id']?.toString()]?['participant_count']),
                  onResults: () => context.go('/faculty/quizzes/${item['id']}/results'),
                ),
            ]),
    );
  }
}

class FacultyQuestionBankScreen extends StatefulWidget {
  const FacultyQuestionBankScreen({super.key});
  @override
  State<FacultyQuestionBankScreen> createState() => _FacultyQuestionBankScreenState();
}

class _FacultyQuestionBankScreenState extends State<FacultyQuestionBankScreen> {
  List<Map<String, dynamic>> _questions = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await FacultyApi.list('/quiz/question-bank');
      if (mounted) setState(() { _questions = result; _loading = false; });
    } catch (_) { if (mounted) setState(() { _loading = false; _error = 'Could not load your question bank.'; }); }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = _questions.where((item) => item['question_text'].toString().toLowerCase().contains(q) || item['quiz_title'].toString().toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: facultyBg,
      appBar: AppBar(title: const Text('Question bank'), actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: facultyAccent))
          : _error != null ? _PortalError(message: _error!, onRetry: _load)
          : ListView(padding: const EdgeInsets.all(22), children: [
              TextField(onChanged: (value) => setState(() => _query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search saved questions')),
              const SizedBox(height: 14),
              Text('${visible.length} question${visible.length == 1 ? '' : 's'} from your quizzes', style: const TextStyle(color: Color(0xFF91A1BA), fontSize: 12)),
              const SizedBox(height: 12),
              if (visible.isEmpty) const _PortalEmpty(message: 'No saved questions match your search.')
              else for (final question in visible) _QuestionBankCard(question: question),
            ]),
    );
  }
}

class _PortalAssessmentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int? participantCount;
  final VoidCallback? onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onClose;
  final VoidCallback? onResults;
  const _PortalAssessmentCard({required this.item, this.participantCount, this.onEdit, this.onPublish, this.onClose, this.onResults});

  @override
  Widget build(BuildContext context) {
    final paper = item['mode'] == 'paper';
    final status = (item['status'] ?? 'draft').toString();
    final count = participantCount ?? _int(item[paper ? 'submission_count' : 'participant_count']);
    final color = status == 'live' ? const Color(0xFF37B991) : status == 'waiting' ? facultyAccent : const Color(0xFF92A2BA);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
      decoration: BoxDecoration(color: facultySurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: facultyBorder)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)), child: Icon(paper ? Icons.fact_check_outlined : Icons.bolt_rounded, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((item['title'] ?? 'Untitled assessment').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${paper ? 'Paper test' : 'Live quiz'} · ${item['question_count'] ?? 0} questions · $count ${paper ? 'submissions' : 'joined'}', style: const TextStyle(color: Color(0xFF91A1BA), fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(15)), child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        PopupMenuButton<String>(
          tooltip: 'Assessment actions',
          onSelected: (action) {
            if (action == 'edit') onEdit?.call();
            if (action == 'publish') onPublish?.call();
            if (action == 'close') onClose?.call();
            if (action == 'results') onResults?.call();
            if (action == 'open') context.go('/faculty/quizzes/${item['id']}/dashboard');
          },
          itemBuilder: (context) => [
            if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit draft')),
            if (onPublish != null) const PopupMenuItem(value: 'publish', child: Text('Publish to students')),
            if (onClose != null) const PopupMenuItem(value: 'close', child: Text('Close test')),
            if (onResults != null) const PopupMenuItem(value: 'results', child: Text('View results')),
            if (!paper) const PopupMenuItem(value: 'open', child: Text('Open live dashboard')),
          ],
        ),
      ]),
    );
  }
}

class _QuestionBankCard extends StatelessWidget {
  final Map<String, dynamic> question;
  const _QuestionBankCard({required this.question});
  @override
  Widget build(BuildContext context) {
    final options = question['options'] as List? ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: facultySurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: facultyBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text((question['quiz_title'] ?? 'Quiz').toString(), style: const TextStyle(color: Color(0xFF92A2BA), fontSize: 11))), IconButton(tooltip: 'Copy question text', onPressed: () { Clipboard.setData(ClipboardData(text: question['question_text'].toString())); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Question copied'))); }, icon: const Icon(Icons.copy_rounded, size: 17, color: Color(0xFF92A2BA)))]),
        Text((question['question_text'] ?? '').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 9),
        for (var i = 0; i < options.length; i++) if (options[i] is Map) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${String.fromCharCode(65 + i)}. ${options[i]['text'] ?? ''}${options[i]['isCorrect'] == true ? '  ✓' : ''}', style: TextStyle(color: options[i]['isCorrect'] == true ? const Color(0xFF43C7A1) : const Color(0xFFC4D0E2), fontSize: 12))),
      ]),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  const _AnalyticsMetric({required this.width, required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(width: width, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: facultySurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: facultyBorder)), child: Row(children: [Icon(icon, size: 20, color: facultyAccent), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22)), Text(label, style: const TextStyle(color: Color(0xFF92A2BA), fontSize: 11))])]));
}

class _PortalError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _PortalError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, style: const TextStyle(color: Color(0xFFD9E1EE))), const SizedBox(height: 10), FilledButton(onPressed: onRetry, child: const Text('Retry'))])));
}

class _PortalEmpty extends StatelessWidget {
  final String message;
  const _PortalEmpty({required this.message});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: facultySurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: facultyBorder)), child: Text(message, style: const TextStyle(color: Color(0xFF92A2BA), fontSize: 13)));
}

int _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

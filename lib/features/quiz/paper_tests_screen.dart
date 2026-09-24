import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

class PaperTestsScreen extends StatefulWidget {
  const PaperTestsScreen({super.key});
  @override
  State<PaperTestsScreen> createState() => _PaperTestsScreenState();
}

class _PaperTestsScreenState extends State<PaperTestsScreen> {
  late Future<List<dynamic>> _tests;
  @override
  void initState() { super.initState(); _tests = ApiService().getPaperTests(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Paper tests'),
          actions: [TextButton.icon(onPressed: () => context.push('/quiz'), icon: const Icon(Icons.bolt_rounded), label: const Text('Live quizzes')), const SizedBox(width: 8)],
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _tests,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _RetryPanel(message: 'Could not load tests.', onRetry: () => setState(() => _tests = ApiService().getPaperTests()));
            final tests = snapshot.data ?? const [];
            if (tests.isEmpty) return const _EmptyPanel(message: 'There are no published paper tests right now.');
            return RefreshIndicator(
              onRefresh: () async => setState(() => _tests = ApiService().getPaperTests()),
              child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 30), children: [
                Text('Tests shared by your faculty', style: AppTypography.soraHeading2()),
                const SizedBox(height: 5),
                Text('Your answers are graded by the server after you submit.', style: AppTypography.interBodySmall()),
                const SizedBox(height: 16),
                for (final raw in tests) if (raw is Map) _TestCard(test: Map<String, dynamic>.from(raw)),
              ]),
            );
          },
        ),
      );
}

class _TestCard extends StatelessWidget {
  final Map<String, dynamic> test;
  const _TestCard({required this.test});
  @override
  Widget build(BuildContext context) {
    final submitted = test['submitted'] == true;
    final title = (test['title'] ?? 'Paper test').toString();
    final id = (test['id'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        padding: const EdgeInsets.all(16),
        onTap: submitted || id.isEmpty ? null : () => context.push('/tests/$id'),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.cyanDeep.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.fact_check_outlined, color: AppColors.cyanDeep)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.interButton(size: 15)),
            const SizedBox(height: 4),
            Text('By ${test['faculty_name'] ?? 'Faculty'} · ${test['question_count'] ?? 0} questions · ${test['duration_minutes'] ?? 60} min', style: AppTypography.interCaption()),
          ])),
          const SizedBox(width: 8),
          submitted ? const Chip(label: Text('Submitted')) : Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.inkSoft),
        ]),
      ),
    );
  }
}

class PaperTestAttemptScreen extends StatefulWidget {
  final String testId;
  const PaperTestAttemptScreen({super.key, required this.testId});
  @override
  State<PaperTestAttemptScreen> createState() => _PaperTestAttemptScreenState();
}

class _PaperTestAttemptScreenState extends State<PaperTestAttemptScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _test;
  List<Map<String, dynamic>> _questions = [];
  List<int> _questionOrder = [];
  final Map<String, List<int>> _optionOrder = {};
  final Map<String, int> _answers = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _result;
  int _current = 0;
  int _secondsLeft = 0;
  int _focusWarnings = 0;
  bool _lastInactive = false;
  bool _contextMenuDisabled = false;
  int _dismissedWarningCount = 0;
  Timer? _timer;

  Map<String, dynamic> get _settings => Map<String, dynamic>.from((_test?['settings'] as Map?) ?? const {});
  bool get _copyAllowed => _settings['allow_copy'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (kIsWeb && _contextMenuDisabled) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inactive = state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (!inactive) { _lastInactive = false; return; }
    if (_settings['lock_tab_switch'] == true && !_lastInactive && mounted && _result == null) {
      _lastInactive = true;
      setState(() => _focusWarnings++);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leaving the test may be recorded by your faculty.')));
      unawaited(_reportFocusLoss());
    }
  }

  Future<void> _reportFocusLoss() async {
    try {
      final count = await ApiService().recordPaperTestFlag(widget.testId);
      if (mounted) setState(() => _focusWarnings = count);
    } catch (_) {
      // Keep the local warning even if the network is temporarily unavailable.
    }
  }

  Future<void> _saveAnswer(String questionId, int selectedIndex) async {
    try {
      await ApiService().savePaperTestAnswer(widget.testId, questionId, selectedIndex);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Answer could not be synced. Keep this page open and submit when ready.')));
      }
    }
  }

  Future<void> _load() async {
    try {
      final test = await ApiService().getPaperTest(widget.testId);
      final questions = (test['questions'] as List? ?? []).whereType<Map>().map((q) => Map<String, dynamic>.from(q)).toList();
      final restoredAnswers = <String, int>{};
      final savedAnswers = test['saved_answers'];
      if (savedAnswers is Map) {
        for (final question in questions) {
          final id = question['id'].toString();
          final selected = int.tryParse(savedAnswers[id]?.toString() ?? '');
          final optionCount = (question['options'] as List? ?? []).length;
          if (selected != null && selected >= 0 && selected < optionCount) restoredAnswers[id] = selected;
        }
      }
      final order = List<int>.generate(questions.length, (index) => index);
      final random = Random();
      if (test['settings'] is Map && test['settings']['shuffle_questions'] == true) order.shuffle(random);
      final optionOrder = <String, List<int>>{};
      if (test['settings'] is Map && test['settings']['shuffle_options'] == true) {
        for (final question in questions) {
          final id = question['id'].toString();
          optionOrder[id] = List<int>.generate((question['options'] as List? ?? []).length, (index) => index)..shuffle(random);
        }
      }
      final startedAt = DateTime.tryParse((test['started_at'] ?? '').toString())?.toLocal() ?? DateTime.now();
      final duration = int.tryParse((test['duration_minutes'] ?? 60).toString()) ?? 60;
      final remaining = duration * 60 - DateTime.now().difference(startedAt).inSeconds;
      if (!mounted) return;
      if (kIsWeb && test['settings'] is Map && test['settings']['allow_copy'] != true) {
        BrowserContextMenu.disableContextMenu();
        _contextMenuDisabled = true;
      }
      setState(() {
        _test = test;
        _questions = questions;
        _questionOrder = order;
        _optionOrder.addAll(optionOrder);
        _answers.addAll(restoredAnswers);
        _focusWarnings = int.tryParse((test['violation_count'] ?? 0).toString()) ?? 0;
        _secondsLeft = remaining.clamp(0, duration * 60).toInt();
        _loading = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _result != null || _submitting) return;
        if (_secondsLeft <= 1) {
          setState(() => _secondsLeft = 0);
          _submit();
        } else {
          setState(() => _secondsLeft--);
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (error is DioException && error.response?.statusCode == 409 && error.response?.data is Map) {
        final data = Map<String, dynamic>.from(error.response!.data as Map);
        if (data['score'] != null) {
          setState(() {
            _loading = false;
            _result = 'Already submitted. Your score: ${data['score']}';
          });
          return;
        }
      }
      setState(() { _loading = false; _error = _errorText(error); });
    }
  }

  Future<void> _submit() async {
    if (_submitting || _result != null) return;
    setState(() => _submitting = true);
    _timer?.cancel();
    try {
      final response = await ApiService().submitPaperTest(widget.testId, _answers);
      if (!mounted) return;
      setState(() => _result = 'Submitted. Your score: ${response['score'] ?? 0} / ${_questions.fold<int>(0, (sum, q) => sum + ((q['marks'] as num?)?.toInt() ?? 1))}');
    } catch (error) {
      if (!mounted) return;
      final message = _errorText(error);
      if (message.contains('already submitted')) {
        final responseData = error is DioException ? error.response?.data : null;
        final score = responseData is Map ? responseData['score'] : null;
        setState(() => _result = score == null ? 'This test was already submitted.' : 'Already submitted. Your score: $score');
      } else if (message.toLowerCase().contains('time has expired')) {
        setState(() => _result = 'Time expired. The server did not accept a late submission.');
      } else {
        setState(() { _submitting = false; _error = message; });
      }
    } finally {
      if (mounted && _result != null) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_result != null) return Scaffold(appBar: AppBar(title: const Text('Test submitted')), body: _EmptyPanel(message: _result!, icon: Icons.check_circle_outline));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Paper test')), body: _RetryPanel(message: _error!, onRetry: () { setState(() { _loading = true; _error = null; }); _load(); }));
    if (_questions.isEmpty) return const Scaffold(body: _EmptyPanel(message: 'This test has no questions.'));

    final orderIndex = _questionOrder[_current];
    final question = _questions[orderIndex];
    final qid = question['id'].toString();
    final options = question['options'] as List? ?? [];
    final displayOrder = _optionOrder[qid] ?? List<int>.generate(options.length, (index) => index);
    final lockCopy = !_copyAllowed;
    final student = FirebaseAuth.instance.currentUser;
    final uid = student?.uid ?? '';
    final shortId = uid.length > 5 ? uid.substring(uid.length - 5) : uid;
    final watermark = '${student?.displayName ?? student?.email ?? 'CampusSetu student'} · ID $shortId';

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (!lockCopy || event is! KeyDownEvent) return KeyEventResult.ignored;
        final modifier = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
        final blocked = {LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyX, LogicalKeyboardKey.keyV}.contains(event.logicalKey);
        return modifier && blocked ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(title: Text((_test?['title'] ?? 'Paper test').toString()), actions: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Center(child: Text(_formatTime(_secondsLeft), style: AppTypography.monoCode(size: 16, color: _secondsLeft <= 60 ? AppColors.error : AppColors.ink)))),
        ]),
        body: Column(children: [
          if (_focusWarnings > _dismissedWarningCount) MaterialBanner(
            content: Text('Tab switch warning: $_focusWarnings'),
            leading: const Icon(Icons.warning_amber_rounded),
            actions: [TextButton(onPressed: () => setState(() => _dismissedWarningCount = _focusWarnings), child: const Text('Dismiss'))],
          ),
          Expanded(child: ListView(padding: const EdgeInsets.all(18), children: [
            NeuCard(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text('Question ${_current + 1} of ${_questions.length}', style: AppTypography.interLabel()), const Spacer(), Text('${question['marks'] ?? 1} mark${question['marks'] == 1 ? '' : 's'}', style: AppTypography.interCaption())]),
              const SizedBox(height: 12),
              Text((question['question_text'] ?? '').toString(), style: AppTypography.interBody(size: 17, weight: FontWeight.w600)),
              const SizedBox(height: 14),
              RadioGroup<int>(
                groupValue: _answers[qid],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _answers[qid] = value);
                  unawaited(_saveAnswer(qid, value));
                },
                child: Column(
                  children: [
                    for (final optionIndex in displayOrder)
                      if (optionIndex < options.length)
                        RadioListTile<int>(
                          value: optionIndex,
                          title: Text((options[optionIndex] as Map)['text']?.toString() ?? ''),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                          dense: true,
                        ),
                  ],
                ),
              ),
            ])),
            if (_settings['screenshot_deterrent'] == true) ...[
              const SizedBox(height: 14),
              Center(child: Opacity(opacity: 0.55, child: Text(watermark, textAlign: TextAlign.center, style: AppTypography.interCaption()))),
            ],
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton.icon(onPressed: _current > 0 ? () => setState(() => _current--) : null, icon: const Icon(Icons.arrow_back), label: const Text('Previous')),
              const Spacer(),
              if (_current + 1 < _questions.length)
                FilledButton.icon(onPressed: () => setState(() => _current++), icon: const Icon(Icons.arrow_forward), label: const Text('Next'))
              else
                FilledButton.icon(onPressed: _submitting ? null : _confirmSubmit, icon: const Icon(Icons.check), label: Text(_submitting ? 'Submitting…' : 'Submit test')),
            ]),
          ])),
        ]),
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Submit test?'),
      content: Text('${_answers.length} of ${_questions.length} questions answered. Unanswered questions will receive zero marks.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Review')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit'))],
    ));
    if (confirmed == true) _submit();
  }
}

class _EmptyPanel extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyPanel({required this.message, this.icon = Icons.fact_check_outlined});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: NeuCard(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 42, color: AppColors.cyanDeep), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: AppTypography.interBody())]))));
}

class _RetryPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RetryPanel({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center, style: AppTypography.interBody(color: AppColors.error)), const SizedBox(height: 12), FilledButton(onPressed: onRetry, child: const Text('Retry'))])));
}

String _formatTime(int seconds) => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
String _errorText(Object error) {
  try {
    final data = (error as dynamic).response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
  } catch (_) {}
  final message = error.toString();
  return message.contains('409') ? 'You have already submitted this test, or it is no longer open.' : 'Could not load or submit the test. Try again.';
}

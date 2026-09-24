import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'faculty_api.dart';
import 'faculty_portal_shell.dart';

class PaperTestBuilderScreen extends StatefulWidget {
  final String? quizId;
  const PaperTestBuilderScreen({super.key, this.quizId});
  @override
  State<PaperTestBuilderScreen> createState() => _PaperTestBuilderScreenState();
}

class _PaperTestBuilderScreenState extends State<PaperTestBuilderScreen> {
  final _title = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _settings = <String, bool>{
    'shuffle_questions': true,
    'shuffle_options': true,
    'allow_copy': false,
    'screenshot_deterrent': false,
    'lock_tab_switch': true,
  };
  final List<_PaperQuestion> _questions = [];
  bool _saving = false;
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _questions.add(_PaperQuestion());
    if (widget.quizId != null) _loadDraft();
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    for (final question in _questions) { question.dispose(); }
    super.dispose();
  }

  Future<void> _loadDraft() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final data = await FacultyApi.get('/quiz/faculty/${widget.quizId}');
      final loaded = (data['questions'] as List? ?? []).whereType<Map>().map((raw) {
        final question = _PaperQuestion();
        question.text.text = (raw['question_text'] ?? '').toString();
        final options = raw['options'] as List? ?? [];
        for (var i = 0; i < question.options.length && i < options.length; i++) {
          final option = options[i];
          question.options[i].text = (option is Map ? option['text'] : '').toString();
          if (option is Map && option['isCorrect'] == true) question.correctIndex = i;
        }
        return question;
      }).toList();
      if (!mounted) return;
      setState(() {
        _title.text = (data['title'] ?? '').toString();
        _duration.text = (data['duration_minutes'] ?? 60).toString();
        final savedSettings = data['settings'];
        if (savedSettings is Map) {
          for (final key in _settings.keys) { _settings[key] = savedSettings[key] == true; }
        }
        for (final question in _questions) { question.dispose(); }
        _questions
          ..clear()
          ..addAll(loaded.isEmpty ? [_PaperQuestion()] : loaded);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _loadError = _errorMessage(error); });
    }
  }

  Future<void> _save({required bool publish}) async {
    final title = _title.text.trim();
    final duration = int.tryParse(_duration.text.trim());
    if (title.isEmpty || title.length > 160) {
      _message('Enter a test title (up to 160 characters).');
      return;
    }
    if (duration == null || duration < 1 || duration > 600) {
      _message('Duration must be between 1 and 600 minutes.');
      return;
    }
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.text.text.trim().isEmpty || q.options.any((option) => option.text.trim().isEmpty) || q.correctIndex < 0) {
        _message('Question ${i + 1} needs text, four options, and a correct answer.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'title': title,
        'mode': 'paper',
        'duration_minutes': duration,
        'settings': _settings,
        'questions': _questions.map((q) => {
          'question_text': q.text.text.trim(),
          'options': [for (var i = 0; i < q.options.length; i++) {'text': q.options[i].text.trim(), 'isCorrect': i == q.correctIndex}],
        }).toList(),
      };
      final saved = widget.quizId == null
          ? await FacultyApi.post('/quiz', data: payload)
          : await FacultyApi.put('/quiz/${widget.quizId}', data: payload);
      final id = (saved['id'] ?? widget.quizId).toString();
      if (publish) await FacultyApi.post('/quiz/$id/publish');
      if (!mounted) return;
      _message(publish ? 'Test published for your students.' : 'Draft saved. You can edit it from Paper Tests.');
      context.go('/faculty/tests');
    } catch (error) {
      if (mounted) _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: facultyBg, body: Center(child: CircularProgressIndicator(color: facultyAccent)));
    if (_loadError != null) return Scaffold(backgroundColor: facultyBg, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_loadError!, style: const TextStyle(color: Colors.white)), const SizedBox(height: 12), FilledButton(onPressed: _loadDraft, child: const Text('Retry'))]))));

    return Scaffold(
      backgroundColor: facultyBg,
      appBar: AppBar(
        title: Text(widget.quizId == null ? 'Create paper test' : 'Edit paper test'),
        leading: IconButton(onPressed: () => context.go('/faculty/tests'), icon: const Icon(Icons.arrow_back)),
        actions: [
          TextButton(onPressed: _saving ? null : () => _save(publish: false), child: const Text('Save draft')),
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(right: 12), child: FilledButton(onPressed: _saving ? null : () => _save(publish: true), child: _saving ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Publish test'))),
        ],
      ),
      body: LayoutBuilder(builder: (context, box) {
        final editor = _editor();
        final preview = _preview();
        if (box.maxWidth >= 1120) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 11, child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: editor)),
            Expanded(flex: 9, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(8, 22, 22, 22), child: preview)),
          ]);
        }
        return ListView(padding: const EdgeInsets.all(18), children: [editor, const SizedBox(height: 16), preview]);
      }),
    );
  }

  Widget _editor() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Panel(title: 'Test details', child: Column(children: [
          TextField(controller: _title, maxLength: 160, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Unit 3 — Data Structures Test', counterText: '')),
          const SizedBox(height: 12),
          TextField(controller: _duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (minutes)', suffixText: 'min')),
        ])),
        const SizedBox(height: 14),
        _Panel(title: 'Shuffle settings', child: Column(children: [
          _SettingRow(title: 'Shuffle questions', subtitle: 'Students receive a different question order', value: _settings['shuffle_questions']!, onChanged: (v) => setState(() => _settings['shuffle_questions'] = v)),
          _SettingRow(title: 'Shuffle answer options', subtitle: 'Option order changes per student', value: _settings['shuffle_options']!, onChanged: (v) => setState(() => _settings['shuffle_options'] = v)),
        ])),
        const SizedBox(height: 14),
        _Panel(title: 'Anti-leak controls', child: Column(children: [
          _SettingRow(title: 'Allow copy and paste', subtitle: 'When off, the test page blocks common copy/paste actions', value: _settings['allow_copy']!, onChanged: (v) => setState(() => _settings['allow_copy'] = v)),
          _SettingRow(title: 'Screenshot deterrent', subtitle: 'Show a traceable student watermark; browsers cannot reliably block screenshots', value: _settings['screenshot_deterrent']!, onChanged: (v) => setState(() => _settings['screenshot_deterrent'] = v)),
          _SettingRow(title: 'Flag leaving the test tab', subtitle: 'Record a warning when the test loses focus', value: _settings['lock_tab_switch']!, onChanged: (v) => setState(() => _settings['lock_tab_switch'] = v)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF3B2D17), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF8A682A))), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: facultyAccent, size: 18), SizedBox(width: 9), Expanded(child: Text('Browser controls are deterrents. A separate camera or modified browser can bypass them, so use the watermark for traceability.', style: TextStyle(color: Color(0xFFF0C47B), fontSize: 11, height: 1.45)))])),
        ])),
        const SizedBox(height: 14),
        _Panel(title: 'Questions (${_questions.length})', child: Column(children: [
          for (var i = 0; i < _questions.length; i++) _QuestionEditor(
            key: ObjectKey(_questions[i]),
            index: i,
            question: _questions[i],
            canDelete: _questions.length > 1,
            onDelete: () => setState(() { final removed = _questions.removeAt(i); removed.dispose(); }),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _questions.length >= 100 ? null : () => setState(() => _questions.add(_PaperQuestion())), icon: const Icon(Icons.add), label: const Text('Add question')),
        ])),
      ]);

  Widget _preview() {
    final question = _questions.isEmpty ? null : _questions.first;
    return _Panel(title: 'Student preview', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 7, runSpacing: 7, children: [
        _Badge(text: _settings['allow_copy']! ? 'Copy enabled' : 'Copy disabled', color: _settings['allow_copy']! ? const Color(0xFF34A783) : const Color(0xFF718096)),
        _Badge(text: _settings['screenshot_deterrent']! ? 'Watermarked' : 'No watermark', color: facultyAccent),
        _Badge(text: '${_duration.text.isEmpty ? '60' : _duration.text} min', color: const Color(0xFF6685BE)),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF101A30), borderRadius: BorderRadius.circular(14), border: Border.all(color: facultyBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title.text.isEmpty ? 'Untitled test' : _title.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Text('Question 1 of ${_questions.length} · 1 mark', style: const TextStyle(color: Color(0xFF91A1BA), fontSize: 11)),
          const SizedBox(height: 9),
          Text(question?.text.text.isNotEmpty == true ? question!.text.text : 'Your question will appear here', style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 13),
          if (question != null) for (var i = 0; i < question.options.length; i++)
            Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), decoration: BoxDecoration(border: Border.all(color: facultyBorder), borderRadius: BorderRadius.circular(9)), child: Row(children: [const Icon(Icons.radio_button_unchecked, size: 16, color: Color(0xFF718096)), const SizedBox(width: 9), Expanded(child: Text(question.options[i].text.isEmpty ? 'Option ${String.fromCharCode(65 + i)}' : question.options[i].text, style: const TextStyle(color: Color(0xFFD7E0EF), fontSize: 12)))])),
          if (_settings['screenshot_deterrent']!) ...[
            const SizedBox(height: 12),
            const Center(child: Text('STUDENT NAME · SECTION · CAMPUS ID', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF65758F), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
          ],
        ]),
      ),
    ]));
  }
}

class _PaperQuestion {
  final text = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  int correctIndex = -1;
  void dispose() { text.dispose(); for (final option in options) { option.dispose(); } }
}

class _QuestionEditor extends StatelessWidget {
  final int index;
  final _PaperQuestion question;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  const _QuestionEditor({super.key, required this.index, required this.question, required this.canDelete, required this.onDelete, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFF101A30), borderRadius: BorderRadius.circular(12), border: Border.all(color: facultyBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('Question ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), const Spacer(), if (canDelete) IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Color(0xFFDC5571), size: 19), tooltip: 'Remove question')]),
          TextField(controller: question.text, onChanged: (_) => onChanged(), minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Question', hintText: 'Write a clear question')),
          const SizedBox(height: 8),
          for (var i = 0; i < question.options.length; i++)
            Row(children: [
              Radio<int>(value: i, groupValue: question.correctIndex, onChanged: (value) { if (value != null) { question.correctIndex = value; onChanged(); } }, activeColor: const Color(0xFF34A783)),
              Expanded(child: TextField(controller: question.options[i], onChanged: (_) => onChanged(), decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + i)}'))),
            ]),
          const Text('Select the radio button beside the correct answer.', style: TextStyle(color: Color(0xFF91A1BA), fontSize: 10)),
        ]),
      );
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingRow({required this.title, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        activeTrackColor: const Color(0xFF247C70),
        title: Text(title, style: const TextStyle(color: Color(0xFFE3EAF4), fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF91A1BA), fontSize: 10, height: 1.35)),
      );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)));
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: facultySurface, borderRadius: BorderRadius.circular(15), border: Border.all(color: facultyBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)), const SizedBox(height: 13), child]));
}

String _errorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (error.type == DioExceptionType.connectionError) return 'Could not reach the server. Check your connection.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}

// lib/features/faculty/quiz/quiz_dashboard_screen.dart
// Real-time faculty dashboard: shows joined students, current question, timer controls
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class QuizDashboardScreen extends StatefulWidget {
  final String quizId;
  const QuizDashboardScreen({super.key, required this.quizId});

  @override
  State<QuizDashboardScreen> createState() => _QuizDashboardScreenState();
}

class _QuizDashboardScreenState extends State<QuizDashboardScreen> {
  Map<String, dynamic>? _quiz;
  List<dynamic> _questions = [];
  bool _loading = true;
  bool _isLive = false;
  int _participantCount = 0;
  int _currentQuestion = 0;
  int _timeLeft = 20;
  WebSocketChannel? _channel;
  bool _quizEnded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<Dio> _dio() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Dio(BaseOptions(
      baseUrl: dotenv.env['API_BASE_URL'] ?? '',
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  Future<void> _load() async {
    try {
      final dio = await _dio();
      final resp = await dio.get('/quiz/faculty/${widget.quizId}');
      final data = resp.data;

      setState(() {
        _quiz = data;
        _questions = data['questions'] ?? [];
        _loading = false;
        _isLive = data['status'] == 'live';
        _quizEnded = data['status'] == 'ended';
        _currentQuestion = data['current_question'] ?? 0;
      });
      if (data['status'] == 'waiting' || data['status'] == 'live') {
        _connectSocket();
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _connectSocket() async {
    final rawUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    final parsed = Uri.parse(rawUrl);
    final wsScheme = parsed.scheme == 'https' ? 'wss' : 'ws';
    final portStr = parsed.hasPort ? ':${parsed.port}' : '';
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();

    try {
      final wsUri = Uri.parse('$wsScheme://${parsed.host}$portStr/quiz?token=$token');
      _channel = WebSocketChannel.connect(wsUri);

      _channel!.sink.add(jsonEncode({
        'event': 'faculty-join',
        'quizId': widget.quizId,
      }));

      _channel!.stream.listen((msg) {
        final data = jsonDecode(msg);
        final event = data['event'];
        if (!mounted) return;
        setState(() {
          if (event == 'participant-count') _participantCount = data['count'] ?? 0;
          if (event == 'time-tick') _timeLeft = data['timeLeft'] ?? 20;
          if (event == 'question-start') {
            _currentQuestion = data['questionIndex'] ?? 0;
            _timeLeft = data['timeLeft'] ?? 20;
            _isLive = true;
          }
          if (event == 'quiz-ended') _quizEnded = true;
        });
      });
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
    }
  }

  void _sendEvent(String event, [Map<String, dynamic>? extra]) {
    final payload = {'event': event, 'quizId': widget.quizId, ...?extra};
    _channel?.sink.add(jsonEncode(payload));
  }

  Future<void> _startQuiz() async {
    try {
      final dio = await _dio();
      await dio.post('/quiz/${widget.quizId}/start');
      _sendEvent('go-live');
      if (mounted) setState(() => _isLive = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start quiz'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _nextQuestion() async {
    _sendEvent('next-question');
  }

  Future<void> _endQuiz() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Quiz?'),
        content: const Text('This will end the quiz for all students. You cannot undo this.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Quiz', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _sendEvent('end-quiz');
    try {
      final dio = await _dio();
      await dio.post('/quiz/${widget.quizId}/end');
    } catch (_) {}

    if (mounted) setState(() => _quizEnded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_quiz == null) return const Scaffold(body: Center(child: Text('Quiz not found')));

    final pin = _quiz!['pin'] ?? '';
    final title = _quiz!['title'] ?? '';
    final totalQ = _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(onPressed: () => context.go('/faculty/quizzes'), icon: const Icon(Icons.arrow_back)),
        actions: [
          if (_quizEnded)
            TextButton.icon(
              onPressed: () => context.go('/faculty/quizzes/${widget.quizId}/results'),
              icon: const Icon(Icons.bar_chart, color: Colors.white),
              label: const Text('View Results', style: TextStyle(color: Colors.white)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              if (_quizEnded)
                _banner(Colors.blue, Icons.check_circle, 'Quiz Ended', 'View full results from the Results button above')
              else if (_isLive)
                _banner(Colors.green, Icons.play_circle_filled, 'Quiz is LIVE', 'Students are answering questions right now')
              else
                _banner(Colors.orange, Icons.hourglass_top, 'Waiting Room', 'Share the PIN with students, then click "Go Live"'),

              const SizedBox(height: 24),

              // Top Stats Row
              Row(
                children: [
                  Expanded(child: _statCard('📌 Quiz PIN', pin, Colors.purple,
                    suffix: IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () {
                      Clipboard.setData(ClipboardData(text: pin));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN copied!')));
                    }),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('👥 Students Joined', '$_participantCount', Colors.teal)),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('❓ Questions', '$totalQ total', Colors.indigo)),
                  if (_isLive) ...[
                    const SizedBox(width: 16),
                    Expanded(child: _statCard('⏱ Time Left', '$_timeLeft sec', _timeLeft <= 5 ? Colors.red : Colors.orange)),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Current Question Preview
              if (_isLive && !_quizEnded && _questions.isNotEmpty) ...[
                const Text('Current Question', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Question ${_currentQuestion + 1} of $totalQ',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentQuestion < _questions.length
                              ? _questions[_currentQuestion]['question_text'] ?? ''
                              : '',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        if (_currentQuestion < _questions.length &&
                            _questions[_currentQuestion]['image_url'] != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(_questions[_currentQuestion]['image_url'], height: 160, fit: BoxFit.contain),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Options with correct highlighted
                        if (_currentQuestion < _questions.length) ...[
                          ...( (_questions[_currentQuestion]['options'] as List? ?? []) .asMap().entries.map((e) {
                            final opt = e.value;
                            final isCorrect = opt['isCorrect'] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isCorrect ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isCorrect ? Colors.green : Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Text(String.fromCharCode(65 + e.key), style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.grey)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(opt['text'] ?? '')),
                                  if (isCorrect) const Icon(Icons.check, color: Colors.green, size: 18),
                                ],
                              ),
                            );
                          })),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Control Buttons
              if (!_quizEnded) ...[
                const Text('Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!_isLive) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _participantCount > 0 ? _startQuiz : null,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(_participantCount > 0 ? 'Go Live Now!' : 'Waiting for students...'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _nextQuestion,
                          icon: const Icon(Icons.skip_next),
                          label: Text(_currentQuestion + 1 < totalQ ? 'Next Question' : 'Finish Questions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _endQuiz,
                        icon: const Icon(Icons.stop),
                        label: const Text('End Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(Color color, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, {Widget? suffix}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                if (suffix != null) ...[const SizedBox(width: 4), suffix],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

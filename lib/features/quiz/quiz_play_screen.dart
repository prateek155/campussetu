// lib/features/quiz/quiz_play_screen.dart
// Student quiz playing screen — real-time questions, 20s timer, submit answer
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QuizPlayScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  final String pin;

  const QuizPlayScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.pin,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> with TickerProviderStateMixin {
  WebSocketChannel? _channel;
  Map<String, dynamic>? _currentQuestion;
  int _questionIndex = 0;
  int _totalQuestions = 0;
  int _timeLeft = 20;
  bool _answered = false;
  int? _selectedIndex;
  int? _correctIndex;
  int _score = 0;
  int _totalScore = 0;
  String _status = 'waiting'; // waiting, live, ended
  List<dynamic> _leaderboard = [];
  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(vsync: this, duration: const Duration(seconds: 20));
    _connectSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _timerController.dispose();
    super.dispose();
  }

  void _connectSocket() async {
    final rawUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    final parsed = Uri.parse(rawUrl);
    final wsScheme = parsed.scheme == 'https' ? 'wss' : 'ws';
    final portStr = parsed.hasPort ? ':${parsed.port}' : '';
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final user = FirebaseAuth.instance.currentUser;

    final wsUri = Uri.parse('$wsScheme://${parsed.host}$portStr/quiz?token=$token');
    _channel = WebSocketChannel.connect(wsUri);


    // Join the quiz room
    _channel!.sink.add(jsonEncode({
      'event': 'student-join',
      'quizId': widget.quizId,
      'userId': user?.uid ?? '',
      'userName': user?.displayName ?? 'Student',
    }));

    _channel!.stream.listen((msg) {
      final data = jsonDecode(msg);
      final event = data['event'];
      if (!mounted) return;

      if (event == 'question-start') {
        setState(() {
          _currentQuestion = data['question'];
          _questionIndex = data['questionIndex'] ?? 0;
          _totalQuestions = data['totalQuestions'] ?? 0;
          _timeLeft = data['timeLeft'] ?? 20;
          _answered = false;
          _selectedIndex = null;
          _correctIndex = null;
          _status = 'live';
        });
        _timerController.forward(from: 0);
      }

      if (event == 'time-tick') {
        setState(() => _timeLeft = data['timeLeft'] ?? 0);
      }

      if (event == 'question-end') {
        setState(() {
          _correctIndex = data['correctIndex'];
          _answered = true; // force show correct answer
        });
        _timerController.stop();
      }

      if (event == 'answer-result') {
        setState(() {
          _score = data['score'] ?? 0;
          if (data['alreadySubmitted'] != true) _totalScore += _score;
          _correctIndex = data['correctIndex'];
        });
      }

      if (event == 'quiz-ended') {
        setState(() {
          _status = 'ended';
          _leaderboard = data['leaderboard'] ?? [];
        });
        _timerController.stop();
      }
    });
  }

  void _submitAnswer(int index) {
    if (_answered || _currentQuestion == null) return;
    setState(() {
      _answered = true;
      _selectedIndex = index;
    });
    _timerController.stop();

    final timeTaken = 20 - _timeLeft;
    _channel!.sink.add(jsonEncode({
      'event': 'submit-answer',
      'quizId': widget.quizId,
      'questionId': _currentQuestion!['id'],
      'selectedIndex': index,
      'timeTaken': timeTaken,
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (_status == 'ended') return _buildEndScreen();
    if (_status == 'waiting' || _currentQuestion == null) return _buildWaitingScreen();
    return _buildQuestionScreen();
  }

  Widget _buildWaitingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF6C63FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top, size: 72, color: Colors.white70),
            const SizedBox(height: 24),
            Text(
              widget.quizTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text('Waiting for faculty to start...', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text('PIN: ${widget.pin}', style: const TextStyle(color: Colors.white60, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionScreen() {
    final options = (_currentQuestion!['options'] as List<dynamic>? ?? []);
    final timerColor = _timeLeft <= 5 ? Colors.red : _timeLeft <= 10 ? Colors.orange : Colors.green;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FF),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Question ${_questionIndex + 1} / $_totalQuestions',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: timerColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: timerColor, size: 16),
                        const SizedBox(width: 4),
                        Text('$_timeLeft', style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            LinearProgressIndicator(
              value: _totalQuestions > 0 ? (_questionIndex + 1) / _totalQuestions : 0,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF6C63FF),
              minHeight: 4,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Question Text
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              _currentQuestion!['question_text'] ?? '',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            if (_currentQuestion!['image_url'] != null) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(_currentQuestion!['image_url'], height: 200, fit: BoxFit.contain),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Options
                    ...options.asMap().entries.map((entry) {
                      final i = entry.key;
                      final opt = entry.value;
                      Color cardColor = Colors.white;
                      Color borderColor = Colors.grey.shade200;
                      Widget? trailing;

                      if (_answered) {
                        if (i == _correctIndex) {
                          cardColor = Colors.green.withValues(alpha: 0.15);
                          borderColor = Colors.green;
                          trailing = const Icon(Icons.check_circle, color: Colors.green);
                        } else if (i == _selectedIndex && i != _correctIndex) {
                          cardColor = Colors.red.withValues(alpha: 0.1);
                          borderColor = Colors.red;
                          trailing = const Icon(Icons.cancel, color: Colors.red);
                        }
                      } else if (i == _selectedIndex) {
                        cardColor = const Color(0xFF6C63FF).withValues(alpha: 0.1);
                        borderColor = const Color(0xFF6C63FF);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: _answered ? null : () => _submitAnswer(i),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: borderColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                                  child: Center(child: Text(String.fromCharCode(65 + i), style: TextStyle(fontWeight: FontWeight.bold, color: borderColor))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(opt['text'] ?? '', style: const TextStyle(fontSize: 16))),
                                if (trailing != null) trailing,
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Score feedback after answering
                    if (_answered && _score > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('+$_score points! 🎉', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                    ] else if (_answered && _selectedIndex != null && _score == 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Text('Wrong answer 😔', style: TextStyle(fontSize: 16, color: Colors.red)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom score bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Text('Total Score: $_totalScore', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndScreen() {
    final top3 = _leaderboard.take(3).toList();
    final myEntry = _leaderboard.firstWhere(
      (e) => e['user_id'] == FirebaseAuth.instance.currentUser?.uid,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF6C63FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const Text('Quiz Complete!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Final Results', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 32),

              // Top 3 Podium
              if (top3.isNotEmpty) ...[
                const Text('Top 3', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (top3.length >= 2) _podiumItem(top3[1], 2, 90),
                    const SizedBox(width: 8),
                    _podiumItem(top3[0], 1, 120),
                    const SizedBox(width: 8),
                    if (top3.length >= 3) _podiumItem(top3[2], 3, 70),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              // My Result
              if (myEntry != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Column(
                    children: [
                      const Text('Your Result', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('#${myEntry['rank']}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('${myEntry['total_score']} points', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _podiumItem(Map<String, dynamic> p, int rank, double height) {
    final emojis = ['🥇', '🥈', '🥉'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(p['name']?.toString().split(' ').first ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${p['total_score']} pts', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          width: 75, height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
          child: Center(child: Text(emojis[rank - 1], style: const TextStyle(fontSize: 28))),
        ),
      ],
    );
  }
}

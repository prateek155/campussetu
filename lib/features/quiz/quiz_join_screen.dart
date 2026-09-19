// lib/features/quiz/quiz_join_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';

class QuizJoinScreen extends StatefulWidget {
  final Map<String, dynamic>? quizData; // passed when tapping from list

  const QuizJoinScreen({super.key, this.quizData});

  @override
  State<QuizJoinScreen> createState() => _QuizJoinScreenState();
}

class _QuizJoinScreenState extends State<QuizJoinScreen> {
  final _pinC = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill PIN if quiz selected from list
    if (widget.quizData != null) {
      _pinC.text = widget.quizData!['pin'] ?? '';
    }
  }

  @override
  void dispose() {
    _pinC.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final pin = _pinC.text.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a PIN')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiService().joinQuiz(pin);
      final quiz = data['quiz'] as Map<String, dynamic>;


      if (!mounted) return;
      context.push('/quiz/play', extra: {
        'quizId': quiz['id'],
        'quizTitle': quiz['title'],
        'pin': pin,
      });
    } catch (e) {
      String msg = 'Could not join quiz. Check your PIN.';
      if (e is Exception) msg = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C63FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Join Quiz'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎯', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                if (widget.quizData != null) ...[
                  Text(
                    widget.quizData!['title'] ?? '',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By ${widget.quizData!['faculty_name'] ?? 'Faculty'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  const Text('Enter Quiz PIN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Get the PIN from your faculty', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 32),
                ],

                // PIN Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: TextField(
                    controller: _pinC,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 10),
                    decoration: const InputDecoration(
                      hintText: '------',
                      hintStyle: TextStyle(letterSpacing: 10, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _join(),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _join,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Join Quiz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

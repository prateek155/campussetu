// lib/features/quiz/quiz_join_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  void dispose() {
    _pinC.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final pin = _pinC.text.trim();
    final quizId = widget.quizData?['id']?.toString() ?? '';
    if (quizId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a quiz from Learning first')),
      );
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code shared by your faculty')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiService().joinQuiz(quizId, pin);
      final quiz = data['quiz'] as Map<String, dynamic>;


      if (!mounted) return;
      context.push('/quiz/play', extra: {
        'quizId': quiz['id'],
        'quizTitle': quiz['title'],
        'pin': pin,
      });
    } catch (e) {
      String msg = 'Could not join this quiz. Check the 6-digit code.';
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
      body: widget.quizData == null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.menu_book_rounded, size: 56, color: Colors.white),
                const SizedBox(height: 16),
                const Text('Choose a quiz from Learning first', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.go('/quiz'), child: const Text('Open Learning')),
              ]),
            ))
          : Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎯', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                Text(
                  widget.quizData!['title']?.toString() ?? 'Quiz',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'By ${widget.quizData!['faculty_name'] ?? 'Faculty'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text('Enter the 6-digit code shared by this faculty', style: TextStyle(color: Colors.white70, fontSize: 15), textAlign: TextAlign.center),
                const SizedBox(height: 28),

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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 10),
                    decoration: const InputDecoration(
                      hintText: '••••••',
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

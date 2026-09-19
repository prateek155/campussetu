// lib/features/quiz/quiz_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';

final liveQuizzesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return await ApiService().getLiveQuizzes();
});


class QuizListScreen extends ConsumerWidget {
  const QuizListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(liveQuizzesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FF),
      appBar: AppBar(
        title: const Text('Live Quizzes 📚'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(liveQuizzesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: quizzesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Failed to load quizzes', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(liveQuizzesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (quizzes) => quizzes.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🎯', style: TextStyle(fontSize: 64)),
                    SizedBox(height: 16),
                    Text('No Live Quizzes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Check back when your faculty starts a quiz!', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: quizzes.length,
                itemBuilder: (ctx, i) {
                  final q = quizzes[i];
                  final isLive = q['status'] == 'live';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/quiz/join', extra: q),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: isLive ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isLive ? Icons.play_circle_filled : Icons.hourglass_top,
                                color: isLive ? Colors.green : Colors.orange,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('By ${q['faculty_name'] ?? 'Faculty'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isLive ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isLive ? '🔴 LIVE' : '⏳ Waiting',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isLive ? Colors.green : Colors.orange),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${q['question_count'] ?? 0} questions', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(width: 8),
                                      Text('${q['participant_count'] ?? 0} joined', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

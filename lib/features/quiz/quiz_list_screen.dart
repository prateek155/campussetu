// lib/features/quiz/quiz_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

final liveQuizzesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return await ApiService().getLiveQuizzes();
});


class QuizListScreen extends ConsumerWidget {
  const QuizListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(liveQuizzesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Live quizzes'),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Paper tests',
            onPressed: () => context.push('/tests'),
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            onPressed: () => ref.invalidate(liveQuizzesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: quizzesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Failed to load quizzes', style: AppTypography.interBody(color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => ref.invalidate(liveQuizzesProvider), child: const Text('Retry')),
          ]),
        ),
        data: (quizzes) => quizzes.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🎯', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('No live quizzes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  Text('Check back when your faculty starts a quiz!', style: AppTypography.interBody(color: AppColors.inkSoft)),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: quizzes.length,
                itemBuilder: (ctx, i) {
                  final q = quizzes[i];
                  final isLive = q['status'] == 'live';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NeuCard(
                      onTap: () => context.push('/quiz/join', extra: q),
                      child: Row(children: [
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
                                  Text(q['title'] ?? '', style: AppTypography.interButton(size: 15)),
                                  const SizedBox(height: 4),
                                  Text('By ${q['faculty_name'] ?? 'Faculty'}', style: AppTypography.interCaption()),
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
                                      Text('${q['question_count'] ?? 0} questions', style: AppTypography.interCaption()),
                                      const SizedBox(width: 8),
                                      Text('${q['participant_count'] ?? 0} joined', style: AppTypography.interCaption()),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// lib/features/faculty/quiz/quiz_results_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

class QuizResultsScreen extends StatefulWidget {
  final String quizId;
  const QuizResultsScreen({super.key, required this.quizId});

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio(BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL'] ?? '',
        headers: {'Authorization': 'Bearer $token'},
      ));
      final resp = await dio.get('/quiz/${widget.quizId}/results');

      setState(() { _data = resp.data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade300;
  }

  String _rankEmoji(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data == null) return const Scaffold(body: Center(child: Text('Failed to load results')));

    final quiz = _data!['quiz'] as Map<String, dynamic>;
    final participants = _data!['participants'] as List<dynamic>;
    final questions = _data!['questions'] as List<dynamic>;
    final hardestQuestions = _hardestQuestions(participants, questions);

    return Scaffold(
      appBar: AppBar(
        title: Text('Results — ${quiz['title'] ?? ''}'),
        leading: IconButton(onPressed: () => context.go('/faculty/quizzes'), icon: const Icon(Icons.arrow_back)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  _card('👥 Total Students', '${participants.length}'),
                  const SizedBox(width: 16),
                  _card('❓ Questions', '${questions.length}'),
                  const SizedBox(width: 16),
                  if (participants.isNotEmpty)
                    _card('🏆 Top Score', '${participants[0]['total_score'] ?? 0} pts'),
                ],
              ),
              const SizedBox(height: 28),

              // Podium (Top 3)
              if (participants.length >= 3) ...[
                const Text('🏆 Top 3', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (participants.length >= 2) _podiumCard(participants[1], 2, 100),
                    const SizedBox(width: 12),
                    _podiumCard(participants[0], 1, 130),
                    const SizedBox(width: 12),
                    if (participants.length >= 3) _podiumCard(participants[2], 3, 80),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              // Full Leaderboard Table
              const Text('📊 Full Results', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Rank')),
                      DataColumn(label: Text('Student Name')),
                      DataColumn(label: Text('Total Score')),
                      DataColumn(label: Text('Correct Answers')),
                      DataColumn(label: Text('Tab-switch flags')),
                    ],
                    rows: participants.asMap().entries.map((entry) {
                      final p = entry.value;
                      final rank = p['rank'] ?? (entry.key + 1);
                      final answers = p['answers'];
                      int correct = 0;
                      if (answers is List) {
                        correct = answers.where((a) => a['isCorrect'] == true).length;
                      }
                      return DataRow(
                        color: WidgetStateProperty.all(
                          rank <= 3 ? _rankColor(rank).withValues(alpha: 0.1) : null,
                        ),
                        cells: [
                          DataCell(Text(_rankEmoji(rank), style: const TextStyle(fontSize: 18))),
                          DataCell(Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text('${p['total_score'] ?? 0} pts', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('$correct / ${questions.length}')),
                          DataCell(Text('${p['violation_count'] ?? 0}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (hardestQuestions.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Hardest questions · most missed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      for (final item in hardestQuestions.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(item['question'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 12),
                              Text('${((item['rate'] as num) * 100).round()}% missed', style: const TextStyle(color: Color(0xFFDC5571), fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (item['rate'] as num).toDouble(),
                                minHeight: 7,
                                color: const Color(0xFFDC5571),
                                backgroundColor: Colors.grey.withValues(alpha: 0.18),
                              ),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _hardestQuestions(List<dynamic> participants, List<dynamic> questions) {
    final summaries = <Map<String, dynamic>>[];
    for (final rawQuestion in questions) {
      if (rawQuestion is! Map) continue;
      final questionId = rawQuestion['id'].toString();
      var attempted = 0;
      var missed = 0;
      for (final rawParticipant in participants) {
        if (rawParticipant is! Map || rawParticipant['answers'] is! List) continue;
        for (final rawAnswer in rawParticipant['answers'] as List) {
          if (rawAnswer is! Map) continue;
          final answerId = rawAnswer['question_id'] ?? rawAnswer['questionId'];
          if (answerId?.toString() != questionId) continue;
          attempted++;
          if (rawAnswer['isCorrect'] != true) missed++;
          break;
        }
      }
      if (attempted > 0) {
        summaries.add({
          'question': (rawQuestion['question_text'] ?? 'Question').toString(),
          'attempted': attempted,
          'missed': missed,
          'rate': missed / attempted,
        });
      }
    }
    summaries.sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));
    return summaries;
  }

  Widget _podiumCard(Map<String, dynamic> p, int rank, double height) {
    return Column(
      children: [
        Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${p['total_score'] ?? 0} pts', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          width: 90,
          height: height,
          decoration: BoxDecoration(
            color: _rankColor(rank),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
          child: Center(
            child: Text(_rankEmoji(rank), style: const TextStyle(fontSize: 32)),
          ),
        ),
      ],
    );
  }
}

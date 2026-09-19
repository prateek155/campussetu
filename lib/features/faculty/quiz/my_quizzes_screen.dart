// lib/features/faculty/quiz/my_quizzes_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MyQuizzesScreen extends StatefulWidget {
  const MyQuizzesScreen({super.key});

  @override
  State<MyQuizzesScreen> createState() => _MyQuizzesScreenState();
}

class _MyQuizzesScreenState extends State<MyQuizzesScreen> {
  List<dynamic> _quizzes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      final resp = await dio.get('/quiz/my');

      setState(() { _quizzes = resp.data; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load quizzes'; _loading = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft': return Colors.grey;
      case 'waiting': return Colors.orange;
      case 'live': return Colors.green;
      case 'ended': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'draft': return Icons.edit_outlined;
      case 'waiting': return Icons.hourglass_top;
      case 'live': return Icons.play_circle_filled;
      case 'ended': return Icons.check_circle_outline;
      default: return Icons.circle_outlined;
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/faculty/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quizzes'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout), tooltip: 'Sign Out'),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/faculty/quizzes/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Quiz'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ))
              : _quizzes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.quiz_outlined, size: 72, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No quizzes yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text('Create your first quiz to get started!', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/faculty/quizzes/create'),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Quiz'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _quizzes.length,
                      itemBuilder: (ctx, i) {
                        final q = _quizzes[i];
                        final status = q['status'] ?? 'draft';
                        final createdAt = DateTime.tryParse(q['created_at'] ?? '');
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_statusIcon(status), color: _statusColor(status)),
                            ),
                            title: Text(q['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('PIN: ${q['pin']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${q['question_count'] ?? 0} questions  •  ${q['participant_count'] ?? 0} participants'
                                  '${createdAt != null ? '  •  ${DateFormat('MMM d, y').format(createdAt)}' : ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'dashboard') context.go('/faculty/quizzes/${q['id']}/dashboard');
                                if (val == 'results') context.go('/faculty/quizzes/${q['id']}/results');
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'dashboard', child: ListTile(leading: Icon(Icons.dashboard_outlined), title: Text('Open Dashboard'))),
                                if (status == 'ended')
                                  const PopupMenuItem(value: 'results', child: ListTile(leading: Icon(Icons.bar_chart), title: Text('View Results'))),
                              ],
                            ),
                            onTap: () => context.go('/faculty/quizzes/${q['id']}/dashboard'),
                          ),
                        );
                      },
                    ),
    );
  }
}

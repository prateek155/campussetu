// lib/features/admin/admin_faculty_screen.dart
// Admin panel section for managing faculty registration requests
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class AdminFacultyScreen extends StatefulWidget {
  const AdminFacultyScreen({super.key});

  @override
  State<AdminFacultyScreen> createState() => _AdminFacultyScreenState();
}

class _AdminFacultyScreenState extends State<AdminFacultyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _pending = [];
  List<dynamic> _approved = [];
  List<dynamic> _rejected = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
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
    setState(() => _loading = true);
    try {
      final dio = await _dio();
      final results = await Future.wait([
        dio.get('/admin/faculty-requests?status=pending'),
        dio.get('/admin/faculty-requests?status=approved'),
        dio.get('/admin/faculty-requests?status=rejected'),
      ]);

      setState(() {
        _pending = results[0].data ?? [];
        _approved = results[1].data ?? [];
        _rejected = results[2].data ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _approve(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Faculty?'),
        content: Text('Create faculty account for $name?\nThey will be able to login and create quizzes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = await _dio();
      await dio.post('/admin/faculty-requests/$id/approve');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $name approved! Account created.'), backgroundColor: Colors.green),
        );
      }
      _load();
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Approval failed';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Request?'),
        content: Text('Reject faculty request from $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = await _dio();
      await dio.post('/admin/faculty-requests/$id/reject');

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected')));
      _load();
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Failed';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Management'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'Approved (${_approved.length})'),
            Tab(text: 'Rejected (${_rejected.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildList(_pending, showActions: true),
                _buildList(_approved, showActions: false),
                _buildList(_rejected, showActions: false),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> items, {required bool showActions}) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('No requests here', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final r = items[i];
        final createdAt = DateTime.tryParse(r['created_at'] ?? '');
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                      child: Text(
                        (r['name'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(r['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (createdAt != null)
                      Text(DateFormat('MMM d, y').format(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.account_balance_outlined, 'College', r['college_name'] ?? '-'),
                          const SizedBox(height: 6),
                          _infoRow(Icons.book_outlined, 'Subject', r['subject'] ?? '-'),
                        ],
                      ),
                    ),
                  ],
                ),
                if (showActions) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reject(r['id'], r['name'] ?? ''),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approve(r['id'], r['name'] ?? ''),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    );
  }
}

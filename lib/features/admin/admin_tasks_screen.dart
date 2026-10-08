// lib/features/admin/admin_tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/user_avatar.dart';
import 'widgets/admin_toast.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  static const _bg     = Color(0xFF080C14);
  static const _card   = Color(0xFF0D121E);
  static const _cardAlt= Color(0xFF141B2D);
  static const _border = Color(0xFF1E283D);
  static const _cyan   = Color(0xFF38BDF8);
  static const _green  = Color(0xFF10B981);
  static const _red    = Color(0xFFEF4444);
  static const _amber  = Color(0xFFF59E0B);
  static const _inkSoft= Color(0xFF94A3B8);

  List<dynamic> _tasks = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;

  String _filter = 'all'; // all, open, assigned, completed, on_hold
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().getAdminTasks(
        status: _filter,
        q: _searchCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _tasks = (res['data'] as List<dynamic>?) ?? [];
          _stats = (res['stats'] as Map<String, dynamic>?) ?? {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _deleteTask(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: _red, size: 22),
            SizedBox(width: 8),
            Text('Admin Delete Task', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Delete "$title"? This will remove the task, all associated applications, and cannot be undone.',
          style: const TextStyle(color: _inkSoft, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _inkSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ApiService().adminDeleteTask(id);
      if (mounted) {
        AdminToast.success(context, 'Task deleted successfully');
        _load();
      }
    } catch (e) {
      if (mounted) AdminToast.error(context, 'Failed to delete task: $e');
    }
  }

  void _showApplicantsSheet(Map<String, dynamic> task) {
    final title = (task['title'] ?? 'Task').toString();
    final apps = (task['applications'] as List<dynamic>?) ?? [];
    final isDesktop = MediaQuery.of(context).size.width >= 650;

    Widget contentBuilder(BuildContext ctx) => Container(
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.of(context).size.height * (isDesktop ? 0.82 : 0.75),
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: isDesktop ? BorderRadius.circular(20) : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _border),
        boxShadow: isDesktop
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (!isDesktop)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.people_alt_rounded, color: _cyan, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Task Applicants', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(title, style: const TextStyle(color: _inkSoft, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text('${apps.length} Total', style: const TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, color: _inkSoft, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    splashRadius: 18,
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: _border, height: 1),
          Flexible(
            child: apps.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text('No applications received for this task yet.', style: TextStyle(color: _inkSoft, fontSize: 13)),
                    ),
                  )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: apps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final a = apps[i] as Map<String, dynamic>;
                        final status = (a['status'] ?? 'applied').toString();
                        final statusColor = status == 'accepted' ? _green : (status == 'rejected' ? _red : _cyan);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cardAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: status == 'accepted' ? _green.withValues(alpha: 0.4) : _border,
                            ),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                name: (a['name'] ?? 'Applicant').toString(),
                                imageUrl: a['photo_url']?.toString(),
                                size: 44,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (a['name'] ?? 'Student').toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${(a['college'] ?? '').toString()} • Campus ID: ${(a['campus_id'] ?? 'N/A').toString()}',
                                      style: const TextStyle(color: _inkSoft, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (a['email'] != null)
                                      Text(
                                        a['email'].toString(),
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Applied: ${_formatDate(a['created_at']?.toString())}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: contentBuilder(ctx),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => contentBuilder(ctx),
      );
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) {
      return iso;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return _green;
      case 'assigned': return _amber;
      case 'open': return _cyan;
      case 'on_hold': return const Color(0xFF64748B);
      default: return _inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                color: _card,
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.assignment_rounded, color: _cyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Task Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text('Audit all student tasks, requests, helper assignments & dual closures', style: TextStyle(color: _inkSoft, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh_rounded, color: _cyan, size: 20),
                        onPressed: _load,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stat Badges
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatChip(label: 'Total', count: _stats['total'] ?? _tasks.length, color: Colors.white),
                        const SizedBox(width: 8),
                        _StatChip(label: 'Open', count: _stats['open_count'] ?? 0, color: _cyan),
                        const SizedBox(width: 8),
                        _StatChip(label: 'Assigned', count: _stats['assigned_count'] ?? 0, color: _amber),
                        const SizedBox(width: 8),
                        _StatChip(label: 'Completed', count: _stats['completed_count'] ?? 0, color: _green),
                        const SizedBox(width: 8),
                        _StatChip(label: 'On Hold', count: _stats['on_hold_count'] ?? 0, color: const Color(0xFF64748B)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Search + Filters
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onSubmitted: (_) => _load(),
                            decoration: const InputDecoration(
                              hintText: 'Search tasks by title or details...',
                              hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _load,
                        child: const Text('Search', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(label: 'All Tasks', value: 'all', selected: _filter == 'all', onSelect: (v) { setState(() => _filter = v); _load(); }),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Open', value: 'open', selected: _filter == 'open', onSelect: (v) { setState(() => _filter = v); _load(); }),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Assigned', value: 'assigned', selected: _filter == 'assigned', onSelect: (v) { setState(() => _filter = v); _load(); }),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Completed', value: 'completed', selected: _filter == 'completed', onSelect: (v) { setState(() => _filter = v); _load(); }),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'On Hold', value: 'on_hold', selected: _filter == 'on_hold', onSelect: (v) { setState(() => _filter = v); _load(); }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Task List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _cyan))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: $_error', style: const TextStyle(color: _red)),
                              const SizedBox(height: 10),
                              ElevatedButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _tasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_outlined, color: _inkSoft.withValues(alpha: 0.5), size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No tasks found matching filter', style: TextStyle(color: _inkSoft, fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _tasks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (ctx, i) {
                                final task = _tasks[i] as Map<String, dynamic>;
                                return _buildTaskCard(task);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final id = (task['id'] ?? '').toString();
    final title = (task['title'] ?? '').toString();
    final desc = (task['description'] ?? '').toString();
    final type = (task['type'] ?? 'paid').toString();
    final isPaid = type == 'paid';
    final reward = isPaid ? '₹${task['amount']}' : '${task['points']} pts';
    final status = (task['status'] ?? 'open').toString();
    final statusClr = _statusColor(status);

    final poster = task['poster'] is Map ? Map<String, dynamic>.from(task['poster'] as Map) : <String, dynamic>{};
    final assignee = task['assignee'] is Map ? Map<String, dynamic>.from(task['assignee'] as Map) : null;
    final appsCount = int.tryParse((task['applications_count'] ?? 0).toString()) ?? 0;

    final posterCompleted = task['poster_completed'] == true;
    final assigneeCompleted = task['assignee_completed'] == true;
    final posterCompletedAt = task['poster_completed_at']?.toString();
    final assigneeCompletedAt = task['assignee_completed_at']?.toString();
    final completedAt = task['completed_at']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _cardAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isPaid ? _green : _amber).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? '💰 $reward' : '⭐ $reward',
                    style: TextStyle(color: isPaid ? _green : _amber, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusClr.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusClr, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(task['created_at']?.toString()),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Desc
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: _inkSoft, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 14),

                // Poster & Assignee Info Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      // Poster
                      Row(
                        children: [
                          UserAvatar(
                            name: (poster['name'] ?? 'P').toString(),
                            imageUrl: poster['photo_url']?.toString(),
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('POSTER: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w700)),
                                    Expanded(
                                      child: Text(
                                        (poster['name'] ?? 'Unknown').toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${(poster['college'] ?? '').toString()} • ID: ${(poster['campus_id'] ?? 'N/A').toString()}',
                                  style: const TextStyle(color: _inkSoft, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (assignee != null) ...[
                        const Divider(color: _border, height: 16),
                        // Assignee
                        Row(
                          children: [
                            UserAvatar(
                              name: (assignee['name'] ?? 'H').toString(),
                              imageUrl: assignee['photo_url']?.toString(),
                              size: 32,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('HELPER: ', style: TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w700)),
                                      Expanded(
                                        child: Text(
                                          (assignee['name'] ?? 'Assigned Helper').toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${(assignee['college'] ?? '').toString()} • ID: ${(assignee['campus_id'] ?? 'N/A').toString()}',
                                    style: const TextStyle(color: _inkSoft, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Dual Confirmation Status Card (if assigned or completed)
                if (status == 'assigned' || status == 'completed') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: status == 'completed' ? _green.withValues(alpha: 0.08) : _cardAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: status == 'completed' ? _green.withValues(alpha: 0.3) : _border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.handshake_rounded, color: _cyan, size: 16),
                            SizedBox(width: 6),
                            Text('Dual Confirmation Status', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              assigneeCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: assigneeCompleted ? _green : _inkSoft,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                assigneeCompleted
                                    ? 'Helper Confirmed (${_formatDate(assigneeCompletedAt)})'
                                    : 'Helper Confirmation Pending',
                                style: TextStyle(
                                  color: assigneeCompleted ? _green : _inkSoft,
                                  fontSize: 11,
                                  fontWeight: assigneeCompleted ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              posterCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: posterCompleted ? _green : _inkSoft,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                posterCompleted
                                    ? 'Poster Confirmed (${_formatDate(posterCompletedAt)})'
                                    : 'Poster Confirmation Pending',
                                style: TextStyle(
                                  color: posterCompleted ? _green : _inkSoft,
                                  fontSize: 11,
                                  fontWeight: posterCompleted ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (completedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Closed & Settled: ${_formatDate(completedAt)}',
                            style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons Row
                Row(
                  children: [
                    // View Applicants Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cyan,
                        side: const BorderSide(color: _cyan),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.people_outline_rounded, size: 16),
                      label: Text('Applicants ($appsCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () => _showApplicantsSheet(task),
                    ),
                    const Spacer(),

                    // Admin Delete Button
                    IconButton(
                      tooltip: 'Delete Task (Admin)',
                      icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 20),
                      onPressed: () => _deleteTask(id, title),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final dynamic count;
  final Color color;
  const _StatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
          Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String) onSelect;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF38BDF8);
    const border = Color(0xFF1E283D);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cyan.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? cyan : border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? cyan : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

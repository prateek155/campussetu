import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/user_avatar.dart';

class HelpingTaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const HelpingTaskDetailScreen({super.key, required this.taskId});
  @override
  ConsumerState<HelpingTaskDetailScreen> createState() => _HelpingTaskDetailScreenState();
}

class _HelpingTaskDetailScreenState extends ConsumerState<HelpingTaskDetailScreen> {
  bool _busy = false;

  Future<void> _ensureToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) ApiService().setToken(token);
    }
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      await _ensureToken();
      await ApiService().applyHelpingTask(widget.taskId);
      ref.invalidate(helpingTaskDetailProvider(widget.taskId));
      ref.invalidate(helpingTasksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applied ✓ Poster will review your application'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(String applicantId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Accept $name?', style: AppTypography.soraHeading3()),
        content: Text('They will be assigned as the helper for this task.', style: AppTypography.interBody()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanDeep),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept Helper', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _ensureToken();
      await ApiService().acceptHelpingApplicant(widget.taskId, applicantId);
      ref.invalidate(helpingTaskDetailProvider(widget.taskId));
      ref.invalidate(helpingTasksProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Helper accepted ✓ Task assigned'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete task?', style: AppTypography.soraHeading3()),
        content: Text('Ye task permanent delete ho jayega.', style: AppTypography.interBody()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _ensureToken();
      await ApiService().deleteHelpingTask(widget.taskId);
      ref.invalidate(helpingTasksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted'), backgroundColor: AppColors.success));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _postedLabel(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    try {
      return '${DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal())} (${timeago.format(dt)})';
    } catch (_) {
      return iso.split('T').first;
    }
  }

  int _daysLeft(String? expiresIso, String? createdIso) {
    DateTime? e = expiresIso != null ? DateTime.tryParse(expiresIso) : null;
    e ??= createdIso != null ? DateTime.tryParse(createdIso)?.add(const Duration(days: 7)) : null;
    if (e == null) return 0;
    return e.difference(DateTime.now()).inDays;
  }

  Future<void> _complete({required bool isPoster, required bool isPaid, required String reward}) async {
    final title = isPoster ? 'Confirm Task Completion (Poster)' : 'Mark Task as Completed (Helper)';
    final content = isPoster
        ? (isPaid
            ? 'Confirm that the task has been finished by the helper and cash/UPI reward ($reward) has been settled.'
            : 'Confirm that helper completed the task. If helper also confirms, $reward will be transferred to helper.')
        : 'Confirm that you have successfully completed this task. The poster must also confirm to fully close the task.';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: AppTypography.soraHeading3()),
        content: Text(content, style: AppTypography.interBody()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _ensureToken();
      final res = await ApiService().completeHelpingTask(widget.taskId);
      ref.invalidate(helpingTaskDetailProvider(widget.taskId));
      ref.invalidate(currentUserProvider);
      ref.invalidate(helpingTasksProvider);

      if (mounted) {
        final isClosed = res['status'] == 'completed';
        final msg = isClosed
            ? 'Task fully closed! Both sides confirmed ✓'
            : (res['message'] ?? 'Confirmed ✓ Waiting for other side confirmation');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(helpingTaskDetailProvider(widget.taskId));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink), onPressed: () => context.pop()),
        actions: [
          Consumer(builder: (ctx, ref2, __) {
            final v = async.value;
            final isPoster = v != null && v['is_poster'] == true;
            if (!isPoster) return const SizedBox.shrink();
            return IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error), onPressed: _busy ? null : _delete);
          }),
        ],
      ),
      body: async.when(
        data: (d) {
          final isPaid = (d['type'] ?? 'paid') == 'paid';
          final reward = isPaid ? '₹${d['amount']}' : '${d['points']} pts';
          final isPoster = d['is_poster'] == true;
          final isAssignee = d['is_assignee'] == true;
          final status = (d['status'] ?? 'open').toString();
          final isHold = status == 'on_hold';
          final isAssigned = status == 'assigned';
          final isCompleted = status == 'completed';
          final apps = (d['applications'] as List?) ?? [];
          final myApp = d['my_application'];
          final poster = d['poster'] is Map ? Map<String, dynamic>.from(d['poster'] as Map) : <String, dynamic>{};
          final assignee = d['assignee'] is Map ? Map<String, dynamic>.from(d['assignee'] as Map) : null;
          final img = (d['image_url'] ?? '').toString();
          final daysLeft = _daysLeft(d['expires_at']?.toString(), d['created_at']?.toString());

          final posterCompleted = d['poster_completed'] == true;
          final assigneeCompleted = d['assignee_completed'] == true;
          final posterCompletedAt = d['poster_completed_at']?.toString();
          final assigneeCompletedAt = d['assignee_completed_at']?.toString();
          final completedAt = d['completed_at']?.toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(isPaid ? '💰 Paid' : '⭐ Points', style: AppTypography.interBadge(color: isPaid ? AppColors.success : AppColors.warning)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                  child: Text(reward, style: AppTypography.monoCode(size: 14, weight: FontWeight.w700)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.14)
                        : (isAssigned ? AppColors.warning.withValues(alpha: 0.14) : AppColors.cyanDeep.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: AppTypography.interBadge(
                      color: isCompleted ? AppColors.success : (isAssigned ? AppColors.warning : AppColors.cyanDeep),
                    ),
                  ),
                ),
              ]),
              if (isHold)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(color: AppColors.inkSoft.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.pause_circle_outline_rounded, size: 18, color: AppColors.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(child: Text('⏸ Ye task hold par hai (7 days expiry). ${isPoster ? 'Sirf aap dekh sakte ho.' : 'Ab apply nahi ho sakta.'}', style: AppTypography.interBody(color: AppColors.inkSoft, size: 13))),
                  ]),
                ),
              const SizedBox(height: 10),
              Text((d['title'] ?? '').toString(), style: AppTypography.soraHeading2()),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.schedule_outlined, size: 13, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Expanded(child: Text('Posted: ${_postedLabel(d['created_at']?.toString())}', style: AppTypography.interCaption(color: AppColors.inkSoft))),
                if (!isHold && status == 'open') Text('$daysLeft d left', style: AppTypography.interBadge(color: daysLeft <= 2 ? AppColors.error : AppColors.cyanDeep)),
              ]),
              const SizedBox(height: 8),
              Text((d['description'] ?? '').toString(), style: AppTypography.interBody(color: AppColors.inkSoft)),
              if (img.isNotEmpty) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: img,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 180, color: AppColors.shadowDark.withValues(alpha: 0.15)),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Poster Profile Card
              Text('Posted by', style: AppTypography.interButton(size: 14)),
              const SizedBox(height: 6),
              NeuCard(
                padding: const EdgeInsets.all(14),
                onTap: poster['id'] != null ? () => context.push('${AppRoutes.profile}?userId=${poster['id']}') : null,
                child: Row(children: [
                  UserAvatar(name: (poster['name'] ?? '?').toString(), imageUrl: poster['photo_url']?.toString(), size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((poster['name'] ?? 'Student').toString(), style: AppTypography.interButton(size: 14)),
                      Text('${(poster['college'] ?? '').toString()} • Tap to view profile', style: AppTypography.interCaption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.inkSoft),
                ]),
              ),

              // Assigned Helper Card (when assigned or completed)
              if (assignee != null) ...[
                const SizedBox(height: 14),
                Text('Assigned Helper', style: AppTypography.interButton(size: 14)),
                const SizedBox(height: 6),
                NeuCard(
                  padding: const EdgeInsets.all(14),
                  onTap: assignee['id'] != null ? () => context.push('${AppRoutes.profile}?userId=${assignee['id']}') : null,
                  child: Row(children: [
                    UserAvatar(name: (assignee['name'] ?? '?').toString(), imageUrl: assignee['photo_url']?.toString(), size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text((assignee['name'] ?? 'Helper').toString(), style: AppTypography.interButton(size: 14))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.cyanDeep.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                            child: const Text('HELPER', style: TextStyle(color: AppColors.cyanDeep, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        Text('${(assignee['college'] ?? '').toString()} • Tap to view profile', style: AppTypography.interCaption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.inkSoft),
                  ]),
                ),
              ],

              if (d['deadline'] != null && d['deadline'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.event_outlined, size: 15, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text('Deadline: ${d['deadline'].toString().split('T').first}', style: AppTypography.interBody(color: AppColors.error, size: 13)),
                ]),
              ],

              // ── DUAL CONFIRMATION STATUS SECTION ──
              if (isAssigned || isCompleted) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.success.withValues(alpha: 0.08) : AppColors.darkTileAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCompleted ? AppColors.success.withValues(alpha: 0.3) : AppColors.inkSoft.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(
                        isCompleted ? Icons.check_circle_rounded : Icons.handshake_rounded,
                        color: isCompleted ? AppColors.success : AppColors.cyanDeep,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('Dual-Confirmation Closure', style: AppTypography.interButton(size: 14)),
                      const Spacer(),
                      Text(
                        isCompleted ? 'FULLY CLOSED' : 'IN PROGRESS',
                        style: TextStyle(
                          color: isCompleted ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Both the Task Poster and the Helper must confirm completion to close the task.',
                      style: AppTypography.interCaption(color: AppColors.inkSoft),
                    ),
                    const Divider(height: 20),

                    // Step 1: Helper confirmation
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(
                        assigneeCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: assigneeCompleted ? AppColors.success : AppColors.inkSoft,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('1. Helper Completion', style: AppTypography.interButton(size: 13)),
                          Text(
                            assigneeCompleted
                                ? '✓ Helper marked complete on ${_formatDate(assigneeCompletedAt)}'
                                : '⏳ Waiting for helper to confirm completion',
                            style: AppTypography.interCaption(color: assigneeCompleted ? AppColors.success : AppColors.inkSoft),
                          ),
                        ]),
                      ),
                    ]),

                    const SizedBox(height: 12),

                    // Step 2: Poster confirmation
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(
                        posterCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: posterCompleted ? AppColors.success : AppColors.inkSoft,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('2. Poster Confirmation', style: AppTypography.interButton(size: 13)),
                          Text(
                            posterCompleted
                                ? '✓ Poster confirmed complete on ${_formatDate(posterCompletedAt)}'
                                : '⏳ Waiting for poster to confirm and close',
                            style: AppTypography.interCaption(color: posterCompleted ? AppColors.success : AppColors.inkSoft),
                          ),
                        ]),
                      ),
                    ]),

                    if (isCompleted && completedAt != null) ...[
                      const Divider(height: 20),
                      Row(children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Closed on ${_formatDate(completedAt)} • ${isPaid ? "Payment settled" : "Points transferred"}',
                            style: AppTypography.interCaption(color: AppColors.success),
                          ),
                        ),
                      ]),
                    ],
                  ]),
                ),
              ],

              const SizedBox(height: 20),

              // ── APPLICATION BUTTON FOR STUDENTS ──
              if (!isPoster && !isAssignee && status == 'open' && !isHold)
                GestureDetector(
                  onTap: _busy ? null : (myApp != null ? null : _apply),
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: myApp != null ? null : AppColors.cyanGradient,
                      color: myApp != null ? AppColors.success.withValues(alpha: 0.15) : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            myApp != null ? '✓ Applied (${myApp['status']})' : 'Apply for this Task',
                            style: AppTypography.interButton(color: myApp != null ? AppColors.success : Colors.white),
                          ),
                  ),
                ),

              // ── HELPER'S COMPLETION BUTTON ──
              if (isAssignee && isAssigned) ...[
                if (!assigneeCompleted)
                  GestureDetector(
                    onTap: _busy ? null : () => _complete(isPoster: false, isPaid: isPaid, reward: reward),
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.center,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Mark as Completed (Helper Side)', style: AppTypography.interButton(color: Colors.white)),
                    ),
                  )
                else if (!posterCompleted)
                  NeuCard(
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: Text(
                        '✓ You marked completed! Waiting for poster confirmation.',
                        style: AppTypography.interButton(color: AppColors.cyanDeep, size: 13),
                      ),
                    ),
                  ),
              ],

              // ── POSTER'S ACTIONS & APPLICANTS ──
              if (isPoster) ...[
                const SizedBox(height: 12),
                Text('Applicants (${apps.length}) — tap profile to review', style: AppTypography.soraHeading3()),
                const SizedBox(height: 4),
                Text('Review profile then Accept one student as helper', style: AppTypography.interCaption()),
                const SizedBox(height: 10),
                if (apps.isEmpty)
                  NeuCard(padding: const EdgeInsets.all(18), child: Center(child: Text('No applications yet. Share with friends!', style: AppTypography.interCaption()))),
                ...apps.map((a) {
                  final m = Map<String, dynamic>.from(a as Map);
                  final ap = m['applicant'] is Map ? Map<String, dynamic>.from(m['applicant'] as Map) : <String, dynamic>{};
                  final st = (m['status'] ?? 'applied').toString();
                  final name = (ap['name'] ?? 'Student').toString();
                  final aid = (m['applicant_id'] ?? ap['id'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NeuCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => context.push('${AppRoutes.profile}?userId=$aid'),
                          child: UserAvatar(name: name, imageUrl: ap['photo_url']?.toString(), size: 44),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('${AppRoutes.profile}?userId=$aid'),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: AppTypography.interButton(size: 14)),
                              Text('${(ap['college'] ?? '').toString()} • ${(ap['skills'] is List ? (ap['skills'] as List).take(2).join(', ') : '').toString()}', style: AppTypography.interCaption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(st.toUpperCase(), style: AppTypography.interBadge(color: st == 'accepted' ? AppColors.success : st == 'rejected' ? AppColors.error : AppColors.cyanDeep)),
                            ]),
                          ),
                        ),
                        if (status == 'open' && st == 'applied')
                          GestureDetector(
                            onTap: _busy ? null : () => _accept(aid, name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(10)),
                              child: Text('Accept', style: AppTypography.interButton(color: Colors.white, size: 12)),
                            ),
                          ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 8),

                // Poster Complete Button
                if (isAssigned) ...[
                  if (!posterCompleted)
                    GestureDetector(
                      onTap: _busy ? null : () => _complete(isPoster: true, isPaid: isPaid, reward: reward),
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.center,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                isPaid ? 'Confirm Completed (Pay $reward offline)' : 'Confirm & Release $reward',
                                style: AppTypography.interButton(color: Colors.white),
                              ),
                      ),
                    )
                  else if (!assigneeCompleted)
                    NeuCard(
                      padding: const EdgeInsets.all(14),
                      child: Center(
                        child: Text(
                          '✓ You confirmed completion! Waiting for helper confirmation.',
                          style: AppTypography.interButton(color: AppColors.warning, size: 13),
                        ),
                      ),
                    ),
                ],

                if (isCompleted)
                  NeuCard(
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: Text(
                        isPaid ? '✓ Completed — cash/reward settled offline' : '✓ Completed — points transferred',
                        style: AppTypography.interButton(color: AppColors.success, size: 13),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _busy ? null : _delete,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    alignment: Alignment.center,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Delete Task', style: AppTypography.interButton(color: AppColors.error)),
                    ]),
                  ),
                ),
              ],
            ]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Failed', style: AppTypography.interBody(color: AppColors.error)),
            Text(e.toString(), style: AppTypography.interCaption()),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.invalidate(helpingTaskDetailProvider(widget.taskId)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.cyanDeep, borderRadius: BorderRadius.circular(10)),
                child: Text('Retry', style: AppTypography.interLabel(color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

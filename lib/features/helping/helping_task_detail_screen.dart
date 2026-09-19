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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applied ✓ Poster will review'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(String applicantId, String name) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('Accept $name?', style: AppTypography.soraHeading3()), content: Text('They will be assigned this task.', style: AppTypography.interBody()), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanDeep), onPressed: () => Navigator.pop(context, true), child: const Text('Accept', style: TextStyle(color: Colors.white)))]));
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _ensureToken();
      await ApiService().acceptHelpingApplicant(widget.taskId, applicantId);
      ref.invalidate(helpingTaskDetailProvider(widget.taskId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted ✓'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('Delete task?', style: AppTypography.soraHeading3()), content: Text('Ye task permanent delete ho jayega.', style: AppTypography.interBody()), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.white)))]));
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

  String _postedLabel(String? iso) {
    final raw = iso;
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    try {
      return '${DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal())} (${timeago.format(dt)})';
    } catch (_) {
      return raw.split('T').first;
    }
  }

  int _daysLeft(String? expiresIso, String? createdIso) {
    DateTime? e = expiresIso != null ? DateTime.tryParse(expiresIso) : null;
    e ??= createdIso != null ? DateTime.tryParse(createdIso)?.add(const Duration(days: 7)) : null;
    if (e == null) return 0;
    return e.difference(DateTime.now()).inDays;
  }

  Future<void> _complete(bool isPaid, String reward) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('Mark completed?', style: AppTypography.soraHeading3()), content: Text(isPaid ? 'Confirm you have paid $reward to helper (cash/UPI).' : 'This will transfer $reward from your points to helper. This cannot be undone.', style: AppTypography.interBody()), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), onPressed: () => Navigator.pop(context, true), child: const Text('Complete', style: TextStyle(color: Colors.white)))]));
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _ensureToken();
      final res = await ApiService().completeHelpingTask(widget.taskId);
      ref.invalidate(helpingTaskDetailProvider(widget.taskId));
      ref.invalidate(currentUserProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPaid ? 'Completed ✓ Pay $reward to helper' : 'Completed ✓ ${res['transferred_points']} pts transferred'), backgroundColor: AppColors.success));
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
          final status = (d['status'] ?? 'open').toString();
          final isHold = status == 'on_hold';
          final apps = (d['applications'] as List?) ?? [];
          final myApp = d['my_application'];
          final poster = d['poster'] is Map ? Map<String, dynamic>.from(d['poster'] as Map) : <String, dynamic>{};
          final img = (d['image_url'] ?? '').toString();
          final daysLeft = _daysLeft(d['expires_at']?.toString(), d['created_at']?.toString());
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text(isPaid ? '💰 Paid' : '⭐ Points', style: AppTypography.interBadge(color: isPaid ? AppColors.success : AppColors.warning))),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: Text(reward, style: AppTypography.monoCode(size: 14, weight: FontWeight.w700))),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: status == 'open' ? AppColors.cyanDeep.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: AppTypography.interBadge(color: status == 'open' ? AppColors.cyanDeep : AppColors.success))),
              ]),
              if (isHold)
                Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.inkSoft.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.pause_circle_outline_rounded, size: 18, color: AppColors.inkSoft), const SizedBox(width: 8), Expanded(child: Text('⏸ Ye task hold par hai (7 days expiry). ${isPoster ? 'Sirf aap dekh sakte ho.' : 'Ab apply nahi ho sakta.'}', style: AppTypography.interBody(color: AppColors.inkSoft, size: 13)))])),
              const SizedBox(height: 2),
              Text((d['title'] ?? '').toString(), style: AppTypography.soraHeading2()),
              const SizedBox(height: 6),
              Row(children: [Icon(Icons.schedule_outlined, size: 13, color: AppColors.inkSoft), const SizedBox(width: 4), Expanded(child: Text('Posted: ${_postedLabel(d['created_at']?.toString())}', style: AppTypography.interCaption(color: AppColors.inkSoft))), if (!isHold && status == 'open') Text('$daysLeft d left', style: AppTypography.interBadge(color: daysLeft <= 2 ? AppColors.error : AppColors.cyanDeep))]),
              const SizedBox(height: 6),
              Text((d['description'] ?? '').toString(), style: AppTypography.interBody(color: AppColors.inkSoft)),
              if (img.isNotEmpty) ...[const SizedBox(height: 14), ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: img, width: double.infinity, fit: BoxFit.cover, placeholder: (_, __) => Container(height: 180, color: AppColors.shadowDark.withValues(alpha: 0.15)), errorWidget: (_, __, ___) => const SizedBox.shrink()))],
              const SizedBox(height: 12),
              NeuCard(
                padding: const EdgeInsets.all(14),
                onTap: poster['id'] != null ? () => context.push('${AppRoutes.profile}?userId=${poster['id']}') : null,
                child: Row(children: [
                  UserAvatar(name: (poster['name'] ?? '?').toString(), imageUrl: poster['photo_url']?.toString(), size: 42),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((poster['name'] ?? 'Student').toString(), style: AppTypography.interButton(size: 14)), Text('${(poster['college'] ?? '').toString()} • Tap to view profile', style: AppTypography.interCaption(), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                  Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.inkSoft),
                ]),
              ),
              if (d['deadline'] != null && d['deadline'].toString().isNotEmpty) ...[const SizedBox(height: 10), Row(children: [const Icon(Icons.event_outlined, size: 15, color: AppColors.error), const SizedBox(width: 6), Text('Deadline: ${d['deadline'].toString().split('T').first}', style: AppTypography.interBody(color: AppColors.error, size: 13))])],
              const SizedBox(height: 16),
              if (!isPoster && isHold)
                Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.inkSoft.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text('⏸ Task on hold — expired', style: AppTypography.interButton(color: AppColors.inkSoft))),
              if (!isPoster && status == 'open' && !isHold)
                GestureDetector(
                  onTap: _busy ? null : (myApp != null ? null : _apply),
                  child: Container(width: double.infinity, height: 54, decoration: BoxDecoration(gradient: myApp != null ? null : AppColors.cyanGradient, color: myApp != null ? AppColors.success.withValues(alpha: 0.15) : null, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(myApp != null ? '✓ Applied (${myApp['status']})' : 'Apply for this Task', style: AppTypography.interButton(color: myApp != null ? AppColors.success : Colors.white))),
                ),
              if (isPoster) ...[
                Text('Applicants (${apps.length}) — tap profile to review', style: AppTypography.soraHeading3()),
                const SizedBox(height: 4),
                Text('Review profile then Accept one student', style: AppTypography.interCaption()),
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
                        GestureDetector(onTap: () => context.push('${AppRoutes.profile}?userId=$aid'), child: UserAvatar(name: name, imageUrl: ap['photo_url']?.toString(), size: 44)),
                        const SizedBox(width: 12),
                        Expanded(child: GestureDetector(onTap: () => context.push('${AppRoutes.profile}?userId=$aid'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: AppTypography.interButton(size: 14)), Text('${(ap['college'] ?? '').toString()} • ${(ap['skills'] is List ? (ap['skills'] as List).take(2).join(', ') : '').toString()}', style: AppTypography.interCaption(), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(st.toUpperCase(), style: AppTypography.interBadge(color: st == 'accepted' ? AppColors.success : st == 'rejected' ? AppColors.error : AppColors.cyanDeep))]))),
                        if (status == 'open' && st == 'applied')
                          GestureDetector(onTap: _busy ? null : () => _accept(aid, name), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(10)), child: Text('Accept', style: AppTypography.interButton(color: Colors.white, size: 12)))),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                if (status == 'assigned')
                  GestureDetector(
                    onTap: _busy ? null : () => _complete(isPaid, reward),
                    child: Container(width: double.infinity, height: 54, decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: Text(isPaid ? 'Mark Completed (pay $reward offline)' : 'Complete & Transfer $reward', style: AppTypography.interButton(color: Colors.white))),
                  ),
                if (status == 'completed') NeuCard(padding: const EdgeInsets.all(14), child: Center(child: Text(isPaid ? '✓ Completed — pay settled offline' : '✓ Completed — points transferred', style: AppTypography.interButton(color: AppColors.success, size: 13)))),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _busy ? null : _delete,
                  child: Container(width: double.infinity, height: 50, decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.error.withValues(alpha: 0.4))), alignment: Alignment.center, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), const SizedBox(width: 8), Text('Delete Task', style: AppTypography.interButton(color: AppColors.error))])),
                ),
              ],
            ]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Failed', style: AppTypography.interBody(color: AppColors.error)), Text(e.toString(), style: AppTypography.interCaption()), const SizedBox(height: 12), GestureDetector(onTap: () => ref.invalidate(helpingTaskDetailProvider(widget.taskId)), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.cyanDeep, borderRadius: BorderRadius.circular(10)), child: Text('Retry', style: AppTypography.interLabel(color: Colors.white))))])),
      ),
    );
  }
}

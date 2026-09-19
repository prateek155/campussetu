import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/models/helping_task_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_chip.dart';
import '../../core/widgets/neu_text_field.dart';
import 'create_helping_task_sheet.dart';

class HelpingBoardTab extends ConsumerStatefulWidget {
  const HelpingBoardTab({super.key});
  @override
  ConsumerState<HelpingBoardTab> createState() => HelpingBoardTabState();
}

class HelpingBoardTabState extends ConsumerState<HelpingBoardTab> {
  String _tab = 'All';
  bool _mineOnly = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> openPostSheet() async {
    final created = await showModalBottomSheet<bool>(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => const CreateHelpingTaskSheet());
    if (created == true) {
      ref.invalidate(helpingTasksProvider);
      ref.invalidate(currentUserProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Key format: tab|mine|status  (search is done locally to avoid per-keystroke API calls)
    final key = '$_tab|$_mineOnly|open';
    final asyncTasks = ref.watch(helpingTasksProvider(key));
    final meAsync = ref.watch(currentUserProvider);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NeuCard(
            padding: const EdgeInsets.all(18),
            onTap: openPostSheet,
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Need help with an assignment?', style: AppTypography.soraHeading3()),
                const SizedBox(height: 4),
                Text('Post a task & pay a student to do it for you', style: AppTypography.interBody(color: AppColors.inkSoft, size: 13)),
              ])),
              const SizedBox(width: 12),
              Container(width: 46, height: 46, decoration: const BoxDecoration(gradient: AppColors.cyanGradient, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: NeuTextField(hint: '🔍  Search task...', controller: _searchCtrl, onChanged: (_) => setState(() {}), prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkSoft, size: 20))),
            const SizedBox(width: 10),
            meAsync.when(
              data: (u) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [const Icon(Icons.stars_rounded, size: 16, color: AppColors.warning), const SizedBox(width: 4), Text('${u.points}', style: AppTypography.interButton(color: AppColors.warning, size: 13))]),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ...['All', 'Paid', 'Points'].map((t) => Padding(padding: const EdgeInsets.only(right: 8), child: NeuChip(label: t, isSelected: _tab == t, onTap: () => setState(() => _tab = t)))),
              NeuChip(label: 'My Tasks', isSelected: _mineOnly, onTap: () => setState(() => _mineOnly = !_mineOnly), selectedColor: AppColors.warning),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: asyncTasks.when(
          data: (tasks) {
            // Apply local search filter to avoid per-keystroke API calls
            final q = _searchCtrl.text.toLowerCase();
            final filtered = q.isEmpty
                ? tasks
                : tasks.where((t) =>
                    t.title.toLowerCase().contains(q) ||
                    t.description.toLowerCase().contains(q)).toList();
            if (filtered.isEmpty) {
              return Center(child: Padding(padding: const EdgeInsets.all(32), child: NeuCard(padding: const EdgeInsets.all(24), child: Column(children: [Icon(Icons.handshake_outlined, size: 40, color: AppColors.inkSoft), const SizedBox(height: 12), Text('No tasks yet', style: AppTypography.soraHeading3()), Text('Post the first helping task!', style: AppTypography.interCaption())]))));
            }
            return RefreshIndicator(
              onRefresh: () async { ref.invalidate(helpingTasksProvider(key)); ref.invalidate(currentUserProvider); },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => HelpingTaskCard(task: filtered[i]).animate(delay: (i * 60).ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Failed to load', style: AppTypography.interBody(color: AppColors.error)), Text(e.toString(), style: AppTypography.interCaption()), const SizedBox(height: 12), GestureDetector(onTap: () => ref.invalidate(helpingTasksProvider(key)), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.cyanDeep, borderRadius: BorderRadius.circular(10)), child: Text('Retry', style: AppTypography.interLabel(color: Colors.white))))])),
        ),
      ),
    ]);
  }
}

class HelpingTaskCard extends ConsumerWidget {
  final HelpingTask task;
  const HelpingTaskCard({super.key, required this.task});

  String _postedLabel() {
    final dt = task.createdDate;
    if (dt == null) return '';
    try {
      return '${DateFormat('dd MMM, hh:mm a').format(dt.toLocal())} • ${timeago.format(dt)}';
    } catch (_) {
      return task.createdAt.split('T').first;
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('Delete task?', style: AppTypography.soraHeading3()), content: Text('Ye task permanent delete ho jayega.', style: AppTypography.interBody()), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.white)))]));
    if (ok != true) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) ApiService().setToken(token);
      }
      await ApiService().deleteHelpingTask(task.id);
      ref.invalidate(helpingTasksProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted'), backgroundColor: AppColors.success));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaid = task.isPaid;
    final color = isPaid ? AppColors.success : AppColors.warning;
    final posterName = (task.poster?['name'] ?? '').toString();
    final meId = ref.watch(currentUserProvider).value?.id;
    final isMine = meId != null && meId == task.posterId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        padding: const EdgeInsets.all(16),
        onTap: () => context.push('${AppRoutes.helping}/${task.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text(isPaid ? '💰 Paid' : '⭐ Points', style: AppTypography.interBadge(color: color))),
            if (task.isOnHold) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.inkSoft.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text('⏸ ON HOLD', style: AppTypography.interBadge(color: AppColors.inkSoft)))],
            const Spacer(),
            if (isMine)
              GestureDetector(onTap: () => _delete(context, ref), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error))),
            if (isMine) const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: Text(task.rewardLabel, style: AppTypography.monoCode(size: 13, weight: FontWeight.w700, color: AppColors.ink))),
          ]),
          const SizedBox(height: 10),
          Text(task.title, style: AppTypography.interButton(color: AppColors.ink, size: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(task.description, style: AppTypography.interCaption(), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.schedule_outlined, size: 12, color: AppColors.inkSoft),
            const SizedBox(width: 4),
            Expanded(child: Text(_postedLabel(), style: AppTypography.interCaption(color: AppColors.inkSoft))),
            if (!task.isOnHold && task.status == 'open') Text('${task.daysLeft}d left', style: AppTypography.interBadge(color: task.daysLeft <= 2 ? AppColors.error : AppColors.cyanDeep)),
          ]),
          if (task.imageUrl != null && task.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: task.imageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover, placeholder: (_, __) => Container(height: 140, color: AppColors.shadowDark.withValues(alpha: 0.15)), errorWidget: (_, __, ___) => const SizedBox.shrink())),
          ],
          const SizedBox(height: 10),
          Row(children: [
            if (posterName.isNotEmpty) ...[Icon(Icons.person_outline, size: 13, color: AppColors.inkSoft), const SizedBox(width: 4), Expanded(child: Text(posterName, style: AppTypography.interCaption(), overflow: TextOverflow.ellipsis))],
            if (task.deadline != null && task.deadline!.isNotEmpty) ...[const Icon(Icons.event_outlined, size: 13, color: AppColors.error), const SizedBox(width: 4), Text(task.deadline!.split('T').first, style: AppTypography.interCaption(color: AppColors.error))],
            const Spacer(),
            if (task.applicationsCount > 0) Text('${task.applicationsCount} applied', style: AppTypography.interBadge(color: AppColors.cyanDeep)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(gradient: task.isOnHold ? null : AppColors.cyanGradient, color: task.isOnHold ? AppColors.shadowDark.withValues(alpha: 0.4) : null, borderRadius: BorderRadius.circular(9)), child: Text(task.isOnHold ? 'On Hold' : 'Open →', style: AppTypography.interButton(color: Colors.white, size: 12))),
          ]),
        ]),
      ),
    );
  }
}

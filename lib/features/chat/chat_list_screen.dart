import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/user_avatar.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncChats = ref.watch(chatThreadsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Messages', style: AppTypography.soraDisplay(size: 26)), Text('Stay connected', style: AppTypography.interBody(color: AppColors.inkSoft))]),
              const Spacer(),
              NeuCard(padding: const EdgeInsets.all(12), onTap: () {}, child: const Icon(Icons.edit_outlined, size: 20, color: AppColors.cyanDeep)),
            ]),
          ),
          Expanded(
            child: asyncChats.when(
              data: (threads) {
                if (threads.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: NeuCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.inkSoft),
                          const SizedBox(height: 12),
                          Text('No conversations yet', style: AppTypography.soraHeading3()),
                          Text('Connect with students to start chatting', style: AppTypography.interBody(color: AppColors.inkSoft), textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(chatThreadsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: threads.length,
                    itemBuilder: (ctx, i) {
                      final t = threads[i];
                      final id = (t['id'] ?? t['chat_id'] ?? '$i').toString();
                      final name = (t['name'] ?? t['other_user']?['name'] ?? t['group_name'] ?? 'Chat').toString();
                      final lastMsg = (t['last_message'] ?? t['lastMessage'] ?? '').toString();
                      final time = (t['time'] ?? t['updated_at'] ?? '').toString();
                      final unread = (t['unread'] ?? t['unread_count'] ?? 0) as int;
                      return _ThreadCard(name: name, lastMessage: lastMsg.isEmpty ? 'Tap to open' : lastMsg, time: time.length > 10 ? time.substring(11, 16) : time, unread: unread, onTap: () => context.go('/chat/$id')).animate(delay: (i * 60).ms).fadeIn(duration: 300.ms).slideX(begin: -0.05);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Failed to load chats', style: AppTypography.interBody(color: AppColors.error)), Text(e.toString(), style: AppTypography.interCaption()), const SizedBox(height: 12), GestureDetector(onTap: () => ref.invalidate(chatThreadsProvider), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.cyanDeep, borderRadius: BorderRadius.circular(10)), child: Text('Retry', style: AppTypography.interLabel(color: Colors.white))))])),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final VoidCallback onTap;
  const _ThreadCard({required this.name, required this.lastMessage, required this.time, this.unread = 0, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NeuCard(
          padding: const EdgeInsets.all(14),
          onTap: onTap,
          child: Row(children: [
            UserAvatar(name: name, size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: AppTypography.interButton(color: AppColors.ink, size: 14)), const SizedBox(height: 3), Text(lastMessage, style: AppTypography.interBodySmall(color: unread > 0 ? AppColors.ink : AppColors.inkSoft).copyWith(fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400), overflow: TextOverflow.ellipsis)])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(time, style: AppTypography.monoTimestamp()),
              const SizedBox(height: 4),
              if (unread > 0) Container(width: 20, height: 20, decoration: const BoxDecoration(color: AppColors.cyanDeep, shape: BoxShape.circle), alignment: Alignment.center, child: Text('$unread', style: AppTypography.interBadge(color: Colors.white))),
            ]),
          ]),
        ),
      );
}

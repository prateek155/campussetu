import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/router/app_router.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});
  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  final Set<String> _dismissed = {};
  final Map<String, String> _states = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(UserModel u) async {
    try {
      await ApiService().sendConnectionRequest(u.id);
      setState(() => _states[u.id] = 'pending');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent ✓'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final s = (e.response?.data?['status'] ?? 'pending').toString();
        setState(() => _states[u.id] = s);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s == 'pending' ? 'Already sent' : 'Already $s'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.message}'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              const UserAvatar(name: 'You', size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1B1F2E) : const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(20)),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: AppTypography.interBodySmall(color: const Color(0xFF6B7280)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF6B7280)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.cyanDeep.withValues(alpha: 0.12), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: AppColors.cyanDeep), onPressed: () => context.go(AppRoutes.chat))),
            ]),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.cyanDeep,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.cyanDeep,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            tabs: const [Tab(text: 'Grow'), Tab(text: 'Catch up')],
          ),
          Container(height: 8, color: isDark ? const Color(0xFF1B1F2E) : const Color(0xFFE8E8E8)),
          Expanded(
            child: TabBarView(controller: _tabCtrl, children: [
              _GrowTab(searchQuery: _searchCtrl.text, dismissed: _dismissed, states: _states, onDismiss: (id) => setState(() => _dismissed.add(id)), onSend: _send, onSearchChanged: () => setState(() {})),
              const _CatchUpTab(),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _GrowTab extends ConsumerWidget {
  final String searchQuery;
  final Set<String> dismissed;
  final Map<String, String> states;
  final void Function(String) onDismiss;
  final Future<void> Function(UserModel) onSend;
  final VoidCallback onSearchChanged;
  const _GrowTab({required this.searchQuery, required this.dismissed, required this.states, required this.onDismiss, required this.onSend, required this.onSearchChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1B1F2E) : Colors.white;
    final params = DiscoverParams(search: searchQuery);
    final asyncUsers = ref.watch(discoverProvider(params));
    final asyncPending = ref.watch(_pendingProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(discoverProvider(params)); ref.invalidate(_pendingProvider); },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          InkWell(
            onTap: () => context.push(AppRoutes.invitations),
            child: Container(
              color: surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Text('Invitations', style: AppTypography.interButton(size: 15, color: AppColors.ink)),
                const Spacer(),
                asyncPending.when(
                  data: (list) => list.isEmpty ? const SizedBox() : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)), child: Text('${list.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.inkSoft),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 6, color: AppColors.bg),
          InkWell(
            onTap: () => context.push(AppRoutes.manageNetwork),
            child: Container(
              color: surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [Text('Manage my network', style: AppTypography.interButton(size: 15, color: AppColors.ink)), const Spacer(), Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.inkSoft)]),
            ),
          ),
          Container(height: 8, color: AppColors.bg),
          Container(
            color: surface,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('People you may know based on your recent activity', style: AppTypography.interButton(size: 14, color: AppColors.ink)),
          ),
          Container(
            color: surface,
            child: asyncUsers.when(
              data: (users) {
                final filtered = users.where((u) => !dismissed.contains(u.id)).toList();
                if (searchQuery.isNotEmpty) {
                  final q = searchQuery.toLowerCase();
                  final f2 = filtered.where((u) => u.name.toLowerCase().contains(q) || (u.college?.toLowerCase().contains(q) ?? false) || (u.branch?.toLowerCase().contains(q) ?? false)).toList();
                  if (f2.isEmpty) return Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No users found for "$searchQuery"', style: AppTypography.interCaption(), textAlign: TextAlign.center)));
                  return _PeopleGrid(users: f2, states: states, onDismiss: onDismiss, onSend: onSend);
                }
                if (filtered.isEmpty) return Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No suggestions', style: AppTypography.interCaption())));
                return _PeopleGrid(users: filtered, states: states, onDismiss: onDismiss, onSend: onSend);
              },
              loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Failed: $e', style: AppTypography.interCaption())),
            ),
          ),
          const SizedBox(height: 130),
        ],
      ),
    );
  }
}

final _pendingProvider = FutureProvider<List<dynamic>>((ref) async {
  try { return await ApiService().getPendingRequests(); } catch (_) { return []; }
});

class _PeopleGrid extends StatelessWidget {
  final List<UserModel> users;
  final Map<String, String> states;
  final void Function(String) onDismiss;
  final Future<void> Function(UserModel) onSend;
  const _PeopleGrid({required this.users, required this.states, required this.onDismiss, required this.onSend});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1B1F2E) : Colors.white;
    final border = isDark ? const Color(0xFF30364A) : const Color(0xFFE5E7EB);
    final ink = AppColors.ink;
    final muted = AppColors.inkSoft;
    return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.68),
    itemCount: users.length > 20 ? 20 : users.length,
    itemBuilder: (ctx, i) {
      final u = users[i];
      final state = states[u.id];
      final isPending = state == 'pending';
      return Container(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
        child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(height: 64, decoration: BoxDecoration(color: i % 3 == 0 ? const Color(0xFFB8C6C6) : i % 3 == 1 ? const Color(0xFFE8D5C4) : const Color(0xFFD6E4F0), borderRadius: const BorderRadius.vertical(top: Radius.circular(12)))),
            Positioned(
              top: 28,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
                  child: UserAvatar(name: u.name, size: 72, imageUrl: u.photoUrl),
                ),
              ),
            ),
            Positioned(top: 6, right: 6, child: GestureDetector(onTap: () => onDismiss(u.id), child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: Color(0xCC1A1D24), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 14, color: Colors.white)))),
          ]),
          const SizedBox(height: 44),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(children: [
              Text(u.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(u.college ?? '', style: TextStyle(fontSize: 11, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.people_rounded, size: 12, color: muted),
                const SizedBox(width: 3),
                Text('${u.connectionsCount}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ink)),
                Text(' • ', style: TextStyle(fontSize: 10, color: muted)),
                const Icon(Icons.stars_rounded, size: 12, color: Color(0xFFF59E0B)),
                const SizedBox(width: 3),
                Text('${u.points} pts', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ink)),
              ]),
            ]),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 34,
              child: OutlinedButton(
                onPressed: isPending ? null : () => onSend(u),
                style: OutlinedButton.styleFrom(side: BorderSide(color: isPending ? muted : AppColors.cyanDeep), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), foregroundColor: isPending ? ink : AppColors.cyanDeep),
                child: Text(isPending ? 'Pending' : 'Connect', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isPending ? ink : AppColors.cyanDeep)),
              ),
            ),
          ),
        ]),
      );
    },
  );
  }
}

class _CatchUpTab extends StatelessWidget {
  const _CatchUpTab();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1B1F2E) : Colors.white;
    return ListView(
    padding: const EdgeInsets.fromLTRB(16, 40, 16, 130),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? const Color(0xFF30364A) : const Color(0xFFE5E7EB))),
        child: Column(children: [
          const Icon(Icons.update_rounded, size: 40, color: Color(0xFF6B7280)),
          const SizedBox(height: 12),
          Text('Catch up with your network', style: AppTypography.soraHeading3()),
          const SizedBox(height: 6),
          Text('Updates from your connections will appear here', style: AppTypography.interCaption(), textAlign: TextAlign.center),
        ]),
      ),
    ],
  );
  }
}

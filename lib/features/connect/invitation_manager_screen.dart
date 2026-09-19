import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/user_avatar.dart';

class InvitationManagerScreen extends StatefulWidget {
  const InvitationManagerScreen({super.key});
  @override
  State<InvitationManagerScreen> createState() => _InvitationManagerScreenState();
}

class _InvitationManagerScreenState extends State<InvitationManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F2F2),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D24)), onPressed: () => context.pop()),
      title: Text('Invitation Manager', style: AppTypography.soraHeading3()),
      actions: [IconButton(icon: const Icon(Icons.settings_rounded, color: Color(0xFF6B7280)), onPressed: () {})],
      bottom: TabBar(
        controller: _tabCtrl,
        labelColor: const Color(0xFF0A6640),
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: const Color(0xFF0A6640),
        indicatorWeight: 3,
        tabs: const [Tab(text: 'Received'), Tab(text: 'Sent')],
      ),
    ),
    body: TabBarView(controller: _tabCtrl, children: const [_ReceivedTab(), _SentTab()]),
  );
}

class _ReceivedTab extends StatefulWidget {
  const _ReceivedTab();
  @override
  State<_ReceivedTab> createState() => _ReceivedTabState();
}

class _ReceivedTabState extends State<_ReceivedTab> {
  List<dynamic> _pending = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService().getPendingRequests();
      if (mounted) setState(() => _pending = list);
    } catch (_) {
      if (mounted) setState(() => _pending = []);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _respond(String id, String status) async {
    try {
      await ApiService().respondToConnection(id, status);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'accepted' ? 'Accepted ✓' : 'Rejected'), backgroundColor: status == 'accepted' ? AppColors.success : AppColors.inkSoft));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF0A6640), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Focused (${_pending.length})', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)), const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 18)]),
            ),
          ),
          if (_pending.isEmpty) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(children: [
                Image.network('https://cdn-icons-png.flaticon.com/512/7486/7486801.png', width: 180, height: 120, errorBuilder: (_, __, ___) => const Icon(Icons.mail_outline_rounded, size: 80, color: Color(0xFF6B7280))),
                const SizedBox(height: 16),
                Text('No new invitations', style: AppTypography.soraHeading2()),
              ]),
            ),
            Container(height: 8, color: const Color(0xFFE8E8E8)),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text('Suggestions for you', style: AppTypography.interButton(size: 14)),
            ),
            const _SuggestionsList(),
          ] else ...[
            Container(color: Colors.white, child: Column(children: _pending.map((item) {
              final m = item as Map<String, dynamic>;
              final req = m['requester'] is Map ? Map<String, dynamic>.from(m['requester'] as Map) : <String, dynamic>{};
              final name = (req['name'] ?? 'Unknown').toString();
              final id = m['id'].toString();
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Row(children: [
                  UserAvatar(name: name, size: 48, imageUrl: req['photo_url']?.toString()),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), Text((req['college'] ?? req['branch'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)), onPressed: () => _respond(id, 'rejected'), style: IconButton.styleFrom(side: const BorderSide(color: Color(0xFF6B7280)), shape: const CircleBorder())),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.check_rounded, color: Colors.white), onPressed: () => _respond(id, 'accepted'), style: IconButton.styleFrom(backgroundColor: const Color(0xFF0A66C2), shape: const CircleBorder())),
                ]),
              );
            }).toList())),
          ],
        ],
      ),
    );
  }
}

class _SuggestionsList extends StatefulWidget {
  const _SuggestionsList();
  @override
  State<_SuggestionsList> createState() => _SuggestionsListState();
}

class _SuggestionsListState extends State<_SuggestionsList> {
  List<dynamic> _users = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final res = await ApiService().discoverStudents();
      final list = (res['data'] as List?) ?? [];
      if (mounted) setState(() => _users = list.take(5).toList());
    } catch (_) { if (mounted) setState(() => _users = []); } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    if (_users.isEmpty) return const SizedBox();
    return Container(
      color: Colors.white,
      child: Column(children: _users.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final name = (m['name'] ?? '').toString();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(children: [
            UserAvatar(name: name, size: 48, imageUrl: m['photo_url']?.toString()),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), Text((m['college'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis), Row(children: [Container(width: 18, height: 18, decoration: const BoxDecoration(color: Color(0xFFE8E8E8), shape: BoxShape.circle), child: const Icon(Icons.people_rounded, size: 10, color: Color(0xFF6B7280))), const SizedBox(width: 4), const Text('mutual connections', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)))])])),
            OutlinedButton(onPressed: () async { final messenger = ScaffoldMessenger.of(context); try { await ApiService().sendConnectionRequest(m['id'].toString()); if (!mounted) return; messenger.showSnackBar(const SnackBar(content: Text('Request sent'))); } catch (e) { if (!mounted) return; messenger.showSnackBar(SnackBar(content: Text('Failed: $e'))); } }, style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0A66C2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Connect', style: TextStyle(color: Color(0xFF0A66C2), fontWeight: FontWeight.w700, fontSize: 12))),
          ]),
        );
      }).toList()),
    );
  }
}

class _SentTab extends StatefulWidget {
  const _SentTab();
  @override
  State<_SentTab> createState() => _SentTabState();
}

class _SentTabState extends State<_SentTab> {
  List<dynamic> _sent = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService().getSentRequests();
      if (mounted) setState(() => _sent = list);
    } catch (_) {
      if (mounted) setState(() => _sent = []);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF0A6640), borderRadius: BorderRadius.circular(20)),
              child: Text('People (${_sent.length})', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          if (_sent.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(children: [
                const Icon(Icons.send_outlined, size: 40, color: Color(0xFF6B7280)),
                const SizedBox(height: 12),
                Text('No sent invitations', style: AppTypography.soraHeading3()),
                Text('People you invited will appear here.\nYou can Withdraw pending requests.', style: AppTypography.interCaption(), textAlign: TextAlign.center),
              ]),
            )
          else
            ..._sent.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              final other = m['other_user'] is Map ? Map<String, dynamic>.from(m['other_user'] as Map) : (m['receiver'] is Map ? Map<String, dynamic>.from(m['receiver'] as Map) : m);
              final name = (other['name'] ?? m['name'] ?? 'Unknown').toString();
              final id = m['id'].toString();
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Row(children: [
                  UserAvatar(name: name, size: 52, imageUrl: other['photo_url']?.toString()),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)), Text((other['college'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis), const Text('Sent today', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))])),
                  TextButton(onPressed: () async { final messenger = ScaffoldMessenger.of(context); try { await ApiService().removeConnection(id); if (!mounted) return; messenger.showSnackBar(const SnackBar(content: Text('Withdrawn'), backgroundColor: AppColors.success)); _load(); } catch (e) { if (!mounted) return; messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error)); } }, child: const Text('Withdraw', style: TextStyle(color: Color(0xFF1A1D24), fontWeight: FontWeight.w700))),
                ]),
              );
            }),
        ],
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/user_avatar.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});
  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  List<dynamic> _connections = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_filter); }

  @override
  void dispose() { _searchCtrl.dispose(); _searchFocusNode.dispose(); super.dispose(); }

  Future<void> _ensureToken() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      final t = await u.getIdToken(true);
      if (t != null) ApiService().setToken(t);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _ensureToken();
      final list = await ApiService().getMyConnections();
      if (mounted) setState(() { _connections = list; _filtered = list; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) { setState(() => _filtered = _connections); return; }
    setState(() => _filtered = _connections.where((e) {
      final m = e as Map<String, dynamic>;
      final other = m['other_user'] is Map ? Map<String, dynamic>.from(m['other_user'] as Map) : <String, dynamic>{};
      final name = (other['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList());
  }

  Future<void> _remove(String id) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text('Remove connection?', style: AppTypography.soraHeading3()),
      content: Text('They will not be notified. You can connect again later.', style: AppTypography.interBody(color: AppColors.inkSoft)),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: AppColors.error)))],
    ));
    if (confirm != true) return;
    try {
      await _ensureToken();
      await ApiService().removeConnection(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed'), backgroundColor: AppColors.success));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  void _openChat(Map<String, dynamic> other) {
    final name = (other['name'] ?? 'Chat').toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chat with $name — Coming soon!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D24)), onPressed: () => context.pop()),
        title: Text('Connections', style: AppTypography.soraHeading3()),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Text('${_filtered.length} connections', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const Spacer(),
            IconButton(icon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6B7280)), onPressed: () => _searchFocusNode.requestFocus()),
            IconButton(icon: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF6B7280)), onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filter coming soon!')));
            }),
          ]),
        ),
        Container(height: 1, color: const Color(0xFFE5E7EB)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search connections',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF6B7280)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF6B7280)), const SizedBox(height: 8), Text('No connections yet', style: AppTypography.interCaption())]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Container(height: 1, color: const Color(0xFFE5E7EB)),
                        itemBuilder: (ctx, i) {
                          final item = _filtered[i] as Map<String, dynamic>;
                          final other = item['other_user'] is Map ? Map<String, dynamic>.from(item['other_user'] as Map) : <String, dynamic>{};
                          final name = (other['name'] ?? 'Unknown').toString();
                          final title = (other['branch'] ?? other['course'] ?? other['college'] ?? '').toString();
                          final photo = other['photo_url']?.toString();
                          final id = item['id'].toString();
                          final dateStr = item['updated_at'] ?? item['created_at'] ?? '';
                          String dateLabel = '';
                          try { final dt = DateTime.parse(dateStr.toString()); dateLabel = 'Connected on ${DateFormat('MMMM d, y').format(dt)}'; } catch (_) {}
                          return Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            child: Row(children: [
                              UserAvatar(name: name, size: 48, imageUrl: photo),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1D24)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF1A1D24)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (dateLabel.isNotEmpty) Text(dateLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                ]),
                              ),
                              IconButton(
                                icon: Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6B7280))), child: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF1A1D24))),
                                onPressed: () => _openChat(other),
                              ),
                              IconButton(icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF6B7280)), onPressed: () => _showOptions(id)),
                            ]),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  void _showOptions(String id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.person_remove_rounded, color: AppColors.error), title: const Text('Remove connection', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); _remove(id); }),
          ListTile(leading: const Icon(Icons.block_rounded, color: Color(0xFF6B7280)), title: const Text('Block'), onTap: () => Navigator.pop(context)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

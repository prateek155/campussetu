// lib/features/admin/admin_events_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../core/config/app_config.dart';
import '../../core/services/api_service.dart';
import 'add_event_screen.dart';
import 'widgets/admin_toast.dart';
import 'widgets/admin_event_registrations_sheet.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  static const _bg     = Color(0xFF080C14);
  static const _card   = Color(0xFF0D121E);
  static const _cardAlt= Color(0xFF141B2D);
  static const _border = Color(0xFF1E283D);
  static const _cyan   = Color(0xFF38BDF8);
  static const _green  = Color(0xFF10B981);
  static const _red    = Color(0xFFEF4444);
  static const _amber  = Color(0xFFF59E0B);
  static const _inkSoft= Color(0xFF94A3B8);

  List<dynamic> _events = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initToken().then((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initToken() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) ApiService().setToken(token);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getEvents();
      if (mounted) {
        setState(() {
          _events = data;
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

  Future<void> _deleteEvent(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: _red, size: 22),
            SizedBox(width: 8),
            Text('Delete Event', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text('Permanently remove "$name"? All registrations will also be deleted.', style: const TextStyle(color: _inkSoft, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _inkSoft))),
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
      await ApiService().deleteEvent(id);
      if (mounted) {
        AdminToast.success(context, 'Event deleted successfully');
        _load();
      }
    } catch (e) {
      if (mounted) AdminToast.error(context, 'Failed to delete event: $e');
    }
  }

  void _viewRegistrations(String id, String eventName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminEventRegistrationsSheet(
        eventId: id,
        eventName: eventName,
        onRegistrationsChanged: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _events.where((item) {
      final m = item is Map ? item : <String, dynamic>{};
      final name = (m['name'] ?? m['title'] ?? '').toString().toLowerCase();
      final place = (m['place'] ?? m['venue'] ?? '').toString().toLowerCase();
      final code = (m['event_code'] ?? m['eventCode'] ?? '').toString().toLowerCase();
      return query.isEmpty || name.contains(query) || place.contains(query) || code.contains(query);
    }).toList();

    final internalCount = _events.where((e) => (e is Map) && e['registration_mode'] == 'internal').length;
    final totalRegs = _events.fold<int>(0, (sum, e) {
      if (e is Map) {
        return sum + ((e['registration_count'] as num?)?.toInt() ?? 0);
      }
      return sum;
    });

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
                        child: const Icon(Icons.event_rounded, color: _cyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Event Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text('Create campus events, direct registration links & organizer logins', style: TextStyle(color: _inkSoft, fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Event', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        onPressed: () async {
                          final res = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => const AddEventScreen()),
                          );
                          if (res == true) _load();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metrics Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatBadge(label: 'Total Events', value: '${_events.length}', color: Colors.white),
                        const SizedBox(width: 8),
                        _StatBadge(label: 'Internal Reg.', value: '$internalCount', color: _cyan),
                        const SizedBox(width: 8),
                        _StatBadge(label: 'External Links', value: '${_events.length - internalCount}', color: _amber),
                        const SizedBox(width: 8),
                        _StatBadge(label: 'Total Attendees', value: '$totalRegs', color: _green),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Search bar
                  Container(
                    height: 40,
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search by event name, venue, or EVT code...',
                        hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Event List
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
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy_rounded, color: _inkSoft.withValues(alpha: 0.5), size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No events found', style: TextStyle(color: _inkSoft, fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (ctx, i) {
                                final e = Map<String, dynamic>.from(filtered[i] as Map);
                                final id = (e['_id'] ?? e['id'] ?? '').toString();
                                final name = (e['name'] ?? e['title'] ?? 'Untitled Event').toString();
                                return _buildEventCard(e, id, name);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, String id, String name) {
    final place = (event['place'] ?? event['venue'] ?? '').toString();
    final date = (event['time_date'] ?? event['date'] ?? event['time'] ?? '').toString();
    final link = (event['registration_link'] ?? event['link'] ?? '').toString();
    final pic = (event['picture_url'] ?? event['image_url'] ?? event['image'] ?? '').toString();
    final isInternal = event['registration_mode'] == 'internal';
    final registrationCount = (event['registration_count'] as num?)?.toInt() ?? 0;
    final eventCode = (event['event_code'] ?? event['eventCode'] ?? '').toString();
    final hasOrganizer = event['organizer_access_enabled'] == true || (event['organizer_id'] != null && event['organizer_id'].toString().isNotEmpty);
    final organizerId = (event['organizer_id'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image
          if (pic.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                pic,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tags
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isInternal ? _green : _amber).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isInternal ? 'INTERNAL REGISTRATION' : 'EXTERNAL LINK',
                        style: TextStyle(
                          color: isInternal ? _green : _amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (eventCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'ID: $eventCode',
                          style: const TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    const Spacer(),

                    // Edit button
                    IconButton(
                      tooltip: 'Edit Event',
                      icon: const Icon(Icons.edit_outlined, color: _cyan, size: 18),
                      onPressed: () async {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => AddEventScreen(event: event)),
                        );
                        if (res == true) _load();
                      },
                    ),

                    // Delete button
                    IconButton(
                      tooltip: 'Delete Event',
                      icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 18),
                      onPressed: () => _deleteEvent(id, name),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),

                if (place.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: _inkSoft, size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(place, style: const TextStyle(color: _inkSoft, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],

                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: _inkSoft, size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(date, style: const TextStyle(color: _inkSoft, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Shareable direct link & organizer status bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.link_rounded, color: _cyan, size: 16),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Direct Public Link (No Login Needed):',
                              style: TextStyle(color: _inkSoft, fontSize: 11),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              final codeOrId = eventCode.isNotEmpty ? eventCode : id;
                              final shareUrl = '${AppConfig.userWebBaseUrl}/events?code=$codeOrId';
                              Clipboard.setData(ClipboardData(text: shareUrl));
                              AdminToast.success(context, 'Direct share link copied: $shareUrl');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _cyan.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy_rounded, color: _cyan, size: 12),
                                  SizedBox(width: 4),
                                  Text('Copy Link', style: TextStyle(color: _cyan, fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasOrganizer) ...[
                        const Divider(color: _border, height: 16),
                        Row(
                          children: [
                            const Icon(Icons.badge_outlined, color: _green, size: 15),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Organizer ID: $organizerId (Access Protected)',
                                style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom actions for Internal Events
                if (isInternal) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$registrationCount Registered',
                          style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan.withValues(alpha: 0.15),
                          foregroundColor: _cyan,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.people_alt_rounded, size: 15),
                        label: const Text('Manage Registrations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        onPressed: () => _viewRegistrations(id, name),
                      ),
                    ],
                  ),
                ] else if (link.isNotEmpty) ...[
                  Text('External: $link', style: const TextStyle(color: _cyan, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

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
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

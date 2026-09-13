// lib/features/admin/admin_content_screen.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/router/app_router.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});
  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> with SingleTickerProviderStateMixin {
  static const _bg      = Color(0xFF0D0F1A);
  static const _card    = Color(0xFF141728);
  static const _border  = Color(0xFF252840);
  static const _cyan    = Color(0xFF3FD8F5);
  static const _green   = Color(0xFF22C55E);
  static const _red     = Color(0xFFEF4444);
  static const _orange  = Color(0xFFF59E0B);
  static const _purple  = Color(0xFFA855F7);
  static const _inkSoft = Color(0xFF9CA3AF);

  late TabController _tabCtrl;

  List _events    = [];
  List _deals     = [];
  List _flatmates = [];

  bool _loadingEvents    = true;
  bool _loadingDeals     = true;
  bool _loadingFlatmates = true;

  String? _eventsError;
  String? _dealsError;
  String? _flatmatesError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _initToken().then((_) {
      _loadEvents();
      _loadDeals();
      _loadFlatmates();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _initToken() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) ApiService().setToken(token);
    }
  }

  Future<void> _loadEvents() async {
    setState(() { _loadingEvents = true; _eventsError = null; });
    try {
      final data = await ApiService().getEvents();
      if (mounted) setState(() { _events = data; _loadingEvents = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingEvents = false; _eventsError = e.toString(); });
    }
  }

  Future<void> _loadDeals() async {
    setState(() { _loadingDeals = true; _dealsError = null; });
    try {
      final data = await ApiService().getDeals();
      if (mounted) setState(() { _deals = data; _loadingDeals = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingDeals = false; _dealsError = e.toString(); });
    }
  }

  Future<void> _loadFlatmates() async {
    setState(() { _loadingFlatmates = true; _flatmatesError = null; });
    try {
      final data = await ApiService().getAdminFlatmates();
      final raw = data['data'] ?? data['flatmates'] ?? data['items'] ?? data;
      if (mounted) setState(() { _flatmates = raw is List ? raw : []; _loadingFlatmates = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingFlatmates = false; _flatmatesError = e.toString(); });
    }
  }

  // ── Delete helpers ────────────────────────────────────────

  Future<void> _deleteEvent(String id, int index) async {
    if (!await _confirm('Delete Event', 'This event will be permanently removed.')) return;
    try {
      await ApiService().deleteEvent(id);
      if (mounted) { setState(() => _events.removeAt(index)); _snack('Event deleted', _green); }
    } catch (e) { if (mounted) _snack('Error: $e', _red); }
  }

  Future<void> _deleteDeal(String id, int index) async {
    if (!await _confirm('Delete Deal', 'This deal will be permanently removed.')) return;
    try {
      await ApiService().deleteDeal(id);
      if (mounted) { setState(() => _deals.removeAt(index)); _snack('Deal deleted', _green); }
    } catch (e) { if (mounted) _snack('Error: $e', _red); }
  }

  Future<void> _deleteFlatmate(String id, int index) async {
    if (!await _confirm('Remove Listing', 'This flatmate listing will be permanently removed.')) return;
    try {
      await ApiService().deleteAdminFlatmate(id);
      if (mounted) { setState(() => _flatmates.removeAt(index)); _snack('Listing removed', _green); }
    } catch (e) { if (mounted) _snack('Error: $e', _red); }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(color: Color(0xFF9CA3AF))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF)))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // Header + TabBar
          Container(
            decoration: BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Text('Content Management', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              TabBar(
                controller: _tabCtrl,
                labelColor: _cyan,
                unselectedLabelColor: _inkSoft,
                indicatorColor: _cyan,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Events'),
                  Tab(text: 'Deals'),
                  Tab(text: 'Flatmates'),
                ],
              ),
            ]),
          ),

          // Tab bodies
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── Events ──────────────────────────────────
                _ContentTab(
                  accentColor: _cyan,
                  icon: Icons.event_rounded,
                  emptyLabel: 'No events yet',
                  loading: _loadingEvents,
                  error: _eventsError,
                  onRefresh: _loadEvents,
                  onAdd: () async {
                    await context.push('/admin/add-event');
                    _loadEvents();
                  },
                  addLabel: 'Add Event',
                  body: _loadingEvents
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF3FD8F5)))
                      : _eventsError != null
                      ? _ErrorView(error: _eventsError!, onRetry: _loadEvents)
                      : _events.isEmpty
                      ? const _EmptyView(icon: Icons.event_outlined, message: 'No events published yet')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _events.length,
                          itemBuilder: (ctx, i) {
                            final e = Map<String, dynamic>.from(_events[i] as Map);
                            final id = (e['_id'] ?? e['id'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _EventCard(event: e, onDelete: () => _deleteEvent(id, i)),
                            ).animate(delay: (i * 30).ms).fadeIn(duration: 280.ms);
                          },
                        ),
                ),

                // ── Deals ───────────────────────────────────
                _ContentTab(
                  accentColor: _orange,
                  icon: Icons.local_offer_rounded,
                  emptyLabel: 'No deals yet',
                  loading: _loadingDeals,
                  error: _dealsError,
                  onRefresh: _loadDeals,
                  onAdd: () async {
                    await context.push(AppRoutes.adminAddDeal);
                    _loadDeals();
                  },
                  addLabel: 'Add Deal',
                  body: _loadingDeals
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF3FD8F5)))
                      : _dealsError != null
                      ? _ErrorView(error: _dealsError!, onRetry: _loadDeals)
                      : _deals.isEmpty
                      ? const _EmptyView(icon: Icons.local_offer_outlined, message: 'No deals posted yet')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _deals.length,
                          itemBuilder: (ctx, i) {
                            final d = Map<String, dynamic>.from(_deals[i] as Map);
                            final id = (d['_id'] ?? d['id'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _DealCard(deal: d, onDelete: () => _deleteDeal(id, i)),
                            ).animate(delay: (i * 30).ms).fadeIn(duration: 280.ms);
                          },
                        ),
                ),

                // ── Flatmates ────────────────────────────────
                _ContentTab(
                  accentColor: _purple,
                  icon: Icons.home_work_rounded,
                  emptyLabel: 'No listings yet',
                  loading: _loadingFlatmates,
                  error: _flatmatesError,
                  onRefresh: _loadFlatmates,
                  onAdd: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AddFlatmateSheet(onSubmitted: _loadFlatmates),
                    );
                  },
                  addLabel: 'Add Listing',
                  body: _loadingFlatmates
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF3FD8F5)))
                      : _flatmatesError != null
                      ? _ErrorView(error: _flatmatesError!, onRetry: _loadFlatmates)
                      : _flatmates.isEmpty
                      ? const _EmptyView(icon: Icons.home_outlined, message: 'No flatmate listings yet')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _flatmates.length,
                          itemBuilder: (ctx, i) {
                            final f = Map<String, dynamic>.from(_flatmates[i] as Map);
                            final id = (f['_id'] ?? f['id'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FlatmateCard(flatmate: f, onDelete: () => _deleteFlatmate(id, i)),
                            ).animate(delay: (i * 30).ms).fadeIn(duration: 280.ms);
                          },
                        ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Tab wrapper with FAB ─────────────────────────────────────

class _ContentTab extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String emptyLabel, addLabel;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onAdd;
  final Widget body;

  const _ContentTab({
    required this.accentColor,
    required this.icon,
    required this.emptyLabel,
    required this.addLabel,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onAdd,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          color: const Color(0xFF3FD8F5),
          backgroundColor: const Color(0xFF141728),
          onRefresh: onRefresh,
          child: body,
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(addLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Event Card ───────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onDelete;

  const _EventCard({required this.event, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const card   = Color(0xFF141728);
    const border = Color(0xFF252840);
    const cyan   = Color(0xFF3FD8F5);
    const red    = Color(0xFFEF4444);

    final name  = (event['name']              ?? event['title']         ?? 'Untitled Event').toString();
    final place = (event['place']             ?? event['venue']         ?? '').toString();
    final date  = (event['time_date']         ?? event['date']          ?? event['time'] ?? '').toString();
    final link  = (event['registration_link'] ?? event['link']          ?? '').toString();
    final pic   = (event['picture_url']       ?? event['image_url']     ?? event['image'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (pic.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(pic, height: 140, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.event_rounded, color: Color(0xFF3FD8F5), size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(name, style: const TextStyle(color: Color(0xFFE9EBEE), fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: red.withValues(alpha: 0.3))),
                  child: Icon(Icons.delete_outline_rounded, color: red, size: 15),
                ),
              ),
            ]),
            if (place.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF9CA3AF), size: 13),
                const SizedBox(width: 4),
                Expanded(child: Text(place, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (date.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time_rounded, color: Color(0xFF9CA3AF), size: 13),
                const SizedBox(width: 4),
                Expanded(child: Text(date, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (link.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: cyan.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: cyan.withValues(alpha: 0.2))),
                child: Text(link, style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Deal Card ────────────────────────────────────────────────

class _DealCard extends StatelessWidget {
  final Map<String, dynamic> deal;
  final VoidCallback onDelete;

  const _DealCard({required this.deal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const card   = Color(0xFF141728);
    const border = Color(0xFF252840);
    const orange = Color(0xFFF59E0B);
    const red    = Color(0xFFEF4444);

    final title    = (deal['title']        ?? 'Untitled Deal').toString();
    final desc     = (deal['description']  ?? '').toString();
    final code     = (deal['discount_code']?? deal['code']    ?? '').toString();
    final banner   = (deal['banner_url']   ?? deal['image']   ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (banner.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(banner, height: 120, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.local_offer_rounded, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(color: Color(0xFFE9EBEE), fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: red.withValues(alpha: 0.3))),
                  child: Icon(Icons.delete_outline_rounded, color: red, size: 15),
                ),
              ),
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (code.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.confirmation_num_outlined, color: orange, size: 13),
                    const SizedBox(width: 5),
                    Text(code, style: TextStyle(color: orange, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                  ]),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Flatmate Card ────────────────────────────────────────────

class _FlatmateCard extends StatelessWidget {
  final Map<String, dynamic> flatmate;
  final VoidCallback onDelete;

  const _FlatmateCard({required this.flatmate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const card   = Color(0xFF141728);
    const border = Color(0xFF252840);
    const purple = Color(0xFFA855F7);
    const red    = Color(0xFFEF4444);

    final name    = (flatmate['name']    ?? 'Unknown').toString();
    final place   = (flatmate['place']   ?? '').toString();
    final persons = (flatmate['persons'] ?? flatmate['num_persons'] ?? flatmate['count'] ?? '').toString();
    final contact = (flatmate['contact'] ?? flatmate['phone'] ?? '').toString();
    final desc    = (flatmate['description'] ?? '').toString();

    final photos = flatmate['photos'] is List ? flatmate['photos'] as List : [];

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (photos.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(photos.first.toString(), height: 130, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.home_work_rounded, color: Color(0xFFA855F7), size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(name, style: const TextStyle(color: Color(0xFFE9EBEE), fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: red.withValues(alpha: 0.3))),
                  child: Icon(Icons.delete_outline_rounded, color: red, size: 15),
                ),
              ),
            ]),
            if (place.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF9CA3AF), size: 13),
                const SizedBox(width: 4),
                Expanded(child: Text(place, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const SizedBox(height: 6),
            Row(children: [
              if (persons.isNotEmpty && persons != 'null') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_rounded, color: purple, size: 12),
                    const SizedBox(width: 4),
                    Text('$persons persons', style: TextStyle(color: purple, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 8),
              ],
              if (contact.isNotEmpty) ...[
                Icon(Icons.phone_rounded, color: const Color(0xFF9CA3AF), size: 13),
                const SizedBox(width: 4),
                Text(contact, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      SizedBox(
        height: 300,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: const Color(0xFF9CA3AF), size: 52),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
        ])),
      ),
    ]);
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      SizedBox(
        height: 300,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 12),
          const Text('Failed to load', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 15)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(error, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3FD8F5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3FD8F5).withValues(alpha: 0.4)),
              ),
              child: const Text('Retry', style: TextStyle(color: Color(0xFF3FD8F5), fontWeight: FontWeight.w600)),
            ),
          ),
        ])),
      ),
    ]);
  }
}

// ── Add Flatmate Sheet ───────────────────────────────────────
// Public so AdminDashboardScreen can also import and use it.

class AddFlatmateSheet extends StatefulWidget {
  final VoidCallback? onSubmitted;
  const AddFlatmateSheet({super.key, this.onSubmitted});

  @override
  State<AddFlatmateSheet> createState() => _AddFlatmateSheetState();
}

class _AddFlatmateSheetState extends State<AddFlatmateSheet> {
  static const _card    = Color(0xFF141728);
  static const _cardAlt = Color(0xFF1C2033);
  static const _border  = Color(0xFF252840);
  static const _purple  = Color(0xFFA855F7);
  static const _red     = Color(0xFFEF4444);
  static const _green   = Color(0xFF22C55E);
  static const _ink     = Color(0xFFE9EBEE);
  static const _inkSoft = Color(0xFF9CA3AF);

  final _nameCtrl    = TextEditingController();
  final _placeCtrl   = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  int _persons = 2;
  XFile? _photo1, _photo2;
  bool _loading = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _placeCtrl.dispose();
    _contactCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(int idx) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null && mounted) {
      setState(() {
        if (idx == 0) _photo1 = picked;
        else _photo2 = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Name is required', _red);
      return;
    }
    if (_placeCtrl.text.trim().isEmpty) {
      _snack('Place is required', _red);
      return;
    }
    if (_contactCtrl.text.trim().isEmpty) {
      _snack('Contact number is required', _red);
      return;
    }

    setState(() => _loading = true);
    try {
      final photos = [if (_photo1 != null) _photo1!.path, if (_photo2 != null) _photo2!.path];
      await ApiService().createFlatmate({
        'name': _nameCtrl.text.trim(),
        'place': _placeCtrl.text.trim(),
        'persons': _persons,
        'contact': _contactCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      }, photoPaths: photos.isNotEmpty ? photos : null);

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flatmate listing added!'), backgroundColor: Color(0xFF22C55E), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', _red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        decoration: const BoxDecoration(
          color: Color(0xFF141728),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 14, bottom: 6), width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.home_work_rounded, color: _purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Add Flatmate Listing', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 17, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: _border, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 16),
                ),
              ),
            ]),
          ),

          const Divider(color: Color(0xFF252840), height: 1),

          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Name
                _Label('Name *'),
                const SizedBox(height: 6),
                _Field(controller: _nameCtrl, hint: 'e.g. Rahul Sharma'),
                const SizedBox(height: 14),

                // Place
                _Label('Place / Area *'),
                const SizedBox(height: 6),
                _Field(controller: _placeCtrl, hint: 'e.g. Koramangala, Bangalore'),
                const SizedBox(height: 14),

                // Persons
                _Label('Number of Persons'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _cardAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () { if (_persons > 1) setState(() => _persons--); },
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.remove_rounded, color: Color(0xFF9CA3AF), size: 18),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('$_persons', style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 22, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () { if (_persons < 10) setState(() => _persons++); },
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: _purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.add_rounded, color: _purple, size: 18),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // Contact
                _Label('Contact Number *'),
                const SizedBox(height: 6),
                _Field(controller: _contactCtrl, hint: 'e.g. 9876543210', keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 14),

                // Description
                _Label('Description (Optional)'),
                const SizedBox(height: 6),
                _Field(controller: _descCtrl, hint: 'Share details about the accommodation, rent, etc.', maxLines: 3),
                const SizedBox(height: 18),

                // Photos
                const Text('Photos (Optional)', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(children: [
                  _PhotoPicker(photo: _photo1, onTap: () => _pickPhoto(0)),
                  const SizedBox(width: 12),
                  _PhotoPicker(photo: _photo2, onTap: () => _pickPhoto(1)),
                ]),
                const SizedBox(height: 24),

                // Submit
                GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: _loading ? _purple.withValues(alpha: 0.5) : _purple,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _loading ? [] : [BoxShadow(color: _purple.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Post Listing', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({required this.controller, required this.hint, this.maxLines = 1, this.keyboardType, this.inputFormatters});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF252840)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final XFile? photo;
  final VoidCallback onTap;

  const _PhotoPicker({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const border  = Color(0xFF252840);
    const purple  = Color(0xFFA855F7);
    const cardAlt = Color(0xFF1C2033);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: photo != null ? purple.withValues(alpha: 0.4) : border),
          ),
          clipBehavior: Clip.antiAlias,
          child: photo != null
              ? Stack(fit: StackFit.expand, children: [
                  Image.file(File(photo!.path), fit: BoxFit.cover),
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                    ),
                  ),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: purple, size: 28),
                  const SizedBox(height: 6),
                  const Text('Add photo', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                ]),
        ),
      ),
    );
  }
}

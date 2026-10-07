// lib/features/admin/admin_content_screen.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import 'add_deal_screen.dart';
import 'widgets/admin_toast.dart';
import 'widgets/admin_deal_redemptions_sheet.dart';
import '../jobs/services/jobs_module_service.dart';

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

  List _deals        = [];
  List _dealsHistory = [];
  List _flatmates    = [];

  bool _loadingDeals     = true;
  bool _loadingFlatmates = true;

  String? _dealsError;
  String? _flatmatesError;

  bool _isJobsModuleOpen = true;
  bool _isTogglingJobs = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadJobsModuleStatus();
    _initToken().then((_) {
      _loadDeals();
      _loadFlatmates();
    });
  }

  Future<void> _loadJobsModuleStatus() async {
    try {
      final open = await JobsModuleService.instance.getJobsStatus();
      if (mounted) setState(() => _isJobsModuleOpen = open);
    } catch (_) {}
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

  Future<void> _loadDeals() async {
    setState(() { _loadingDeals = true; _dealsError = null; });
    try {
      final res = await ApiService().getAdminDeals();
      if (mounted) {
        setState(() {
          _deals = (res['deals'] as List?) ?? [];
          _dealsHistory = (res['history'] as List?) ?? [];
          _loadingDeals = false;
        });
      }
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

  Future<void> _deleteDeal(String id, {bool permanent = false}) async {
    final title = permanent ? 'Permanently Delete Deal' : 'Delete Deal';
    final msg = permanent
        ? 'This deal and its historical records will be permanently deleted.'
        : 'This deal will be removed from the active student feed and logged into Published Deals History.';
    if (!await _confirm(title, msg)) return;
    try {
      await ApiService().deleteDeal(id, permanent: permanent);
      _loadDeals();
      _snack(permanent ? 'Deal permanently deleted' : 'Deal moved to history log', _green);
    } catch (e) {
      if (mounted) _snack('Error: $e', _red);
    }
  }

  Future<void> _restoreDeal(String id) async {
    try {
      await ApiService().restoreDeal(id);
      _loadDeals();
      _snack('Deal restored to active feed!', _green);
    } catch (e) {
      if (mounted) _snack('Error restoring deal: $e', _red);
    }
  }

  void _viewDealRedemptions(String id, String dealTitle, String discountCode) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminDealRedemptionsSheet(
        dealId: id,
        dealTitle: dealTitle,
        discountCode: discountCode,
      ),
    );
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
    if (bg == _green) {
      AdminToast.success(context, msg);
    } else {
      AdminToast.error(context, msg);
    }
  }

  Widget _buildJobsKillswitchCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isJobsModuleOpen
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : const Color(0xFFEF4444).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (_isJobsModuleOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isJobsModuleOpen ? Icons.work_rounded : Icons.work_off_rounded,
              color: _isJobsModuleOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Student Jobs Section', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_isJobsModuleOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _isJobsModuleOpen ? 'ACTIVE' : 'HIDDEN',
                        style: TextStyle(
                          color: _isJobsModuleOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _isJobsModuleOpen ? 'Students can view & apply for jobs' : 'Jobs section is turned off for all students',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _isTogglingJobs
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
              : Switch.adaptive(
                  value: _isJobsModuleOpen,
                  activeThumbColor: const Color(0xFF10B981),
                  activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                  inactiveThumbColor: const Color(0xFFEF4444),
                  inactiveTrackColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  onChanged: (val) async {
                    setState(() => _isTogglingJobs = true);
                    try {
                      await JobsModuleService.instance.setJobsStatus(val);
                      if (mounted) {
                        setState(() {
                          _isJobsModuleOpen = val;
                          _isTogglingJobs = false;
                        });
                        if (val) {
                          AdminToast.success(context, 'Jobs section enabled for students!');
                        } else {
                          AdminToast.warning(context, 'Jobs section hidden. Task Board remains active!');
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isTogglingJobs = false);
                        AdminToast.error(context, 'Failed to update jobs status: $e');
                      }
                    }
                  },
                ),
        ],
      ),
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
            decoration: const BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('Deals & Flatmates', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              _buildJobsKillswitchCard(),
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
                  Tab(text: 'Deals & Offers'),
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
                // ── Deals ───────────────────────────────────
                _ContentTab(
                  accentColor: _orange,
                  icon: Icons.local_offer_rounded,
                  emptyLabel: 'No deals yet',
                  loading: _loadingDeals,
                  error: _dealsError,
                  onRefresh: _loadDeals,
                  onAdd: () async {
                    final res = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const AddDealScreen()),
                    );
                    if (res == true) _loadDeals();
                  },
                  addLabel: 'Add Deal',
                  body: _loadingDeals
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF3FD8F5)))
                      : _dealsError != null
                      ? _ErrorView(error: _dealsError!, onRetry: _loadDeals)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bolt_rounded, color: _orange, size: 18),
                                const SizedBox(width: 8),
                                const Text('Active Deals', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: _orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${_deals.length}', style: const TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_deals.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: _EmptyView(icon: Icons.local_offer_outlined, message: 'No active deals posted yet'),
                              )
                            else
                              ..._deals.asMap().entries.map((entry) {
                                final i = entry.key;
                                final d = Map<String, dynamic>.from(entry.value as Map);
                                final id = (d['_id'] ?? d['id'] ?? '').toString();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DealCard(
                                    deal: d,
                                    onEdit: () async {
                                      final res = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(builder: (_) => AddDealScreen(deal: d)),
                                      );
                                      if (res == true) _loadDeals();
                                    },
                                    onDelete: () => _deleteDeal(id, permanent: false),
                                    onViewRedemptions: () => _viewDealRedemptions(
                                      id,
                                      (d['title'] ?? 'Deal').toString(),
                                      (d['discount_code'] ?? d['code'] ?? '').toString(),
                                    ),
                                  ),
                                ).animate(delay: (i * 25).ms).fadeIn(duration: 250.ms);
                              }),

                            const SizedBox(height: 24),
                            const Divider(color: _border),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                const Icon(Icons.history_rounded, color: _inkSoft, size: 18),
                                const SizedBox(width: 8),
                                const Text('Published Deals History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(10)),
                                  child: Text('${_dealsHistory.length}', style: const TextStyle(color: _inkSoft, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Deleted deals are preserved here. You can restore them to active status anytime.', style: TextStyle(color: _inkSoft, fontSize: 12)),
                            const SizedBox(height: 12),

                            if (_dealsHistory.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: Text('No historical deleted deals yet', style: TextStyle(color: _inkSoft, fontSize: 13))),
                              )
                            else
                              ..._dealsHistory.map((item) {
                                final d = Map<String, dynamic>.from(item as Map);
                                final id = (d['_id'] ?? d['id'] ?? '').toString();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DealHistoryCard(
                                    deal: d,
                                    onRestore: () => _restoreDeal(id),
                                    onPermanentDelete: () => _deleteDeal(id, permanent: true),
                                    onViewRedemptions: () => _viewDealRedemptions(
                                      id,
                                      (d['title'] ?? 'Archived Deal').toString(),
                                      (d['discount_code'] ?? d['code'] ?? '').toString(),
                                    ),
                                  ),
                                );
                              }),
                          ],
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

// ── Deal Card ────────────────────────────────────────────────

class _DealCard extends StatelessWidget {
  final Map<String, dynamic> deal;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onViewRedemptions;

  const _DealCard({
    required this.deal,
    required this.onDelete,
    this.onEdit,
    this.onViewRedemptions,
  });

  @override
  Widget build(BuildContext context) {
    const card   = Color(0xFF141728);
    const border = Color(0xFF252840);
    const orange = Color(0xFFF59E0B);
    const red    = Color(0xFFEF4444);
    const cyan   = Color(0xFF3FD8F5);

    final title    = (deal['title']        ?? 'Untitled Deal').toString();
    final desc     = (deal['description']  ?? '').toString();
    final code     = (deal['discount_code']?? deal['code']    ?? '').toString();
    final banner   = (deal['banner_url']   ?? deal['image']   ?? '').toString();
    final city     = (deal['city']         ?? '').toString().trim();
    final state    = (deal['state']        ?? '').toString().trim();
    final redemptionsCount = (deal['redemptions_count'] as num?)?.toInt() ?? 0;

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
              if (onEdit != null) ...[
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cyan.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.edit_outlined, color: cyan, size: 15),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: red.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: red, size: 15),
                ),
              ),
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(children: [
              if (code.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: orange.withValues(alpha: 0.3))),
                  child: Text('Code: $code', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              if (city.isNotEmpty || state.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text([city, state].where((s) => s.isNotEmpty).join(', '),
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), overflow: TextOverflow.ellipsis),
                ),
              ],
              if (onViewRedemptions != null)
                TextButton.icon(
                  onPressed: onViewRedemptions,
                  icon: const Icon(Icons.receipt_long_rounded, color: cyan, size: 14),
                  label: Text('$redemptionsCount claimed', style: const TextStyle(color: cyan, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Deal History Card ────────────────────────────────────────

class _DealHistoryCard extends StatelessWidget {
  final Map<String, dynamic> deal;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;
  final VoidCallback? onViewRedemptions;

  const _DealHistoryCard({
    required this.deal,
    required this.onRestore,
    required this.onPermanentDelete,
    this.onViewRedemptions,
  });

  @override
  Widget build(BuildContext context) {
    final title = (deal['title'] ?? 'Archived Deal').toString();
    final desc = (deal['description'] ?? '').toString();
    final code = (deal['discount_code'] ?? deal['code'] ?? '').toString();
    final redemptionsCount = (deal['redemptions_count'] as num?)?.toInt() ?? 0;
    final deletedAt = deal['deleted_at']?.toString();
    String deletedDateStr = '';
    if (deletedAt != null && deletedAt.isNotEmpty) {
      final dt = DateTime.tryParse(deletedAt);
      if (dt != null) deletedDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101322),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2238)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: const Text('DELETED', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ]),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        Row(children: [
          if (code.isNotEmpty) Text('Code: $code   •   ', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          Text('$redemptionsCount claims recorded', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ]),
        if (deletedDateStr.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('Deleted: $deletedDateStr', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (onViewRedemptions != null)
            TextButton.icon(
              onPressed: onViewRedemptions,
              icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF38BDF8)),
              label: const Text('View Claims', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.replay_rounded, size: 14, color: Color(0xFF10B981)),
            label: const Text('Restore', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Permanent Delete',
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
            onPressed: onPermanentDelete,
          ),
        ]),
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

    final name    = (flatmate['name']           ?? 'Unnamed').toString();
    final place   = (flatmate['place']          ?? '').toString();
    final persons = (flatmate['num_persons']    ?? 1).toString();
    final contact = (flatmate['contact_number'] ?? '').toString();
    final desc    = (flatmate['description']    ?? '').toString();
    final p1      = (flatmate['photo_url_1']    ?? '').toString();
    final p2      = (flatmate['photo_url_2']    ?? '').toString();
    final photos  = [p1, p2].where((p) => p.isNotEmpty).toList();

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (photos.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(10),
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(photos[i], width: 140, height: 100, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
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
                  decoration: BoxDecoration(
                    color: red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: red.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: red, size: 15),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('$persons Person${persons == "1" ? "" : "s"}', style: const TextStyle(color: Color(0xFFA855F7), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              if (contact.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.phone_outlined, color: Color(0xFF9CA3AF), size: 13),
                const SizedBox(width: 4),
                Text(contact, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Add Flatmate BottomSheet ─────────────────────────────────

class AddFlatmateSheet extends StatefulWidget {
  final VoidCallback onSubmitted;
  const AddFlatmateSheet({super.key, required this.onSubmitted});

  @override
  State<AddFlatmateSheet> createState() => _AddFlatmateSheetState();
}

class _AddFlatmateSheetState extends State<AddFlatmateSheet> {
  static const _card    = Color(0xFF141728);
  static const _cardAlt = Color(0xFF1C2033);
  static const _border  = Color(0xFF252840);
  static const _purple  = Color(0xFFA855F7);

  final _nameCtrl    = TextEditingController();
  final _placeCtrl   = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  int _persons = 1;
  XFile? _photo1, _photo2;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _placeCtrl.dispose();
    _contactCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(int slot) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (photo != null) {
      setState(() {
        if (slot == 0) _photo1 = photo;
        else _photo2 = photo;
      });
    }
  }

  Future<void> _submit() async {
    final name    = _nameCtrl.text.trim();
    final place   = _placeCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    final desc    = _descCtrl.text.trim();

    if (name.isEmpty || place.isEmpty || contact.isEmpty) {
      AdminToast.error(context, 'Name, place and contact are required');
      return;
    }

    setState(() => _loading = true);
    try {
      final paths = [_photo1?.path, _photo2?.path].whereType<String>().toList();
      await ApiService().createFlatmate({
        'name': name,
        'place': place,
        'num_persons': _persons,
        'contact_number': contact,
        'description': desc,
      }, photoPaths: paths.isNotEmpty ? paths : null);

      if (mounted) {
        Navigator.pop(context);
        AdminToast.success(context, 'Flatmate listing added');
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) AdminToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(children: [
              const Text('Add Flatmate Listing', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 20), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(color: _border, height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Listing Name / Title *'),
                const SizedBox(height: 6),
                _Field(controller: _nameCtrl, hint: 'e.g. 2BHK Near Campus - 1 Room Available'),
                const SizedBox(height: 14),

                const _Label('Location / Address *'),
                const SizedBox(height: 6),
                _Field(controller: _placeCtrl, hint: 'e.g. Sector 14, Near Metro Station'),
                const SizedBox(height: 14),

                const _Label('Number of Persons Needed'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        child: const Icon(Icons.add_rounded, color: _purple, size: 18),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                const _Label('Contact Number *'),
                const SizedBox(height: 6),
                _Field(controller: _contactCtrl, hint: 'e.g. 9876543210', keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 14),

                const _Label('Description (Optional)'),
                const SizedBox(height: 6),
                _Field(controller: _descCtrl, hint: 'Share details about the accommodation, rent, etc.', maxLines: 3),
                const SizedBox(height: 18),

                const Text('Photos (Optional)', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(children: [
                  _PhotoPicker(photo: _photo1, onTap: () => _pickPhoto(0)),
                  const SizedBox(width: 12),
                  _PhotoPicker(photo: _photo2, onTap: () => _pickPhoto(1)),
                ]),
                const SizedBox(height: 24),

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
              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: purple, size: 28),
                  SizedBox(height: 6),
                  Text('Add photo', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                ]),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF252840), size: 48),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
        const SizedBox(height: 10),
        Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Try Again', style: TextStyle(color: Color(0xFF3FD8F5)))),
      ]),
    );
  }
}

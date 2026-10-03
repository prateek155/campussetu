// lib/features/admin/admin_points_transfers_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import 'widgets/admin_toast.dart';

class AdminPointsTransfersScreen extends StatefulWidget {
  const AdminPointsTransfersScreen({super.key});

  @override
  State<AdminPointsTransfersScreen> createState() => _AdminPointsTransfersScreenState();
}

class _AdminPointsTransfersScreenState extends State<AdminPointsTransfersScreen> {
  static const _bg        = Color(0xFF080C14);
  static const _card      = Color(0xFF0D121E);
  static const _cardAlt   = Color(0xFF13192A);
  static const _border    = Color(0xFF172033);
  static const _cyan      = Color(0xFF38BDF8);
  static const _green     = Color(0xFF10B981);
  static const _purple    = Color(0xFF818CF8);
  static const _textMuted = Color(0xFF64748B);
  static const _textLight = Color(0xFF94A3B8);

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _transfers = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  final int _limit = 30;
  int _totalCount = 0;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _fetchTransfers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTransfers({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getAdminPointsTransfers(
        page: _page,
        limit: _limit,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
      );

      final rawList = res['transfers'];
      final pagination = res['pagination'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _transfers = rawList is List
              ? rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
          _totalCount = pagination?['total'] ?? _transfers.length;
          _totalPoints = pagination?['total_points'] ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
        AdminToast.error(context, 'Failed to load transfers: $e');
      }
    }
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                color: _card,
                border: Border(bottom: BorderSide(color: _border, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: _green, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student Points Transfers',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Real-time audit log of peer-to-peer points transfers between students',
                              style: TextStyle(color: _textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh_rounded, color: _textLight, size: 20),
                        onPressed: () => _fetchTransfers(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stat Badges
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                        icon: Icons.receipt_long_rounded,
                        label: 'Total Transfers',
                        value: '$_totalCount',
                        color: _cyan,
                      ),
                      _StatChip(
                        icon: Icons.stars_rounded,
                        label: 'Total Points Transferred',
                        value: '$_totalPoints pts',
                        color: _green,
                      ),
                      if (_transfers.isNotEmpty)
                        _StatChip(
                          icon: Icons.people_outline_rounded,
                          label: 'Loaded on Page',
                          value: '${_transfers.length}',
                          color: _purple,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search input
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: _cardAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onSubmitted: (_) => _fetchTransfers(resetPage: true),
                            decoration: InputDecoration(
                              hintText: 'Search by student name, email, or Campus ID...',
                              hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, color: _textMuted, size: 18),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: _textMuted, size: 16),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _fetchTransfers(resetPage: true);
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _fetchTransfers(resetPage: true),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Filter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Main Content Area ─────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _cyan, strokeWidth: 2.5),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
                              const SizedBox(height: 12),
                              Text('Failed to load transfers: $_error', style: const TextStyle(color: _textLight, fontSize: 13)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _fetchTransfers(),
                                style: ElevatedButton.styleFrom(backgroundColor: _cyan, foregroundColor: Colors.black),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _transfers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: _cardAlt,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.swap_horiz_rounded, color: _textMuted, size: 30),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'No points transfers found',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Transfers between students will automatically appear here.',
                                    style: TextStyle(color: _textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _transfers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final item = _transfers[i];
                                return _TransferCard(
                                  item: item,
                                  isDesktop: isDesktop,
                                  formattedTime: _formatDateTime(item['created_at']),
                                ).animate(delay: (i * 20).ms).fadeIn(duration: 250.ms);
                              },
                            ),
            ),

            // ── Pagination Footer ─────────────────────────────────────
            if (_totalCount > _limit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(
                  color: _card,
                  border: Border(top: BorderSide(color: _border, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page $_page of ${((_totalCount - 1) / _limit).floor() + 1} ($_totalCount total)',
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: _page > 1 ? _textLight : _textMuted.withValues(alpha: 0.3),
                          onPressed: _page > 1
                              ? () {
                                  setState(() => _page--);
                                  _fetchTransfers();
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: (_page * _limit) < _totalCount
                              ? _textLight
                              : _textMuted.withValues(alpha: 0.3),
                          onPressed: (_page * _limit) < _totalCount
                              ? () {
                                  setState(() => _page++);
                                  _fetchTransfers();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDesktop;
  final String formattedTime;

  const _TransferCard({
    required this.item,
    required this.isDesktop,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    const cardAlt   = Color(0xFF0D121E);
    const border    = Color(0xFF172033);
    const green     = Color(0xFF10B981);
    const textMuted = Color(0xFF64748B);

    final senderName     = (item['sender_name'] ?? 'Unknown Student').toString();
    final senderCampusId = (item['sender_campus_id'] ?? '').toString();
    final senderEmail    = (item['sender_email'] ?? '').toString();

    final receiverName     = (item['receiver_name'] ?? 'Unknown Student').toString();
    final receiverCampusId = (item['receiver_campus_id'] ?? '').toString();
    final receiverEmail    = (item['receiver_email'] ?? '').toString();

    final amount = item['amount']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Points Badge + Timestamp + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: green),
                    const SizedBox(width: 4),
                    Text(
                      '$amount Points',
                      style: const TextStyle(
                        color: green,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: textMuted),
                  const SizedBox(width: 4),
                  Text(formattedTime, style: const TextStyle(color: textMuted, fontSize: 11)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SUCCESS',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: border, height: 1),
          const SizedBox(height: 12),

          // Transfer Flow Row: [Sender] -> [Arrow] -> [Receiver]
          Row(
            children: [
              // Sender info
              Expanded(
                child: _StudentInfoBlock(
                  label: 'SENDER (FROM)',
                  name: senderName,
                  campusId: senderCampusId,
                  email: senderEmail,
                  accentColor: const Color(0xFFF59E0B),
                ),
              ),

              // Direction arrow
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13192A),
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF38BDF8), size: 16),
              ),

              // Receiver info
              Expanded(
                child: _StudentInfoBlock(
                  label: 'RECEIVER (TO)',
                  name: receiverName,
                  campusId: receiverCampusId,
                  email: receiverEmail,
                  accentColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentInfoBlock extends StatelessWidget {
  final String label;
  final String name;
  final String campusId;
  final String email;
  final Color accentColor;

  const _StudentInfoBlock({
    required this.label,
    required this.name,
    required this.campusId,
    required this.email,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        if (campusId.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  campusId,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            email,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

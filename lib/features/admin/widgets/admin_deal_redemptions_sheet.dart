import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../services/deal_redemptions_export_service.dart';

class AdminDealRedemptionsSheet extends StatefulWidget {
  final String dealId;
  final String dealTitle;
  final String discountCode;

  const AdminDealRedemptionsSheet({
    super.key,
    required this.dealId,
    required this.dealTitle,
    required this.discountCode,
  });

  @override
  State<AdminDealRedemptionsSheet> createState() => _AdminDealRedemptionsSheetState();
}

class _AdminDealRedemptionsSheetState extends State<AdminDealRedemptionsSheet> {
  static const _bg = Color(0xFF0D0F1A);
  static const _card = Color(0xFF141728);
  static const _border = Color(0xFF252840);
  static const _orange = Color(0xFFF59E0B);
  static const _cyan = Color(0xFF3FD8F5);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _textMain = Color(0xFFE9EBEE);
  static const _textSub = Color(0xFF9CA3AF);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _redemptions = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRedemptions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRedemptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getDealRedemptions(widget.dealId);
      final raw = res['redemptions'];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _redemptions = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRedemptions {
    if (_searchQuery.trim().isEmpty) return _redemptions;
    final q = _searchQuery.toLowerCase().trim();

    return _redemptions.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final email = (r['email'] ?? '').toString().toLowerCase();
      final campusId = (r['campus_id'] ?? '').toString().toLowerCase();
      final dealCode = (r['deal_code'] ?? '').toString().toLowerCase();
      final college = (r['college'] ?? '').toString().toLowerCase();

      return name.contains(q) ||
          email.contains(q) ||
          campusId.contains(q) ||
          dealCode.contains(q) ||
          college.contains(q);
    }).toList();
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateVal.toString();
    }
  }

  void _showSnack(String msg, {Color color = _orange}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _exportData(DealExportFormat format) async {
    if (_redemptions.isEmpty) {
      _showSnack('No redemptions to export', color: _orange);
      return;
    }

    try {
      _showSnack('Preparing ${format == DealExportFormat.excel ? 'Excel' : 'PDF'} export...', color: _orange);
      final fileName = await DealRedemptionsExportService.exportAndDownload(
        dealTitle: widget.dealTitle,
        discountCode: widget.discountCode,
        redemptions: _redemptions,
        format: format,
      );
      _showSnack('Saved: $fileName', color: _green);
    } catch (e) {
      _showSnack('Export failed: $e', color: _red);
    }
  }

  Widget _buildRedemptionCard(Map<String, dynamic> r) {
    final name = (r['name'] ?? 'Student').toString();
    final email = (r['email'] ?? '').toString();
    final campusId = (r['campus_id'] ?? '').toString();
    final dealCode = (r['deal_code'] ?? '').toString();
    final college = (r['college'] ?? '').toString();
    final branch = (r['branch'] ?? '').toString();
    final redeemedAt = _formatDate(r['redeemed_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _orange.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: _orange, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: _textMain, fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(color: _textSub, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Redeemed Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: _green, size: 12),
                      SizedBox(width: 4),
                      Text('Redeemed', style: TextStyle(color: _green, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 10),

            // Codes and College Row
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (dealCode.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: dealCode));
                      _showSnack('Copied deal code: $dealCode');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _orange.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_num_outlined, color: _orange, size: 12),
                          const SizedBox(width: 4),
                          Text('Code: $dealCode', style: const TextStyle(color: _orange, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ),

                if (campusId.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _cyan.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, color: _cyan, size: 12),
                        const SizedBox(width: 4),
                        Text('ID: $campusId', style: const TextStyle(color: _cyan, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                if (college.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_outlined, color: _textSub, size: 12),
                      const SizedBox(width: 4),
                      Text(college, style: const TextStyle(color: _textSub, fontSize: 11)),
                    ],
                  ),

                if (branch.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category_outlined, color: _textSub, size: 12),
                      const SizedBox(width: 4),
                      Text(branch, style: const TextStyle(color: _textSub, fontSize: 11)),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, color: _textSub, size: 12),
                const SizedBox(width: 4),
                Text('Redeemed: $redeemedAt', style: const TextStyle(color: _textSub, fontSize: 10.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRedemptions;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_offer_rounded, color: _orange, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.dealTitle,
                            style: const TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_redemptions.length} Students Redeemed${widget.discountCode.isNotEmpty ? ' · Promo: ${widget.discountCode}' : ''}',
                            style: const TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _textSub),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Toolbar: Export Excel & PDF
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, color: _green, size: 16),
                        label: const Text('Export Excel (.xlsx)', style: TextStyle(color: _textMain, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _green.withValues(alpha: 0.08),
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _exportData(DealExportFormat.excel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: _cyan, size: 16),
                        label: const Text('Export PDF Report', style: TextStyle(color: _textMain, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _cyan.withValues(alpha: 0.08),
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _exportData(DealExportFormat.pdf),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Control
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: _card.withValues(alpha: 0.5),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: _textMain, fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by student name, campus ID, code, college...',
                hintStyle: const TextStyle(color: _textSub, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: _textSub, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: _textSub, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: _card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _orange)),
              ),
            ),
          ),

          // Redemptions List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _orange))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: _red, size: 36),
                            const SizedBox(height: 8),
                            Text('Could not load redemptions: $_error', style: const TextStyle(color: _red, fontSize: 12)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadRedemptions,
                              style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.black),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _redemptions.isEmpty ? Icons.redeem_outlined : Icons.search_off_rounded,
                                  color: _textSub,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _redemptions.isEmpty
                                      ? 'No students have redeemed this deal yet.'
                                      : 'No redemptions match your search criteria.',
                                  style: const TextStyle(color: _textSub, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: _orange,
                            onRefresh: _loadRedemptions,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) => _buildRedemptionCard(filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

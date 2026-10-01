// lib/features/admin/admin_ambassadors_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ambassador/models/campus_ambassador_model.dart';
import '../ambassador/services/campus_ambassador_service.dart';
import 'widgets/admin_toast.dart';

class AdminAmbassadorsScreen extends ConsumerStatefulWidget {
  const AdminAmbassadorsScreen({super.key});

  @override
  ConsumerState<AdminAmbassadorsScreen> createState() =>
      _AdminAmbassadorsScreenState();
}

class _AdminAmbassadorsScreenState extends ConsumerState<AdminAmbassadorsScreen> {
  // ── Palette matching the modern dark design ────────────────────────────────
  static const _bg = Color(0xFF090D16);
  static const _card = Color(0xFF0D121E);
  static const _cardAlt = Color(0xFF121725);
  static const _border = Color(0xFF1A2234);
  static const _cyan = Color(0xFF38BDF8);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF59E0B);
  static const _textMuted = Color(0xFF64748B);

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  AmbassadorStatus? _filterStatus;
  bool _isTogglingStatus = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final query = _searchCtrl.text.trim();
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    ref.invalidate(adminAmbassadorsStreamProvider);
    ref.invalidate(ambassadorProgramStatusProvider);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isProgramOpenAsync = ref.watch(ambassadorProgramStatusProvider);
    final isProgramOpen = isProgramOpenAsync.value ?? false;

    final applicationsAsync = ref.watch(adminAmbassadorsStreamProvider);
    final allApplications = applicationsAsync.value ?? <CampusAmbassadorModel>[];
    final isLoading = applicationsAsync.isLoading && allApplications.isEmpty;
    final hasError = applicationsAsync.hasError && allApplications.isEmpty;

    final pendingCount = allApplications
        .where((a) => a.status == AmbassadorStatus.pending)
        .length;
    final acceptedCount = allApplications
        .where((a) => a.status == AmbassadorStatus.accepted)
        .length;
    final rejectedCount = allApplications
        .where((a) => a.status == AmbassadorStatus.rejected)
        .length;
    final totalCount = allApplications.length;

    final filtered = allApplications.where((app) {
      if (_filterStatus != null && app.status != _filterStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = app.name.toLowerCase().contains(q);
        final matchCollege = app.collegeName.toLowerCase().contains(q);
        final matchDegree = app.degree.toLowerCase().contains(q);
        final matchPhone = app.phone.contains(q);
        return matchName || matchCollege || matchDegree || matchPhone;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              color: _cyan,
              backgroundColor: _card,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ── Header & Controls (ALWAYS VISIBLE IMMEDIATELY) ──────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title, Subtitle & Refresh Action
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Campus ambassadors',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Review student nominations and control who sees the program.',
                                      style: TextStyle(
                                        color: _textMuted,
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh data',
                                onPressed: _isRefreshing ? null : _handleRefresh,
                                icon: _isRefreshing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _cyan,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        color: _textMuted,
                                        size: 22,
                                      ),
                                style: IconButton.styleFrom(
                                  backgroundColor: _card,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: _border),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // ── Program Status Killswitch Card ──────────────────
                          _buildProgramStatusCard(isProgramOpen),

                          const SizedBox(height: 16),

                          // ── 3-Column Stats Row ──────────────────────────────
                          _buildStatsRow(
                            pending: pendingCount,
                            accepted: acceptedCount,
                            rejected: rejectedCount,
                            isLoading: isLoading,
                          ),

                          const SizedBox(height: 16),

                          // ── Search Bar ──────────────────────────────────────
                          _buildSearchBar(),

                          const SizedBox(height: 14),

                          // ── Filter Pills ────────────────────────────────────
                          _buildFilterPills(
                            pendingCount: pendingCount,
                            acceptedCount: acceptedCount,
                            rejectedCount: rejectedCount,
                            totalCount: totalCount,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Submissions Section ─────────────────────────────────────
                  if (isLoading)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildSkeletonCard(),
                          childCount: 3,
                        ),
                      ),
                    )
                  else if (hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.cloud_off_rounded,
                                color: _red,
                                size: 48,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Unable to load nominations',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${applicationsAsync.error ?? "Please check your network connection."}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _handleRefresh,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _cyan,
                                  foregroundColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(allApplications.isEmpty),
                    )
                  else if (!isWide)
                    // Mobile: 1 column
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final app = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildApplicantCard(app),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    )
                  else
                    // Desktop / Tablet: 2 columns pair-wise
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, rowIndex) {
                            final firstIdx = rowIndex * 2;
                            final secondIdx = firstIdx + 1;
                            final app1 = filtered[firstIdx];
                            final app2 = secondIdx < filtered.length
                                ? filtered[secondIdx]
                                : null;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildApplicantCard(app1)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: app2 != null
                                        ? _buildApplicantCard(app2)
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: (filtered.length / 2).ceil(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Killswitch Control Card ────────────────────────────────────────────────
  Widget _buildProgramStatusCard(bool isProgramOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isProgramOpen
              ? _green.withValues(alpha: 0.25)
              : _red.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          // Eye Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isProgramOpen
                  ? const Color(0xFF064E3B).withValues(alpha: 0.6)
                  : const Color(0xFF7F1D1D).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isProgramOpen
                    ? _green.withValues(alpha: 0.4)
                    : _red.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              isProgramOpen
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: isProgramOpen ? _green : _red,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Label & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isProgramOpen ? 'Program is open' : 'Program is paused',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isProgramOpen
                      ? 'Visible to students on Home screen & carousel'
                      : 'Card and banners are hidden from student app',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Toggle Switch
          _isTogglingStatus
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _green,
                  ),
                )
              : Switch.adaptive(
                  value: isProgramOpen,
                  activeColor: _green,
                  activeTrackColor: _green.withValues(alpha: 0.35),
                  inactiveThumbColor: _red,
                  inactiveTrackColor: _red.withValues(alpha: 0.35),
                  onChanged: (val) async {
                    setState(() => _isTogglingStatus = true);
                    try {
                      await CampusAmbassadorService.instance
                          .setProgramStatus(val);
                      ref.invalidate(ambassadorProgramStatusProvider);
                      if (mounted) {
                        if (val) {
                          AdminToast.success(context, 'Ambassador Program opened for students!');
                        } else {
                          AdminToast.warning(context, 'Ambassador Program paused and hidden from student app.');
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        AdminToast.error(context, 'Failed to update program status: $e');
                      }
                    } finally {
                      if (mounted) setState(() => _isTogglingStatus = false);
                    }
                  },
                ),
        ],
      ),
    );
  }

  // ── 3-Column Stats Row ─────────────────────────────────────────────────────
  Widget _buildStatsRow({
    required int pending,
    required int accepted,
    required int rejected,
    required bool isLoading,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statBox(
            label: 'Pending',
            value: isLoading ? '...' : pending.toString(),
            color: _orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statBox(
            label: 'Accepted',
            value: isLoading ? '...' : accepted.toString(),
            color: _green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statBox(
            label: 'Rejected',
            value: isLoading ? '...' : rejected.toString(),
            color: _red,
          ),
        ),
      ],
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search name, college, degree, phone',
          hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _textMuted,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: _textMuted, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  // ── Filter Pills ───────────────────────────────────────────────────────────
  Widget _buildFilterPills({
    required int pendingCount,
    required int acceptedCount,
    required int rejectedCount,
    required int totalCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterPill(
            label: 'Pending',
            count: pendingCount,
            status: AmbassadorStatus.pending,
            badgeColor: _orange,
          ),
          const SizedBox(width: 8),
          _filterPill(
            label: 'Accepted',
            count: acceptedCount,
            status: AmbassadorStatus.accepted,
            badgeColor: _green,
          ),
          const SizedBox(width: 8),
          _filterPill(
            label: 'Rejected',
            count: rejectedCount,
            status: AmbassadorStatus.rejected,
            badgeColor: _red,
          ),
          const SizedBox(width: 8),
          _filterPill(
            label: 'All',
            count: totalCount,
            status: null,
            badgeColor: _cyan,
          ),
        ],
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required int count,
    required AmbassadorStatus? status,
    required Color badgeColor,
  }) {
    final isSelected = _filterStatus == status;

    return InkWell(
      onTap: () => setState(() => _filterStatus = status),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _cardAlt : _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? badgeColor.withValues(alpha: 0.6) : _border,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : _textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? badgeColor.withValues(alpha: 0.25)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? badgeColor : _textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Applicant Card ─────────────────────────────────────────────────────────
  Widget _buildApplicantCard(CampusAmbassadorModel app) {
    Color statusColor;
    String statusLabel;

    switch (app.status) {
      case AmbassadorStatus.accepted:
        statusColor = _green;
        statusLabel = 'Accepted';
        break;
      case AmbassadorStatus.rejected:
        statusColor = _red;
        statusLabel = 'Rejected';
        break;
      case AmbassadorStatus.pending:
        statusColor = _orange;
        statusLabel = 'Pending';
        break;
    }

    final avatarColor = _getAvatarColor(app.name);
    final initial = app.name.trim().isNotEmpty
        ? app.name.trim()[0].toUpperCase()
        : 'S';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showStudentDetailSheet(app),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Name/College + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarColor.withValues(alpha: 0.25),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: avatarColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.collegeName.isNotEmpty
                              ? app.collegeName
                              : 'College Not Specified',
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status badge (dot + label)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Row 1: Degree & Year
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 15,
                    color: _textMuted,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Degree: ',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${app.degree.isNotEmpty ? app.degree : "N/A"}, Year ${app.currentYear.isNotEmpty ? app.currentYear : "1"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Row 2: Phone
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 15,
                    color: _textMuted,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Phone: ',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      app.phone.isNotEmpty ? app.phone : 'Not provided',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Action Buttons: Reject & Accept
              Row(
                children: [
                  // Reject Button
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          _updateStatus(app, AmbassadorStatus.rejected),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C1518),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _red.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          app.status == AmbassadorStatus.rejected
                              ? 'Rejected'
                              : 'Reject',
                          style: TextStyle(
                            color: app.status == AmbassadorStatus.rejected
                                ? _red.withValues(alpha: 0.7)
                                : const Color(0xFFF87171),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Accept Button (Cyan)
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          _updateStatus(app, AmbassadorStatus.accepted),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: app.status == AmbassadorStatus.accepted
                              ? _cyan.withValues(alpha: 0.7)
                              : _cyan,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          app.status == AmbassadorStatus.accepted
                              ? 'Accepted'
                              : 'Accept',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Skeleton Loader Card ───────────────────────────────────────────────────
  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 180,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F2E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Student Full Detail Modal ──────────────────────────────────────────────
  void _showStudentDetailSheet(CampusAmbassadorModel app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _StudentDetailSheet(
          app: app,
          onUpdateStatus: (newStatus) {
            Navigator.of(ctx).pop();
            _updateStatus(app, newStatus);
          },
          onMakeCall: () => _makeCall(app.phone),
          onWhatsApp: () => _openWhatsApp(app.phone, app.name),
        );
      },
    );
  }

  // ── Update Application Status ──────────────────────────────────────────────
  Future<void> _updateStatus(
    CampusAmbassadorModel app,
    AmbassadorStatus newStatus,
  ) async {
    try {
      await CampusAmbassadorService.instance.updateApplicationStatus(
        app.id,
        newStatus,
      );
      if (mounted) {
        final isAccepted = newStatus == AmbassadorStatus.accepted;
        final msg = '${app.name} application marked as ${isAccepted ? "Accepted" : "Rejected"}';
        if (isAccepted) {
          AdminToast.success(context, msg);
        } else {
          AdminToast.warning(context, msg);
        }
      }
    } catch (e) {
      if (mounted) {
        AdminToast.error(context, 'Failed to update status: $e');
      }
    }
  }

  // ── Helper Actions ─────────────────────────────────────────────────────────
  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: clean));
      if (mounted) {
        AdminToast.info(context, 'Phone copied: $clean');
      }
    }
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = Uri.encodeComponent(
      'Hello $name, this is regarding your Campus Ambassador application for CampusSetu.',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: clean));
      if (mounted) {
        AdminToast.info(context, 'Phone copied: $clean');
      }
    }
  }

  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isCompletelyEmpty
                  ? 'No Ambassador nominations yet'
                  : 'No nominations match your search or filter',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isCompletelyEmpty
                  ? 'Submissions from the student app will appear here in real time.'
                  : 'Try modifying your search query or reset the filter status.',
              style: const TextStyle(
                color: _textMuted,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF6366F1), // Indigo
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }
}

// ── Student Detail Bottom Sheet ──────────────────────────────────────────────
class _StudentDetailSheet extends StatelessWidget {
  final CampusAmbassadorModel app;
  final ValueChanged<AmbassadorStatus> onUpdateStatus;
  final VoidCallback onMakeCall;
  final VoidCallback onWhatsApp;

  const _StudentDetailSheet({
    required this.app,
    required this.onUpdateStatus,
    required this.onMakeCall,
    required this.onWhatsApp,
  });

  static const _sheetBg = Color(0xFF0D121E);
  static const _sheetCard = Color(0xFF121725);
  static const _sheetBorder = Color(0xFF1A2234);
  static const _cyan = Color(0xFF38BDF8);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF59E0B);
  static const _textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final appliedDateStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(app.createdAt);

    Color statusColor;
    String statusLabel;
    switch (app.status) {
      case AmbassadorStatus.accepted:
        statusColor = _green;
        statusLabel = 'Accepted';
        break;
      case AmbassadorStatus.rejected:
        statusColor = _red;
        statusLabel = 'Rejected';
        break;
      case AmbassadorStatus.pending:
        statusColor = _orange;
        statusLabel = 'Under Review';
        break;
    }

    final avatarColor = _getAvatarColor(app.name);
    final initial = app.name.trim().isNotEmpty
        ? app.name.trim()[0].toUpperCase()
        : 'S';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Profile Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: avatarColor.withValues(alpha: 0.25),
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: avatarColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.collegeName.isNotEmpty
                                  ? app.collegeName
                                  : 'College Not Specified',
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _textMuted,
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status & Applied Timestamp Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _sheetCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _sheetBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: $statusLabel',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          appliedDateStr,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Quick Action Buttons (Call / WhatsApp / Copy)
                  Row(
                    children: [
                      // Call
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onMakeCall,
                          icon: const Icon(Icons.phone_rounded,
                              size: 16, color: _green),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _green,
                            side: BorderSide(
                              color: _green.withValues(alpha: 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // WhatsApp
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onWhatsApp,
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 16, color: _cyan),
                          label: const Text('WhatsApp'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _cyan,
                            side: BorderSide(
                              color: _cyan.withValues(alpha: 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Copy Phone
                      IconButton(
                        tooltip: 'Copy details',
                        onPressed: () {
                          final text = '''
Campus Ambassador Nomination:
Name: ${app.name}
College: ${app.collegeName}
Degree: ${app.degree} (${app.currentYear})
Phone: ${app.phone}
Age: ${app.age}
Statement / Experience: ${app.previousExperience}
Status: ${app.status.label}
''';
                          Clipboard.setData(ClipboardData(text: text));
                          AdminToast.info(context, 'Student details copied to clipboard');
                        },
                        icon: const Icon(Icons.copy_rounded,
                            color: _textMuted, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: _sheetCard,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: _sheetBorder),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── Student Info Grid ──────────────────────────────────────
                  const Text(
                    'ACADEMIC & CONTACT INFO',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _sheetCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _sheetBorder),
                    ),
                    child: Column(
                      children: [
                        _detailRow(
                          Icons.school_outlined,
                          'College',
                          app.collegeName.isNotEmpty
                              ? app.collegeName
                              : 'Not provided',
                        ),
                        const Divider(color: _sheetBorder, height: 16),
                        _detailRow(
                          Icons.menu_book_outlined,
                          'Degree & Year',
                          '${app.degree.isNotEmpty ? app.degree : "N/A"} • Year ${app.currentYear.isNotEmpty ? app.currentYear : "N/A"}',
                        ),
                        const Divider(color: _sheetBorder, height: 16),
                        _detailRow(
                          Icons.phone_outlined,
                          'Phone Number',
                          app.phone.isNotEmpty ? app.phone : 'Not provided',
                        ),
                        const Divider(color: _sheetBorder, height: 16),
                        _detailRow(
                          Icons.cake_outlined,
                          'Age',
                          app.age.isNotEmpty ? '${app.age} yrs' : 'Not specified',
                        ),
                        const Divider(color: _sheetBorder, height: 16),
                        _detailRow(
                          Icons.fingerprint_rounded,
                          'User ID',
                          app.userId.isNotEmpty ? app.userId : app.id,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Student's Short Description / Experience ───────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.format_quote_rounded,
                        color: _cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "STUDENT'S STATEMENT & EXPERIENCE",
                        style: TextStyle(
                          color: _cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Written by student',
                          style: TextStyle(
                            color: _cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _cyan.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      app.previousExperience.trim().isNotEmpty
                          ? app.previousExperience.trim()
                          : 'The student did not provide any extra statement or previous experience with this application.',
                      style: TextStyle(
                        color: app.previousExperience.trim().isNotEmpty
                            ? const Color(0xFFE2E8F0)
                            : _textMuted,
                        fontSize: 13,
                        height: 1.5,
                        fontStyle: app.previousExperience.trim().isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),

                  if (app.reviewNote != null &&
                      app.reviewNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'ADMIN REMARKS',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _sheetCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _sheetBorder),
                      ),
                      child: Text(
                        app.reviewNote!,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Bottom Action Decision Buttons
                  Row(
                    children: [
                      // Reject
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              onUpdateStatus(AmbassadorStatus.rejected),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C1518),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _red.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'Reject Application',
                              style: TextStyle(
                                color: Color(0xFFF87171),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Accept
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              onUpdateStatus(AmbassadorStatus.accepted),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _cyan,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Accept as Ambassador',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _textMuted),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF6366F1), // Indigo
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }
}

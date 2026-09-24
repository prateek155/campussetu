// lib/features/admin/admin_ambassadors_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../ambassador/models/campus_ambassador_model.dart';
import '../ambassador/services/campus_ambassador_service.dart';

class AdminAmbassadorsScreen extends ConsumerStatefulWidget {
  const AdminAmbassadorsScreen({super.key});

  @override
  ConsumerState<AdminAmbassadorsScreen> createState() =>
      _AdminAmbassadorsScreenState();
}

class _AdminAmbassadorsScreenState extends ConsumerState<AdminAmbassadorsScreen> {
  static const _bg = Color(0xFF0D0F1A);
  static const _card = Color(0xFF141728);
  static const _border = Color(0xFF252840);
  static const _cyan = Color(0xFF3FD8F5);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF59E0B);

  String _searchQuery = '';
  AmbassadorStatus? _filterStatus;
  bool _isTogglingStatus = false;

  @override
  Widget build(BuildContext context) {
    final isProgramOpenAsync = ref.watch(ambassadorProgramStatusProvider);
    final isProgramOpen = isProgramOpenAsync.value ?? true;

    final applicationsAsync = ref.watch(adminAmbassadorsStreamProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Top Header ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Campus Ambassadors',
                                style: TextStyle(
                                  color: Color(0xFFE9EBEE),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Manage student nominations & visibility',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Killswitch Control Card ────────────────────────
                    _buildKillswitchCard(isProgramOpen),

                    const SizedBox(height: 16),

                    // ── Stats Summary Row ──────────────────────────────
                    applicationsAsync.when(
                      data: (list) => _buildStatsRow(list),
                      loading: () => const SizedBox(
                        height: 70,
                        child: Center(
                          child: CircularProgressIndicator(color: _orange),
                        ),
                      ),
                      error: (_, __) => const SizedBox(),
                    ),

                    const SizedBox(height: 16),

                    // ── Search & Filter Controls ───────────────────────
                    _buildSearchAndFilters(),
                  ],
                ),
              ),
            ),

            // ── Applicants List ────────────────────────────────────────
            applicationsAsync.when(
              data: (list) {
                final filtered = list.where((app) {
                  if (_filterStatus != null && app.status != _filterStatus) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchName = app.name.toLowerCase().contains(q);
                    final matchCollege =
                        app.collegeName.toLowerCase().contains(q);
                    final matchDegree = app.degree.toLowerCase().contains(q);
                    final matchPhone = app.phone.contains(q);
                    return matchName || matchCollege || matchDegree || matchPhone;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 48, color: Color(0xFF4B5563)),
                            const SizedBox(height: 12),
                            Text(
                              list.isEmpty
                                  ? 'No Ambassador applications yet'
                                  : 'No applications match your filter',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              list.isEmpty
                                  ? 'Submissions from the student app will appear here in real time.'
                                  : 'Try changing your search term or status filter.',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final app = filtered[index];
                        return _buildApplicantCard(app);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _orange),
                ),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Error loading applicants: $err',
                    style: const TextStyle(color: _red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Killswitch Control ──────────────────────────────────────────────────
  Widget _buildKillswitchCard(bool isProgramOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isProgramOpen
              ? _green.withValues(alpha: 0.3)
              : _red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isProgramOpen
                  ? _green.withValues(alpha: 0.15)
                  : _red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isProgramOpen ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: isProgramOpen ? _green : _red,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Program Status: ',
                      style: TextStyle(
                        color: Color(0xFFE9EBEE),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isProgramOpen ? 'ACTIVE (OPEN)' : 'PAUSED (CLOSED)',
                      style: TextStyle(
                        color: isProgramOpen ? _green : _red,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isProgramOpen
                      ? 'Visible to students on Home screen & carousel'
                      : 'Card and banners are hidden from student app',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _isTogglingStatus
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
                )
              : Switch.adaptive(
                  value: isProgramOpen,
                  activeThumbColor: _green,
                  activeTrackColor: _green.withValues(alpha: 0.3),
                  inactiveThumbColor: _red,
                  inactiveTrackColor: _red.withValues(alpha: 0.3),
                  onChanged: (val) async {
                    setState(() => _isTogglingStatus = true);
                    try {
                      await CampusAmbassadorService.instance.setProgramStatus(val);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val
                                ? 'Ambassador Program opened on user app!'
                                : 'Ambassador Program paused and hidden from user app.'),
                            backgroundColor: val ? _green : _orange,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update status: $e')),
                        );
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

  // ── Stats Summary Row ───────────────────────────────────────────────────
  Widget _buildStatsRow(List<CampusAmbassadorModel> list) {
    final total = list.length;
    final pending = list.where((e) => e.status == AmbassadorStatus.pending).length;
    final accepted = list.where((e) => e.status == AmbassadorStatus.accepted).length;
    final rejected = list.where((e) => e.status == AmbassadorStatus.rejected).length;

    return Row(
      children: [
        Expanded(child: _statCard('Total', total.toString(), _cyan)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Pending', pending.toString(), _orange)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Accepted', accepted.toString(), _green)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Rejected', rejected.toString(), _red)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search & Filter Controls ───────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search bar
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by student name, college, degree, phone...',
            hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFF6B7280), size: 18),
            filled: true,
            fillColor: _card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _orange, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All', null),
              const SizedBox(width: 8),
              _filterChip('Pending ⏳', AmbassadorStatus.pending, color: _orange),
              const SizedBox(width: 8),
              _filterChip('Accepted 🎉', AmbassadorStatus.accepted, color: _green),
              const SizedBox(width: 8),
              _filterChip('Rejected ❌', AmbassadorStatus.rejected, color: _red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, AmbassadorStatus? status, {Color? color}) {
    final isSelected = _filterStatus == status;
    final accent = color ?? _cyan;

    return InkWell(
      onTap: () => setState(() => _filterStatus = status),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.15) : _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accent : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? accent : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  // ── Applicant Card ──────────────────────────────────────────────────────
  Widget _buildApplicantCard(CampusAmbassadorModel app) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (app.status) {
      case AmbassadorStatus.accepted:
        statusColor = _green;
        statusText = 'ACCEPTED';
        statusIcon = Icons.check_circle_rounded;
        break;
      case AmbassadorStatus.rejected:
        statusColor = _red;
        statusText = 'REJECTED';
        statusIcon = Icons.cancel_rounded;
        break;
      case AmbassadorStatus.pending:
        statusColor = _orange;
        statusText = 'PENDING';
        statusIcon = Icons.hourglass_top_rounded;
        break;
    }

    final dateStr = DateFormat('dd MMM, yyyy').format(app.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, Status badge & Date
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Text(
                  app.name.isNotEmpty ? app.name[0].toUpperCase() : 'A',
                  style: TextStyle(
                    color: statusColor,
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
                        color: Color(0xFFE9EBEE),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Applied on $dateStr',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Detail grid / rows
          _applicantDetail(Icons.school_outlined, 'College', app.collegeName),
          _applicantDetail(
              Icons.menu_book_outlined, 'Program', '${app.degree} • ${app.currentYear}'),
          Row(
            children: [
              Expanded(
                child: _applicantDetail(
                    Icons.phone_outlined, 'Contact', app.phone),
              ),
              Expanded(
                child: _applicantDetail(
                    Icons.cake_outlined, 'Age', '${app.age} yrs'),
              ),
            ],
          ),

          // Previous Experience
          if (app.previousExperience.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Experience & Leadership Background:',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.previousExperience,
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (app.reviewNote != null && app.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Remarks: ${app.reviewNote}',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 14),

          // Action Buttons: Accept / Reject / Reset
          Row(
            children: [
              // Reject Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: app.status == AmbassadorStatus.rejected
                      ? null
                      : () => _updateStatus(app, AmbassadorStatus.rejected),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: BorderSide(
                      color: app.status == AmbassadorStatus.rejected
                          ? _border
                          : _red.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Accept Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: app.status == AmbassadorStatus.accepted
                      ? null
                      : () => _updateStatus(app, AmbassadorStatus.accepted),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _applicantDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E7EB),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(CampusAmbassadorModel app, AmbassadorStatus newStatus) async {
    try {
      await CampusAmbassadorService.instance.updateApplicationStatus(
        app.id,
        newStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Application marked as ${newStatus.label} for ${app.name}'),
            backgroundColor:
                newStatus == AmbassadorStatus.accepted ? _green : _red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }
}

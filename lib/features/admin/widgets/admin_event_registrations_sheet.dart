import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../services/event_registrations_export_service.dart';

class AdminEventRegistrationsSheet extends StatefulWidget {
  final String eventId;
  final String eventName;
  final bool isOrganizer;
  final VoidCallback? onRegistrationsChanged;

  const AdminEventRegistrationsSheet({
    super.key,
    required this.eventId,
    required this.eventName,
    this.isOrganizer = false,
    this.onRegistrationsChanged,
  });

  @override
  State<AdminEventRegistrationsSheet> createState() => _AdminEventRegistrationsSheetState();
}

class _AdminEventRegistrationsSheetState extends State<AdminEventRegistrationsSheet> {
  static const _bg = Color(0xFF0D0F1A);
  static const _card = Color(0xFF141728);
  static const _cardLighter = Color(0xFF1C2035);
  static const _border = Color(0xFF252840);
  static const _cyan = Color(0xFF3FD8F5);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFFF9F43);
  static const _textMain = Color(0xFFE9EBEE);
  static const _textSub = Color(0xFF9CA3AF);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _registrations = [];
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, confirmed, attended, cancelled, waitlisted
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRegistrations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getEventRegistrations(widget.eventId);
      final raw = res['registrations'];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _registrations = list;
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

  List<Map<String, dynamic>> get _filteredRegistrations {
    return _registrations.where((reg) {
      // Status filter
      final status = (reg['status'] ?? 'confirmed').toString().toLowerCase();
      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }

      // Search filter
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final name = (reg['name'] ?? '').toString().toLowerCase();
      final email = (reg['email'] ?? '').toString().toLowerCase();
      final phone = (reg['phone'] ?? '').toString().toLowerCase();
      final college = (reg['college'] ?? '').toString().toLowerCase();
      final campusId = (reg['campus_id'] ?? '').toString().toLowerCase();
      final branch = (reg['branch'] ?? '').toString().toLowerCase();

      return name.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          college.contains(q) ||
          campusId.contains(q) ||
          branch.contains(q);
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

  void _showSnack(String msg, {Color color = _cyan}) {
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

  Future<void> _exportData(ExportFormat format) async {
    if (_registrations.isEmpty) {
      _showSnack('No registrations available to export', color: _orange);
      return;
    }

    try {
      _showSnack('Preparing ${format == ExportFormat.excel ? 'Excel' : 'PDF'} export...', color: _cyan);
      final fileName = await EventRegistrationsExportService.exportAndDownload(
        eventName: widget.eventName,
        registrations: _registrations,
        format: format,
      );
      _showSnack('Saved: $fileName', color: _green);
    } catch (e) {
      _showSnack('Export failed: $e', color: _red);
    }
  }

  // ── Edit Single Registration ─────────────────────────────
  Future<void> _editRegistration(Map<String, dynamic> reg) async {
    final regId = (reg['id'] ?? '').toString();
    if (regId.isEmpty) return;

    final nameCtrl = TextEditingController(text: reg['name'] ?? '');
    final emailCtrl = TextEditingController(text: reg['email'] ?? '');
    final phoneCtrl = TextEditingController(text: reg['phone'] ?? '');
    final collegeCtrl = TextEditingController(text: reg['college'] ?? '');
    final branchCtrl = TextEditingController(text: reg['branch'] ?? '');
    final notesCtrl = TextEditingController(text: reg['notes'] ?? '');
    String selectedStatus = (reg['status'] ?? 'confirmed').toString().toLowerCase();
    if (!['confirmed', 'attended', 'cancelled', 'waitlisted'].contains(selectedStatus)) {
      selectedStatus = 'confirmed';
    }

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded, color: _cyan, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Edit Registration',
                  style: TextStyle(color: _textMain, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogTextField('Student Name', nameCtrl, Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildDialogTextField('Email Address', emailCtrl, Icons.email_outlined),
                  const SizedBox(height: 12),
                  _buildDialogTextField('Phone Number', phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildDialogTextField('College / University', collegeCtrl, Icons.school_outlined),
                  const SizedBox(height: 12),
                  _buildDialogTextField('Branch / Stream', branchCtrl, Icons.category_outlined),
                  const SizedBox(height: 12),

                  // Status Dropdown
                  const Text('Registration Status', style: TextStyle(color: _textSub, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _cardLighter,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        dropdownColor: _cardLighter,
                        isExpanded: true,
                        style: const TextStyle(color: _textMain, fontSize: 14),
                        items: const [
                          DropdownMenuItem(value: 'confirmed', child: Text('✅ Confirmed')),
                          DropdownMenuItem(value: 'attended', child: Text('🎓 Attended')),
                          DropdownMenuItem(value: 'waitlisted', child: Text('⏳ Waitlisted')),
                          DropdownMenuItem(value: 'cancelled', child: Text('❌ Cancelled')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedStatus = val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  _buildDialogTextField('Admin Notes (Internal)', notesCtrl, Icons.notes_outlined, maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: _textSub)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: const Color(0xFF0F111A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        final updated = await ApiService().updateEventRegistration(
                          widget.eventId,
                          regId,
                          {
                            'name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'college': collegeCtrl.text.trim(),
                            'branch': branchCtrl.text.trim(),
                            'status': selectedStatus,
                            'notes': notesCtrl.text.trim(),
                          },
                        );

                        if (mounted && dialogCtx.mounted) {
                          final regData = updated['registration'] ?? updated;
                          setState(() {
                            final idx = _registrations.indexWhere((r) => (r['id'] ?? '').toString() == regId);
                            if (idx != -1) {
                              _registrations[idx] = Map<String, dynamic>.from(regData as Map);
                            }
                          });
                          Navigator.pop(dialogCtx);
                          _showSnack('Registration updated successfully', color: _green);
                          widget.onRegistrationsChanged?.call();
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        _showSnack('Failed to update: $e', color: _red);
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textSub, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: _textMain, fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _textSub, size: 18),
            filled: true,
            fillColor: _cardLighter,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyan)),
          ),
        ),
      ],
    );
  }

  // ── Delete Single Registration ───────────────────────────
  Future<void> _deleteSingleRegistration(Map<String, dynamic> reg) async {
    final regId = (reg['id'] ?? '').toString();
    final name = (reg['name'] ?? 'Student').toString();
    if (regId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _border)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_forever_rounded, color: _red, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Remove Registration', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the registration for "$name"?\nThis cannot be undone.',
          style: const TextStyle(color: _textSub, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteEventRegistration(widget.eventId, regId);
      if (mounted) {
        setState(() {
          _registrations.removeWhere((r) => (r['id'] ?? '').toString() == regId);
        });
        _showSnack('Registration for "$name" removed', color: _green);
        widget.onRegistrationsChanged?.call();
      }
    } catch (e) {
      _showSnack('Failed to delete registration: $e', color: _red);
    }
  }

  // ── Mandatory Safety Wipe Modal (Download First Required) ──
  Future<void> _openWipeAllRegistrationsDialog() async {
    if (_registrations.isEmpty) {
      _showSnack('No registrations to wipe', color: _orange);
      return;
    }

    String? downloadedFileName;
    bool downloading = false;
    bool deleting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _red.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: _red, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wipe All Registrations',
                      style: TextStyle(color: _textMain, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Irreversible Action & Safety Backup',
                      style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are about to permanently delete all ${_registrations.length} student registrations for:\n"${widget.eventName}".',
                  style: const TextStyle(color: _textMain, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Mandatory Safety Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _orange.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: _orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          downloadedFileName != null
                              ? 'Safety Requirement Met!\nBackup saved: $downloadedFileName'
                              : 'Mandatory Safety Rule:\nYou must download a complete Excel (.xlsx) or PDF backup file before you can proceed to wipe the registrations.',
                          style: TextStyle(
                            color: downloadedFileName != null ? _green : _orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Download Buttons
                const Text(
                  'Step 1: Download Backup File',
                  style: TextStyle(color: _textSub, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, color: _green, size: 18),
                        label: const Text('Download Excel (.xlsx)', style: TextStyle(color: _textMain, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _green.withValues(alpha: 0.08),
                          side: BorderSide(color: downloadedFileName != null && downloadedFileName!.endsWith('.xlsx') ? _green : _border),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: downloading || deleting
                            ? null
                            : () async {
                                setDialogState(() => downloading = true);
                                try {
                                  final name = await EventRegistrationsExportService.exportAndDownload(
                                    eventName: widget.eventName,
                                    registrations: _registrations,
                                    format: ExportFormat.excel,
                                  );
                                  setDialogState(() {
                                    downloadedFileName = name;
                                    downloading = false;
                                  });
                                } catch (e) {
                                  setDialogState(() => downloading = false);
                                  _showSnack('Download failed: $e', color: _red);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: _cyan, size: 18),
                        label: const Text('Download PDF', style: TextStyle(color: _textMain, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _cyan.withValues(alpha: 0.08),
                          side: BorderSide(color: downloadedFileName != null && downloadedFileName!.endsWith('.pdf') ? _cyan : _border),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: downloading || deleting
                            ? null
                            : () async {
                                setDialogState(() => downloading = true);
                                try {
                                  final name = await EventRegistrationsExportService.exportAndDownload(
                                    eventName: widget.eventName,
                                    registrations: _registrations,
                                    format: ExportFormat.pdf,
                                  );
                                  setDialogState(() {
                                    downloadedFileName = name;
                                    downloading = false;
                                  });
                                } catch (e) {
                                  setDialogState(() => downloading = false);
                                  _showSnack('Download failed: $e', color: _red);
                                }
                              },
                      ),
                    ),
                  ],
                ),

                if (downloadedFileName != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: _green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Backup saved: $downloadedFileName',
                            style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: _textSub)),
            ),
            ElevatedButton.icon(
              icon: deleting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text(
                downloadedFileName == null ? 'Download Backup First' : 'Wipe All Registrations',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: downloadedFileName == null ? _border : _red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
              onPressed: (downloadedFileName == null || deleting)
                  ? null
                  : () async {
                      setDialogState(() => deleting = true);
                      try {
                        final deletedCount = await ApiService().deleteAllEventRegistrations(widget.eventId);
                        if (mounted && dialogCtx.mounted) {
                          setState(() {
                            _registrations.clear();
                          });
                          Navigator.pop(dialogCtx);
                          _showSnack('Successfully wiped $deletedCount registrations', color: _green);
                          widget.onRegistrationsChanged?.call();
                        }
                      } catch (e) {
                        setDialogState(() => deleting = false);
                        _showSnack('Failed to wipe registrations: $e', color: _red);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ── UI Components ─────────────────────────────────────────

  Widget _buildStatusChip(String label, String value, Color color) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : _border, width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : _textSub,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationCard(Map<String, dynamic> reg) {
    final name = (reg['name'] ?? 'Student').toString();
    final email = (reg['email'] ?? '').toString();
    final phone = (reg['phone'] ?? '').toString();
    final college = (reg['college'] ?? '').toString();
    final course = (reg['course'] ?? '').toString();
    final branch = (reg['branch'] ?? '').toString();
    final campusId = (reg['campus_id'] ?? '').toString();
    final status = (reg['status'] ?? 'confirmed').toString().toLowerCase();
    final notes = (reg['notes'] ?? '').toString();
    final registeredAt = _formatDate(reg['registered_at']);

    final isGuest = reg['is_guest'] == true || reg['user_id'] == null;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'attended':
        statusColor = _cyan;
        statusLabel = 'Attended';
        break;
      case 'cancelled':
        statusColor = _red;
        statusLabel = 'Cancelled';
        break;
      case 'waitlisted':
        statusColor = _orange;
        statusLabel = 'Waitlisted';
        break;
      case 'confirmed':
      default:
        statusColor = _green;
        statusLabel = 'Confirmed';
    }

    final courseBranch = [course, branch].where((s) => s.isNotEmpty).join(' · ');

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
            // Row 1: Avatar, Name, Status Badge, Edit & Delete Buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isGuest
                      ? _orange.withValues(alpha: 0.15)
                      : _cyan.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isGuest ? _orange : _cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(color: _textMain, fontSize: 14, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isGuest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _orange.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'Guest',
                                style: TextStyle(color: _orange, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isGuest)
                        const Text(
                          'Public Link Registration',
                          style: TextStyle(color: _orange, fontSize: 11, fontWeight: FontWeight.w500),
                        )
                      else if (campusId.isNotEmpty)
                        Text(
                          'ID: $campusId',
                          style: const TextStyle(color: _cyan, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),

                // Edit Action
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: _cyan, size: 18),
                  tooltip: 'Edit Registration',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _editRegistration(reg),
                ),

                // Delete Action
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 18),
                  tooltip: 'Delete Registration',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _deleteSingleRegistration(reg),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 10),

            // Row 2: Contact & College Info
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (email.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: email));
                      _showSnack('Copied email: $email');
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_outlined, color: _textSub, size: 13),
                        const SizedBox(width: 4),
                        Text(email, style: const TextStyle(color: _textSub, fontSize: 11.5)),
                      ],
                    ),
                  ),
                if (phone.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      _showSnack('Copied phone: $phone');
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, color: _green, size: 13),
                        const SizedBox(width: 4),
                        Text(phone, style: const TextStyle(color: _green, fontSize: 11.5, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                if (college.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_outlined, color: _textSub, size: 13),
                      const SizedBox(width: 4),
                      Text(college, style: const TextStyle(color: _textSub, fontSize: 11.5)),
                    ],
                  ),
                if (courseBranch.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category_outlined, color: _textSub, size: 13),
                      const SizedBox(width: 4),
                      Text(courseBranch, style: const TextStyle(color: _textSub, fontSize: 11.5)),
                    ],
                  ),
              ],
            ),

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _cardLighter,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, color: _orange, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Note: $notes',
                        style: const TextStyle(color: _textSub, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: _textSub, size: 12),
                    const SizedBox(width: 4),
                    Text('Registered: $registeredAt', style: const TextStyle(color: _textSub, fontSize: 10.5)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRegistrations;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Header & Drag Handle ─────────────────────────
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
                        color: _cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: _cyan, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.eventName,
                                  style: const TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.isOrganizer) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _orange.withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    'Organizer View',
                                    style: TextStyle(color: _orange, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${_registrations.length} Total Registrations',
                            style: const TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    // Close Button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _textSub),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Toolbar: Export Excel, Export PDF, Wipe All ─
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Export Excel
                      OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, color: _green, size: 16),
                        label: const Text('Export Excel', style: TextStyle(color: _textMain, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _green.withValues(alpha: 0.08),
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _exportData(ExportFormat.excel),
                      ),
                      const SizedBox(width: 8),

                      // Export PDF
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: _cyan, size: 16),
                        label: const Text('Export PDF', style: TextStyle(color: _textMain, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _cyan.withValues(alpha: 0.08),
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _exportData(ExportFormat.pdf),
                      ),

                      // Wipe All Registrations (Super Admin only, completely hidden for Organizers)
                      if (!widget.isOrganizer) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_sweep_rounded, color: _red, size: 16),
                          label: const Text('Wipe All Registrations', style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _red.withValues(alpha: 0.08),
                            side: BorderSide(color: _red.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _openWipeAllRegistrationsDialog,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Search & Filter Controls ─────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: _card.withValues(alpha: 0.5),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: _textMain, fontSize: 13),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by student name, email, phone, college...',
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
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyan)),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All (${_registrations.length})', 'all', _cyan),
                      const SizedBox(width: 8),
                      _buildStatusChip('Confirmed', 'confirmed', _green),
                      const SizedBox(width: 8),
                      _buildStatusChip('Attended', 'attended', _cyan),
                      const SizedBox(width: 8),
                      _buildStatusChip('Waitlisted', 'waitlisted', _orange),
                      const SizedBox(width: 8),
                      _buildStatusChip('Cancelled', 'cancelled', _red),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Registrations List / Empty / Loading ─────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _cyan))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: _red, size: 36),
                            const SizedBox(height: 8),
                            Text('Could not load registrations: $_error', style: const TextStyle(color: _red, fontSize: 12)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadRegistrations,
                              style: ElevatedButton.styleFrom(backgroundColor: _cyan, foregroundColor: Colors.black),
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
                                  _registrations.isEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded,
                                  color: _textSub,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _registrations.isEmpty
                                      ? 'No students have registered yet for this event.'
                                      : 'No registrations match your search criteria.',
                                  style: const TextStyle(color: _textSub, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: _cyan,
                            onRefresh: _loadRegistrations,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) => _buildRegistrationCard(filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

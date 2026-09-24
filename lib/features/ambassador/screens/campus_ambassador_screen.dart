// lib/features/ambassador/screens/campus_ambassador_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_typography.dart';
import '../models/campus_ambassador_model.dart';
import '../services/campus_ambassador_service.dart';

class CampusAmbassadorScreen extends ConsumerStatefulWidget {
  const CampusAmbassadorScreen({super.key});

  @override
  ConsumerState<CampusAmbassadorScreen> createState() =>
      _CampusAmbassadorScreenState();
}

class _CampusAmbassadorScreenState extends ConsumerState<CampusAmbassadorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _isEditing = false;
  bool _initialized = false;

  final List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'Postgraduate / Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _degreeCtrl.dispose();
    _yearCtrl.dispose();
    _collegeCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  void _populateFromUser(CampusAmbassadorModel? existing) {
    if (_initialized) return;
    _initialized = true;

    if (existing != null) {
      _nameCtrl.text = existing.name;
      _ageCtrl.text = existing.age;
      _phoneCtrl.text = existing.phone;
      _degreeCtrl.text = existing.degree;
      _yearCtrl.text = existing.currentYear;
      _collegeCtrl.text = existing.collegeName;
      _experienceCtrl.text = existing.previousExperience;
    } else {
      final user = FirebaseAuth.instance.currentUser;
      final userAsync = ref.read(currentUserProvider).value;

      _nameCtrl.text = userAsync?.name ?? user?.displayName ?? '';
      _collegeCtrl.text = userAsync?.college ?? '';
      _degreeCtrl.text = userAsync?.course ?? userAsync?.branch ?? '';
      if (userAsync?.yearOfStudy != null) {
        _yearCtrl.text = '${userAsync!.yearOfStudy}th Year';
      }
      if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) {
        _phoneCtrl.text = user.phoneNumber!;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to apply.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final application = CampusAmbassadorModel(
        id: user.uid,
        userId: user.uid,
        name: _nameCtrl.text.trim(),
        age: _ageCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        degree: _degreeCtrl.text.trim(),
        currentYear: _yearCtrl.text.trim(),
        collegeName: _collegeCtrl.text.trim(),
        previousExperience: _experienceCtrl.text.trim(),
        status: AmbassadorStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await CampusAmbassadorService.instance.submitApplication(application);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully! 🎉'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final programOpenAsync = ref.watch(ambassadorProgramStatusProvider);
    final isProgramOpen = programOpenAsync.value ?? true;

    final myAppAsync = ref.watch(myAmbassadorApplicationProvider);
    final myApp = myAppAsync.value;

    if (!_initialized && (myApp != null || myAppAsync.hasValue)) {
      _populateFromUser(myApp);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F111A) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161926) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Campus Ambassador',
          style: AppTypography.soraHeading3(
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        centerTitle: true,
        actions: [
          if (myApp != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Color(0xFFF59E0B)),
              tooltip: 'Edit Application',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // If already applied and not editing, show Status Card
            if (myApp != null && !_isEditing) ...[
              _buildStatusCard(myApp, isDark),
              const SizedBox(height: 20),
              _buildApplicationReview(myApp, isDark),
            ] else ...[
              // If closed and user has not applied
              if (!isProgramOpen && myApp == null) ...[
                _buildClosedBanner(isDark),
              ] else ...[
                _buildHeroBanner(isDark),
                const SizedBox(height: 20),
                _buildPerksSection(isDark),
                const SizedBox(height: 24),
                _buildApplicationForm(isDark),
              ],
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Status Banner for existing applicant ──────────────────────────────────
  Widget _buildStatusCard(CampusAmbassadorModel app, bool isDark) {
    Color bgGradientStart;
    Color bgGradientEnd;
    Color borderColor;
    Color accentColor;
    String statusTitle;
    String statusSubtitle;
    IconData icon;

    switch (app.status) {
      case AmbassadorStatus.accepted:
        bgGradientStart = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
        bgGradientEnd = isDark ? const Color(0xFF022C22) : const Color(0xFFA7F3D0);
        borderColor = const Color(0xFF10B981);
        accentColor = const Color(0xFF10B981);
        statusTitle = "You're an Official Ambassador! 🎉";
        statusSubtitle =
            "Congratulations! Your application has been approved. You are now the official representative for ${app.collegeName}. Welcome to the leadership circle!";
        icon = Icons.verified_rounded;
        break;
      case AmbassadorStatus.rejected:
        bgGradientStart = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        bgGradientEnd = isDark ? const Color(0xFF2B0707) : const Color(0xFFFECACA);
        borderColor = const Color(0xFFEF4444);
        accentColor = const Color(0xFFEF4444);
        statusTitle = "Application Not Selected";
        statusSubtitle =
            "Thank you for your interest. Positions for this cohort have been fulfilled. Keep building and look out for next season's applications!";
        icon = Icons.cancel_outlined;
        break;
      case AmbassadorStatus.pending:
        bgGradientStart = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
        bgGradientEnd = isDark ? const Color(0xFF281102) : const Color(0xFFFDE68A);
        borderColor = const Color(0xFFF59E0B);
        accentColor = const Color(0xFFD97706);
        statusTitle = "Application Under Review ⏳";
        statusSubtitle =
            "We received your application! Our campus operations team is reviewing your profile and will update your status soon.";
        icon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgGradientStart, bgGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        app.status.label.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusTitle,
                      style: AppTypography.soraHeading3(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ).copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusSubtitle,
            style: AppTypography.interBody(
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              size: 13,
            ).copyWith(height: 1.45),
          ),
          if (app.reviewNote != null && app.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Admin Note: ${app.reviewNote}',
                      style: AppTypography.interCaption(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Application Detail Summary for applicant ──────────────────────────────
  Widget _buildApplicationReview(CampusAmbassadorModel app, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161926) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Submitted Details',
                style: AppTypography.soraHeading3(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Update'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _detailRow(Icons.person_rounded, 'Full Name', app.name, isDark),
          _detailRow(Icons.cake_rounded, 'Age', '${app.age} years', isDark),
          _detailRow(Icons.phone_rounded, 'Phone', app.phone, isDark),
          _detailRow(Icons.school_rounded, 'College', app.collegeName, isDark),
          _detailRow(Icons.menu_book_rounded, 'Degree & Year', '${app.degree} • ${app.currentYear}', isDark),
          if (app.previousExperience.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Previous Experience',
              style: AppTypography.interLabel(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F111A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                app.previousExperience,
                style: AppTypography.interBody(
                  color: isDark ? Colors.white : const Color(0xFF334155),
                  size: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Banner ───────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF312208), const Color(0xFF1E1705)]
              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📢 ', style: TextStyle(fontSize: 11)),
                    Text(
                      'LEAD YOUR CAMPUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cohort 2026',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Campus Ambassador Program',
            style: AppTypography.soraHeading2(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Represent CampusSetu at your university. Help your college community connect, grow, and unlock exclusive rewards & leadership certificates.',
            style: AppTypography.interBody(
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
              size: 13,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Closed Banner ─────────────────────────────────────────────────────────
  Widget _buildClosedBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161926) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded, size: 40, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          Text(
            'Applications Currently Closed',
            style: AppTypography.soraHeading3(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'The Campus Ambassador program is currently paused or registrations have closed for this season. Please check back soon!',
            style: AppTypography.interBody(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              size: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Perks Section ─────────────────────────────────────────────────────────
  Widget _buildPerksSection(bool isDark) {
    final perks = [
      (
        '📜',
        'Official Certificate',
        'Receive a verified Certificate of Excellence from CampusSetu.',
      ),
      (
        '🎁',
        'Stipend & Goodies',
        'Performance-based monthly stipend, t-shirts, stickers & swag.',
      ),
      (
        '🚀',
        'Direct Mentorship',
        'Network with startup founders, tech leaders, and alumni.',
      ),
      (
        '🏆',
        'Leadership Role',
        'Organize workshops, competitions & represent your batch.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ambassador Perks & Benefits',
          style: AppTypography.soraHeading3(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: perks.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.25,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (ctx, idx) {
            final p = perks[idx];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161926) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.$1, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 8),
                  Text(
                    p.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      p.$3,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Application Form ──────────────────────────────────────────────────────
  Widget _buildApplicationForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161926) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_ind_rounded,
                    color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 10),
                Text(
                  _isEditing ? 'Update Application' : 'Application Form',
                  style: AppTypography.soraHeading3(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fill in your details below to submit your nomination.',
              style: AppTypography.interCaption(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const Divider(height: 24),

            // Name
            _buildTextField(
              controller: _nameCtrl,
              label: 'Full Name',
              hint: 'e.g. John Doe',
              icon: Icons.person_outline_rounded,
              isDark: isDark,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 14),

            // Age & Phone in Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _ageCtrl,
                    label: 'Age',
                    hint: 'e.g. 20',
                    icon: Icons.cake_outlined,
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter age';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 15 || n > 35) return 'Invalid age';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _phoneCtrl,
                    label: 'Phone / WhatsApp',
                    hint: 'e.g. 9876543210',
                    icon: Icons.phone_outlined,
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'Enter valid phone'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // College Name
            _buildTextField(
              controller: _collegeCtrl,
              label: 'College / University Name',
              hint: 'e.g. Delhi Technological University',
              icon: Icons.account_balance_outlined,
              isDark: isDark,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter your college name'
                  : null,
            ),
            const SizedBox(height: 14),

            // Degree & Year
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _degreeCtrl,
                    label: 'Degree / Branch',
                    hint: 'e.g. B.Tech CSE',
                    icon: Icons.school_outlined,
                    isDark: isDark,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter degree'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildDropdown(
                    label: 'Current Year',
                    value: _yearCtrl.text.isNotEmpty ? _yearCtrl.text : null,
                    items: _yearOptions,
                    isDark: isDark,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _yearCtrl.text = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Previous Experience
            _buildTextField(
              controller: _experienceCtrl,
              label: 'Previous Experience & Societies (Brief)',
              hint:
                  'Mention any clubs, fests, student chapters, projects, or leadership roles you were part of...',
              icon: Icons.history_edu_outlined,
              isDark: isDark,
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please write a brief summary of your experience'
                  : null,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (_isEditing) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _isEditing = false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isEditing
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isEditing
                                      ? 'Update Nomination'
                                      : 'Submit Application',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(icon,
                size: 18,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F111A) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFF59E0B),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          items: items.map((e) {
            return DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (v) => (v == null || v.isEmpty) ? 'Select year' : null,
          dropdownColor: isDark ? const Color(0xFF1E2130) : Colors.white,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: 'Select Year',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F111A) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFF59E0B),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

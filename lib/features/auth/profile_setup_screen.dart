// lib/features/auth/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/neu_dropdown.dart';
import '../../core/router/app_router.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();

  String? _selectedState;
  int? _selectedYear;
  File? _photoFile;
  bool _isLoading = false;

  // Skills as chips
  final List<String> _skills = [];

  static const _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Delhi', 'Jammu & Kashmir', 'Ladakh',
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _collegeCtrl.dispose();
    _cityCtrl.dispose();
    _courseCtrl.dispose();
    _branchCtrl.dispose();
    _bioCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageCtrl.nextPage(duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() => _currentStep++);
    } else {
      _submitProfile();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageCtrl.previousPage(duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isNotEmpty && !_skills.contains(trimmed)) {
      setState(() => _skills.add(trimmed));
    }
    _skillsCtrl.clear();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = AuthService().currentUser!;
      final token = await AuthService().getIdToken(forceRefresh: false);
      ApiService().setToken(token);

      // Upload profile photo first if selected
      String? photoUrl;
      if (_photoFile != null) {
        try {
          final photoRes = await ApiService().uploadProfilePhoto(user.uid, _photoFile!.path);
          photoUrl = (photoRes['photo_url'] ?? photoRes['file_url'] ?? photoRes['url'])?.toString();
        } catch (_) {
          // Photo upload failed but continue with profile save
        }
      }

      await ApiService().updateProfile(user.uid, {
        'name': _nameCtrl.text.trim(),
        'college': _collegeCtrl.text.trim(),
        'state': _selectedState,
        'city': _cityCtrl.text.trim(),
        'course': _courseCtrl.text.trim(),
        'branch': _branchCtrl.text.trim(),
        'year_of_study': _selectedYear,
        'bio': _bioCtrl.text.trim(),
        'skills': _skills,
        'profile_complete': true,
        if (photoUrl != null) 'photo_url': photoUrl,
      });

      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Header ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_currentStep > 0)
                          GestureDetector(
                            onTap: _prevStep,
                            child: NeuCard(
                              padding: const EdgeInsets.all(10),
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 18, color: AppColors.ink),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          'Step ${_currentStep + 1} of 3',
                          style: AppTypography.interLabel(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Set up your\nprofile', style: AppTypography.soraDisplay(size: 28)),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us about yourself so peers can find you',
                      style: AppTypography.interBody(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 20),

                    // ── Step dots ──────────────────────────
                    Row(
                      children: List.generate(3, (i) {
                        final active = i == _currentStep;
                        final done = i < _currentStep;
                        return AnimatedContainer(
                          duration: 300.ms,
                          width: active ? 32 : 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: done
                                ? AppColors.success
                                : active
                                    ? AppColors.cyanDeep
                                    : AppColors.shadowDark,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // ── Page content ──────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Step1(
                      photoFile: _photoFile,
                      onPickPhoto: _pickPhoto,
                      nameCtrl: _nameCtrl,
                      collegeCtrl: _collegeCtrl,
                    ),
                    _Step2(
                      states: _states,
                      selectedState: _selectedState,
                      onStateChanged: (v) => setState(() => _selectedState = v),
                      cityCtrl: _cityCtrl,
                      courseCtrl: _courseCtrl,
                      branchCtrl: _branchCtrl,
                      selectedYear: _selectedYear,
                      onYearChanged: (v) => setState(() => _selectedYear = v),
                    ),
                    _Step3(
                      bioCtrl: _bioCtrl,
                      skillsCtrl: _skillsCtrl,
                      skills: _skills,
                      onAddSkill: _addSkill,
                      onRemoveSkill: (s) => setState(() => _skills.remove(s)),
                    ),
                  ],
                ),
              ),

              // ── Next / Submit button ───────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: GestureDetector(
                  onTap: _isLoading ? null : _nextStep,
                  child: AnimatedContainer(
                    duration: 200.ms,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.cyanGlowShadows,
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep < 2 ? 'Next →' : 'Complete Profile 🎉',
                            style: AppTypography.interButton(color: AppColors.darkTile, size: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 1: Photo + Name + College ─────────────────────────
class _Step1 extends StatelessWidget {
  final File? photoFile;
  final VoidCallback onPickPhoto;
  final TextEditingController nameCtrl;
  final TextEditingController collegeCtrl;

  const _Step1({
    required this.photoFile,
    required this.onPickPhoto,
    required this.nameCtrl,
    required this.collegeCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        children: [
          // Photo picker
          GestureDetector(
            onTap: onPickPhoto,
            child: NeuCard(
              padding: EdgeInsets.zero,
              width: 110,
              height: 110,
              borderRadius: 55,
              alignment: Alignment.center,
              child: photoFile != null
                  ? ClipOval(child: Image.file(photoFile!, width: 110, height: 110, fit: BoxFit.cover))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, color: AppColors.cyanDeep, size: 28),
                        const SizedBox(height: 4),
                        Text('Add Photo', style: AppTypography.interCaption(color: AppColors.cyanDeep)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 28),
          NeuTextField(
            label: 'Full Name *',
            hint: 'Your full name',
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            prefixIcon: Icon(Icons.person_outline, color: AppColors.inkSoft, size: 20),
          ),
          const SizedBox(height: 16),
          NeuTextField(
            label: 'College / University *',
            hint: 'e.g. IIT Delhi, VIT Vellore',
            controller: collegeCtrl,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.trim().isEmpty ? 'College is required' : null,
            prefixIcon: Icon(Icons.school_outlined, color: AppColors.inkSoft, size: 20),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Location + Course + Year ───────────────────────
class _Step2 extends StatelessWidget {
  final List<String> states;
  final String? selectedState;
  final ValueChanged<String?> onStateChanged;
  final TextEditingController cityCtrl;
  final TextEditingController courseCtrl;
  final TextEditingController branchCtrl;
  final int? selectedYear;
  final ValueChanged<int?> onYearChanged;

  const _Step2({
    required this.states,
    required this.selectedState,
    required this.onStateChanged,
    required this.cityCtrl,
    required this.courseCtrl,
    required this.branchCtrl,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        children: [
          NeuDropdown<String>(
            label: 'State *',
            hint: 'Select your state',
            value: selectedState,
            items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: onStateChanged,
          ),
          const SizedBox(height: 16),
          NeuTextField(
            label: 'City *',
            hint: 'e.g. Mumbai, Bangalore',
            controller: cityCtrl,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.trim().isEmpty ? 'City is required' : null,
            prefixIcon: Icon(Icons.location_city_outlined, color: AppColors.inkSoft, size: 20),
          ),
          const SizedBox(height: 16),
          NeuTextField(
            label: 'Course *',
            hint: 'e.g. B.Tech, BCA, MBA',
            controller: courseCtrl,
            textCapitalization: TextCapitalization.characters,
            validator: (v) => v == null || v.trim().isEmpty ? 'Course is required' : null,
            prefixIcon: Icon(Icons.book_outlined, color: AppColors.inkSoft, size: 20),
          ),
          const SizedBox(height: 16),
          NeuTextField(
            label: 'Branch / Specialisation *',
            hint: 'e.g. Computer Science, Finance',
            controller: branchCtrl,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.trim().isEmpty ? 'Branch is required' : null,
            prefixIcon: Icon(Icons.category_outlined, color: AppColors.inkSoft, size: 20),
          ),
          const SizedBox(height: 16),
          NeuDropdown<int>(
            label: 'Year of Study *',
            hint: 'Select year',
            value: selectedYear,
            items: [1, 2, 3, 4, 5]
                .map((y) => DropdownMenuItem(value: y, child: Text('Year $y')))
                .toList(),
            onChanged: onYearChanged,
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Bio + Skills ────────────────────────────────────
class _Step3 extends StatelessWidget {
  final TextEditingController bioCtrl;
  final TextEditingController skillsCtrl;
  final List<String> skills;
  final ValueChanged<String> onAddSkill;
  final ValueChanged<String> onRemoveSkill;

  const _Step3({
    required this.bioCtrl,
    required this.skillsCtrl,
    required this.skills,
    required this.onAddSkill,
    required this.onRemoveSkill,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeuTextField(
            label: 'Bio (optional)',
            hint: 'Tell others a bit about yourself...',
            controller: bioCtrl,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          Text('Skills (optional)', style: AppTypography.interLabel()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: NeuTextField(
                  hint: 'e.g. Flutter, Python, ML',
                  controller: skillsCtrl,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: onAddSkill,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 10),
              NeuCard(
                padding: const EdgeInsets.all(14),
                onTap: () => onAddSkill(skillsCtrl.text),
                child: const Icon(Icons.add_rounded, color: AppColors.cyanDeep, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (skills.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills
                  .map((s) => _SkillChip(skill: s, onRemove: () => onRemoveSkill(s)))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;
  final VoidCallback onRemove;
  const _SkillChip({required this.skill, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.cyanDeep.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyanDeep.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(skill, style: AppTypography.interLabel(color: AppColors.cyanDeep).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.cyanDeep),
          ),
        ],
      ),
    );
  }
}

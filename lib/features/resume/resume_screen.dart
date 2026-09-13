import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/dark_tile.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_chip.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/premium_badge.dart';

class ResumeScreen extends ConsumerStatefulWidget {
  const ResumeScreen({super.key});
  @override
  ConsumerState<ResumeScreen> createState() => _ResumeScreenState();
}

class _TemplateMeta {
  final String name;
  final bool isPremium;
  final IconData icon;
  const _TemplateMeta(this.name, this.isPremium, this.icon);
}

class _ResumeScreenState extends ConsumerState<ResumeScreen> {
  int _selectedTemplate = 0;
  final Map<String, TextEditingController> _ctrls = {
    'name': TextEditingController(),
    'email': TextEditingController(),
    'phone': TextEditingController(),
    'linkedin': TextEditingController(),
    'education': TextEditingController(),
    'experience': TextEditingController(),
    'projects': TextEditingController(),
    'skills': TextEditingController(),
    'achievements': TextEditingController(),
  };
  final Map<String, bool> _done = {
    'personal': false, 'education': false, 'experience': false, 'projects': false, 'skills': false, 'achievements': false,
  };

  static const List<_TemplateMeta> _templates = [
    _TemplateMeta('Modern', false, Icons.article_rounded),
    _TemplateMeta('Classic', false, Icons.description_rounded),
    _TemplateMeta('Minimal', false, Icons.text_snippet_rounded),
    _TemplateMeta('Elegant', false, Icons.auto_awesome_rounded),
    _TemplateMeta('Professional', false, Icons.work_rounded),
    _TemplateMeta('Creative', false, Icons.palette_rounded),
    _TemplateMeta('Standard', false, Icons.assignment_rounded),
    _TemplateMeta('Basic', false, Icons.note_alt_rounded),
    _TemplateMeta('Clean', false, Icons.cleaning_services_rounded),
    _TemplateMeta('Simple', false, Icons.subject_rounded),
    _TemplateMeta('Executive', true, Icons.business_center_rounded),
    _TemplateMeta('Luxury', true, Icons.diamond_rounded),
    _TemplateMeta('Designer', true, Icons.brush_rounded),
    _TemplateMeta('Corporate', true, Icons.apartment_rounded),
    _TemplateMeta('Tech', true, Icons.memory_rounded),
    _TemplateMeta('Artistic', true, Icons.color_lens_rounded),
    _TemplateMeta('Futuristic', true, Icons.rocket_launch_rounded),
    _TemplateMeta('Elite', true, Icons.workspace_premium_rounded),
    _TemplateMeta('Platinum', true, Icons.stars_rounded),
    _TemplateMeta('Premium', true, Icons.verified_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(profileProvider(null)).value;
      if (user != null) {
        _ctrls['name']!.text = user.name;
        _ctrls['email']!.text = user.email;
        _ctrls['skills']!.text = user.skills.join(', ');
        setState(() {
          _done['personal'] = user.name.isNotEmpty;
          _done['education'] = (user.college ?? '').isNotEmpty;
          _done['skills'] = user.skills.isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  int get _ats {
    int s = 30;
    if (_done['personal']!) s += 10;
    if (_done['education']!) s += 10;
    if (_done['experience']!) s += 15;
    if (_done['projects']!) s += 15;
    if (_done['skills']!) s += 10;
    if (_done['achievements']!) s += 10;
    return s.clamp(0, 100);
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final name = _ctrls['name']!.text.isEmpty ? 'Your Name' : _ctrls['name']!.text;
    final email = _ctrls['email']!.text;
    final phone = _ctrls['phone']!.text;
    final tmpl = _templates[_selectedTemplate];
    final isModern = tmpl.name == 'Modern' || _selectedTemplate % 2 == 0;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: isModern ? pw.BoxDecoration(color: PdfColor.fromHex('#1BA8C4'), borderRadius: pw.BorderRadius.circular(6)) : const pw.BoxDecoration(),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: isModern ? PdfColors.white : PdfColors.black)),
            pw.SizedBox(height: 2),
            pw.Text('Template: ${tmpl.name}', style: pw.TextStyle(fontSize: 7, color: isModern ? PdfColors.white : PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text('$email  ${phone.isNotEmpty ? ' | $phone' : ''}  ${_ctrls['linkedin']!.text}', style: pw.TextStyle(fontSize: 9, color: isModern ? PdfColors.white : PdfColors.grey700)),
          ]),
        ),
        pw.SizedBox(height: 16),
        if (_ctrls['education']!.text.isNotEmpty) ...[pw.Text('EDUCATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#1BA8C4'))), pw.Divider(), pw.Text(_ctrls['education']!.text, style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 10)],
        if (_ctrls['experience']!.text.isNotEmpty) ...[pw.Text('EXPERIENCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#1BA8C4'))), pw.Divider(), pw.Text(_ctrls['experience']!.text, style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 10)],
        if (_ctrls['projects']!.text.isNotEmpty) ...[pw.Text('PROJECTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#1BA8C4'))), pw.Divider(), pw.Text(_ctrls['projects']!.text, style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 10)],
        if (_ctrls['skills']!.text.isNotEmpty) ...[pw.Text('SKILLS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#1BA8C4'))), pw.Divider(), pw.Text(_ctrls['skills']!.text, style: const pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 10)],
        if (_ctrls['achievements']!.text.isNotEmpty) ...[pw.Text('ACHIEVEMENTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#1BA8C4'))), pw.Divider(), pw.Text(_ctrls['achievements']!.text, style: const pw.TextStyle(fontSize: 10))],
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  void _editSection(String key, String title, String hint, String ctrlKey) {
    final c = _ctrls[ctrlKey]!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.neuRaisedShadows),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.shadowDark, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(title, style: AppTypography.soraHeading3()),
            const SizedBox(height: 12),
            NeuTextField(hint: hint, controller: c, maxLines: 5),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { setState(() => _done[key] = c.text.trim().isNotEmpty); Navigator.pop(context); },
              child: Container(height: 50, decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text('Save', style: AppTypography.interButton(color: Colors.white))),
            ),
          ]),
        ),
      ),
    );
  }

  void _onTemplateTap(int index, bool isPremiumUser) {
    final tmpl = _templates[index];
    if (tmpl.isPremium && !isPremiumUser) {
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [const PremiumBadge(label: 'PRO'), const SizedBox(width: 8), Text('Premium Template', style: AppTypography.soraHeading3())]),
        content: Text('"${tmpl.name}" is a premium template. Subscribe to unlock all 10 premium designs and build unlimited resumes.', style: AppTypography.interBody(color: AppColors.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Maybe later', style: AppTypography.interLabel())),
          GestureDetector(onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium subscription coming soon!'))); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(10)), child: Text('Go Premium', style: AppTypography.interButton(color: Colors.white, size: 13)))),
        ],
      ));
      return;
    }
    setState(() => _selectedTemplate = index);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileProvider(null)).value;
    final isPremiumUser = user?.isPremium ?? false;
    final sections = [
      _Section(icon: Icons.person_outline, title: 'Personal Info', subtitle: _ctrls['name']!.text.isEmpty ? 'Add name, email, phone' : _ctrls['name']!.text, done: _done['personal']!, onTap: () => _editSection('personal', 'Personal Info', 'Name, email, phone, LinkedIn', 'name')),
      _Section(icon: Icons.school_outlined, title: 'Education', subtitle: _ctrls['education']!.text.isEmpty ? 'Add education' : '1 entry', done: _done['education']!, onTap: () => _editSection('education', 'Education', 'College, degree, year, CGPA', 'education')),
      _Section(icon: Icons.work_outline, title: 'Experience', subtitle: _ctrls['experience']!.text.isEmpty ? 'Add internships & jobs' : '1 entry', done: _done['experience']!, onTap: () => _editSection('experience', 'Experience', 'Company, role, duration, description', 'experience')),
      _Section(icon: Icons.code_outlined, title: 'Projects', subtitle: _ctrls['projects']!.text.isEmpty ? 'Add projects' : '1 entry', done: _done['projects']!, onTap: () => _editSection('projects', 'Projects', 'Project name, tech stack, link', 'projects')),
      _Section(icon: Icons.psychology_outlined, title: 'Skills', subtitle: _ctrls['skills']!.text.isEmpty ? 'Add skills' : _ctrls['skills']!.text, done: _done['skills']!, onTap: () => _editSection('skills', 'Skills', 'e.g. Flutter, Python, ML', 'skills')),
      _Section(icon: Icons.emoji_events_outlined, title: 'Achievements', subtitle: _ctrls['achievements']!.text.isEmpty ? 'Add certificates & awards' : '1 entry', done: _done['achievements']!, onTap: () => _editSection('achievements', 'Achievements', 'Certificates, awards', 'achievements')),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('Resume Builder', style: AppTypography.soraHeading3()), backgroundColor: AppColors.bg, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink), onPressed: () => context.pop())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 140 + MediaQuery.of(context).padding.bottom),
        children: [
          Row(children: [
            Text('Choose Template', style: AppTypography.soraHeading3()),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('10 Free', style: AppTypography.interBadge(color: AppColors.success))),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.workspace_premium_rounded, size: 10, color: AppColors.gold), const SizedBox(width: 4), Text('10 PRO', style: AppTypography.interBadge(color: AppColors.gold))])),
          ]),
          const SizedBox(height: 6),
          Text('10 simple free for everyone, 10 premium for subscribers', style: AppTypography.interCaption()),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.82),
            itemCount: _templates.length,
            itemBuilder: (_, i) {
              final tmpl = _templates[i];
              final isLocked = tmpl.isPremium && !isPremiumUser;
              return GestureDetector(
                onTap: () => _onTemplateTap(i, isPremiumUser),
                child: _TemplateTile(name: tmpl.name, icon: tmpl.icon, isSelected: _selectedTemplate == i, isPremium: tmpl.isPremium, isLocked: isLocked),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Resume Sections', style: AppTypography.soraHeading3()),
          const SizedBox(height: 12),
          ...sections.map((s) => _SectionCard(section: s).animate(delay: 50.ms).fadeIn(duration: 300.ms)),
          const SizedBox(height: 24),
          DarkTile(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [GlowText('ATS Score', style: AppTypography.soraHeading3(color: AppColors.cyan)), const Spacer(), Text('$_ats/100', style: AppTypography.monoDisplay(size: 28, color: AppColors.cyan))]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _ats / 100, minHeight: 8, color: AppColors.cyan, backgroundColor: AppColors.cyanDeep.withValues(alpha: 0.2))),
              const SizedBox(height: 12),
              Text(_ats < 70 ? 'Add Experience and Projects to improve your score' : 'Great! Your resume is ready to export', style: AppTypography.interBodySmall(color: AppColors.inkSoft)),
              const SizedBox(height: 8),
              Text('Selected: ${_templates[_selectedTemplate].name} ${_templates[_selectedTemplate].isPremium ? '(PRO)' : '(Free)'}', style: AppTypography.interCaption(color: AppColors.cyan)),
            ]),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _exportPdf,
            child: Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(18), boxShadow: AppColors.cyanGlowShadows),
              alignment: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.download_rounded, color: Colors.white, size: 20), const SizedBox(width: 10), Text('Export as PDF', style: AppTypography.interButton(color: Colors.white, size: 16))]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final String title, subtitle;
  final bool done;
  final VoidCallback onTap;
  const _Section({required this.icon, required this.title, required this.subtitle, this.done = false, required this.onTap});
}

class _SectionCard extends StatelessWidget {
  final _Section section;
  const _SectionCard({required this.section});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: NeuCard(
      padding: const EdgeInsets.all(16),
      onTap: section.onTap,
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: (section.done ? AppColors.success : AppColors.cyanDeep).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(section.icon, color: section.done ? AppColors.success : AppColors.cyanDeep, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(section.title, style: AppTypography.interButton(color: AppColors.ink, size: 14)), Text(section.subtitle, style: AppTypography.interCaption(), maxLines: 1, overflow: TextOverflow.ellipsis)])),
        Icon(section.done ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, color: section.done ? AppColors.success : AppColors.inkSoft, size: section.done ? 20 : 14),
      ]),
    ),
  );
}

class _TemplateTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final bool isPremium;
  final bool isLocked;
  const _TemplateTile({required this.name, required this.icon, this.isSelected = false, this.isPremium = false, this.isLocked = false});

  Widget _preview(bool isPremiumStyle) {
    final headerColor = isPremiumStyle ? const Color(0xFF1A1D24) : AppColors.cyanDeep;
    final accent = isPremiumStyle ? AppColors.gold : AppColors.cyan;
    return Container(
      height: 62,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.shadowDark.withValues(alpha: 0.3))),
      child: Column(children: [
        Container(height: 14, decoration: BoxDecoration(color: headerColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))), alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 6), child: Row(children: [Container(width: 18, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 4), Container(width: 10, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2))), const Spacer(), Icon(icon, size: 8, color: Colors.white.withValues(alpha: 0.8))])),
        Expanded(child: Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Container(height: 3, decoration: BoxDecoration(color: accent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(2)))), const SizedBox(width: 4), Expanded(child: Container(height: 3, decoration: BoxDecoration(color: AppColors.shadowDark.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))))]),
          const SizedBox(height: 4),
          Container(height: 2, width: double.infinity, decoration: BoxDecoration(color: AppColors.shadowDark.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 3),
          Container(height: 2, width: 60, decoration: BoxDecoration(color: AppColors.shadowDark.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 4),
          Row(children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3))), const SizedBox(width: 4), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 2, decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))), const SizedBox(height: 2), Container(height: 2, width: 30, decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)))]))]),
        ]))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: isSelected ? AppColors.cyanGlowShadows : AppColors.neuRaisedShadows, border: isSelected ? Border.all(color: AppColors.cyan, width: 2) : null, color: AppColors.bg),
    child: Stack(children: [
      Column(children: [
        _preview(isPremium),
        const SizedBox(height: 6),
        Text(name, style: AppTypography.interButton(color: isLocked ? AppColors.inkMuted : (isSelected ? AppColors.cyanDeep : AppColors.ink), size: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        if (isSelected) const NeuChip(label: '✓ Selected') else if (isPremium) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text('PRO', style: AppTypography.interBadge(color: AppColors.gold))) else Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text('FREE', style: AppTypography.interBadge(color: AppColors.success))),
        const SizedBox(height: 6),
      ]),
      if (isLocked)
        Container(decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: const Icon(Icons.lock_rounded, color: Colors.white, size: 22)),
      if (isPremium && !isLocked)
        const Positioned(top: 6, right: 6, child: PremiumBadge(label: 'PRO', isSmall: true)),
      if (isSelected)
        Positioned(top: 6, left: 6, child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: AppColors.cyanDeep, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 10, color: Colors.white))),
    ]),
  );
}

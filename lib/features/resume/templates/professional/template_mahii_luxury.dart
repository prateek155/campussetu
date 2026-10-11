import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ────────────────────────────────────────────────────────────────────────────
// MAHII LUXURY RESUME — Professional Category
// Navy-Blue & Gold Executive template with fully interactive editing
// ────────────────────────────────────────────────────────────────────────────

// ─── Color Palette Options (4 sidebar colors user can choose) ───────────────
class _MahiiPalette {
  final String name;
  final Color sidebarColor;
  final Color goldAccent;
  _MahiiPalette(this.name, this.sidebarColor, this.goldAccent);
}

final List<_MahiiPalette> kMahiiPalettes = [
  _MahiiPalette('Navy Blue', const Color(0xFF0F1C30), const Color(0xFFC5A059)),
  _MahiiPalette('Forest Green', const Color(0xFF0A2217), const Color(0xFFC5A059)),
  _MahiiPalette('Charcoal', const Color(0xFF1C1C2E), const Color(0xFFC5A059)),
  _MahiiPalette('Burgundy', const Color(0xFF2A0A14), const Color(0xFFD4B07A)),
  _MahiiPalette('Royal Purple', const Color(0xFF1A0A2E), const Color(0xFFC5A059)),
];

// ─── Editable SkillItem & LanguageItem ──────────────────────────────────────
class _SkillItem {
  String name;
  double level; // 0.0 – 1.0
  _SkillItem(this.name, this.level);
}

class _LangItem {
  String name;
  int dots; // 1–7 filled out of 7
  _LangItem(this.name, this.dots);
}

// ─── Editable experience entry ───────────────────────────────────────────────
class _ExpEntry {
  String role;
  String subtitle;
  String dates;
  List<String> bullets;
  _ExpEntry({
    required this.role,
    required this.subtitle,
    required this.dates,
    required this.bullets,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// MahiiLuxuryTemplate  — Root widget
// ═══════════════════════════════════════════════════════════════════════════
class MahiiLuxuryTemplate extends StatefulWidget {
  const MahiiLuxuryTemplate({super.key});

  @override
  State<MahiiLuxuryTemplate> createState() => _MahiiLuxuryTemplateState();
}

class _MahiiLuxuryTemplateState extends State<MahiiLuxuryTemplate> {
  // ─── Palette ───────────────────────────────────────────────────────────
  int _paletteIndex = 0;
  _MahiiPalette get _pal => kMahiiPalettes[_paletteIndex];
  Color get _sidebar => _pal.sidebarColor;
  Color get _gold => _pal.goldAccent;

  // ─── Photo ─────────────────────────────────────────────────────────────
  File? _photoFile;

  // ─── Name & Title (drives signature auto-update) ──────────────────────
  final _nameCtrl = TextEditingController(text: 'PRATEEK');
  final _titleCtrl = TextEditingController(text: 'GRAPHIC DESIGNER');
  final _taglineCtrl = TextEditingController(text: 'Creative  •  Detail-Oriented  •  Dedicated');
  final _summaryCtrl = TextEditingController(
      text:
          'Creative and detail-oriented professional with a passion for designing '
          'visually stunning and effective content. Strong communicator and team '
          'player with a commitment to delivering high-quality work on time.');

  // ─── Contact ───────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController(text: '+91 98765 43210');
  final _emailCtrl = TextEditingController(text: 'prateek@gmail.com');
  final _locationCtrl = TextEditingController(text: 'Bhopal, India');
  final _linkedinCtrl = TextEditingController(text: 'linkedin.com/in/prateek');
  final _websiteCtrl = TextEditingController(text: 'behance.net/prateek');

  // ─── Education ─────────────────────────────────────────────────────────
  final List<Map<String, TextEditingController>> _eduEntries = [
    {
      'degree': TextEditingController(text: 'Bachelor of Science Computer Science'),
      'inst': TextEditingController(text: 'AISECT University, Bhopal'),
      'year': TextEditingController(text: '2019 – 2023'),
    },
    {
      'degree': TextEditingController(text: 'HSC (Science)'),
      'inst': TextEditingController(text: 'Govt. Excellence School'),
      'year': TextEditingController(text: '2017 – 2019'),
    },
    {
      'degree': TextEditingController(text: 'Matric (Science)'),
      'inst': TextEditingController(text: 'Govt. High School, Bhopal'),
      'year': TextEditingController(text: '2015 – 2017'),
    },
  ];

  // ─── Skills ────────────────────────────────────────────────────────────
  final List<_SkillItem> _skills = [
    _SkillItem('Flutter / Dart', 0.90),
    _SkillItem('Node.js', 0.80),
    _SkillItem('Firebase', 0.85),
    _SkillItem('Figma / UI Design', 0.78),
    _SkillItem('SQL / MongoDB', 0.72),
    _SkillItem('Python', 0.65),
    _SkillItem('Adobe XD', 0.70),
    _SkillItem('Branding', 0.60),
  ];

  // ─── Languages ─────────────────────────────────────────────────────────
  final List<_LangItem> _langs = [
    _LangItem('Hindi', 7),
    _LangItem('English', 6),
  ];

  // ─── Experience ────────────────────────────────────────────────────────
  final List<_ExpEntry> _expEntries = [
    _ExpEntry(
      role: 'Software Developer (Internship)',
      subtitle: 'TechSolutions Pvt. Ltd.',
      dates: '2023 – Present',
      bullets: [
        'Built cross-platform apps in Flutter with Firebase backend.',
        'Integrated REST APIs and managed CI/CD pipelines on GitHub.',
      ],
    ),
    _ExpEntry(
      role: 'Frontend Developer (Freelance)',
      subtitle: 'Self-Employed',
      dates: '2022 – 2023',
      bullets: [
        'Designed and delivered 15+ responsive web & mobile UI projects.',
        'Worked with clients on branding, logo design, and UX strategy.',
      ],
    ),
    _ExpEntry(
      role: 'Teaching Assistant',
      subtitle: 'AISECT University, Bhopal',
      dates: '2021 – 2022',
      bullets: [
        'Assisted professors in labs for DSA and Web Development courses.',
        'Mentored 30+ junior students in project submissions.',
      ],
    ),
  ];

  // ─── Expertise Checklist ───────────────────────────────────────────────
  final List<TextEditingController> _expertiseCtrls = [
    TextEditingController(text: 'Flutter App Development'),
    TextEditingController(text: 'UI / UX Design'),
    TextEditingController(text: 'REST API Integration'),
    TextEditingController(text: 'Database Management'),
    TextEditingController(text: 'Firebase & Cloud Services'),
    TextEditingController(text: 'Branding & Visual Identity'),
    TextEditingController(text: 'Project Management'),
    TextEditingController(text: 'Agile / Scrum Methodology'),
  ];

  // ─── Achievements ──────────────────────────────────────────────────────
  final List<Map<String, TextEditingController>> _achievements = [
    {
      'title': TextEditingController(text: 'Best App Developer Award'),
      'sub': TextEditingController(text: 'University Tech Fest – 2023'),
    },
    {
      'title': TextEditingController(text: 'Google Developer Certification'),
      'sub': TextEditingController(text: 'Associate Android Developer – 2023'),
    },
    {
      'title': TextEditingController(text: 'Hackathon Winner – 1st Place'),
      'sub': TextEditingController(text: 'Smart India Hackathon – 2022'),
    },
  ];

  // ─── Footer ────────────────────────────────────────────────────────────
  final _fatherCtrl = TextEditingController(text: 'Rajesh Kumar');
  final _dobCtrl = TextEditingController(text: '12 March 2001');
  final _genderCtrl = TextEditingController(text: 'Male');
  final _maritalCtrl = TextEditingController(text: 'Single');

  // ─── Editing state ─────────────────────────────────────────────────────
  bool _showControls = true;

  @override
  void dispose() {
    for (final ctrl in [
      _nameCtrl, _titleCtrl, _taglineCtrl, _summaryCtrl,
      _phoneCtrl, _emailCtrl, _locationCtrl, _linkedinCtrl, _websiteCtrl,
      _fatherCtrl, _dobCtrl, _genderCtrl, _maritalCtrl,
      ..._expertiseCtrls,
    ]) {
      ctrl.dispose();
    }
    for (final entry in _eduEntries) {
      for (final c in entry.values) c.dispose();
    }
    for (final a in _achievements) {
      for (final c in a.values) c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() => _photoFile = File(picked.path));
      }
    } catch (_) {}
  }

  int _mobileTab = 0; // 0: View Resume, 1: Customize

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final pdfNavy = PdfColor.fromInt(_sidebar.toARGB32());
    final pdfGold = PdfColor.fromInt(_gold.toARGB32());
    final sig = _nameCtrl.text.isEmpty
        ? 'Prateek'
        : _nameCtrl.text
            .split(' ')
            .first
            .toLowerCase()
            .replaceFirst(RegExp(r'.'), _nameCtrl.text[0].toUpperCase());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Left Navy Sidebar
              pw.Container(
                width: 195,
                color: pdfNavy,
                padding: const pw.EdgeInsets.fromLTRB(16, 26, 16, 18),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Photo Placeholder
                    pw.Center(
                      child: pw.Container(
                        width: 70,
                        height: 70,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: pdfGold, width: 2),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            sig.isNotEmpty ? sig[0] : 'P',
                            style: pw.TextStyle(
                              color: pdfGold,
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 18),
                    // Contact
                    pw.Text('CONTACT',
                        style: pw.TextStyle(
                            color: pdfGold,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5)),
                    pw.SizedBox(height: 6),
                    pw.Text(_phoneCtrl.text,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                    pw.Text(_emailCtrl.text,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                    pw.Text(_locationCtrl.text,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                    pw.Text(_linkedinCtrl.text,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                    pw.Text(_websiteCtrl.text,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 8)),
                    pw.SizedBox(height: 16),
                    // Education
                    pw.Text('EDUCATION',
                        style: pw.TextStyle(
                            color: pdfGold,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5)),
                    pw.SizedBox(height: 6),
                    ..._eduEntries.map((edu) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(edu['degree']!.text,
                                  style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(edu['inst']!.text,
                                  style: const pw.TextStyle(
                                      color: PdfColors.grey300, fontSize: 7)),
                              pw.Text(edu['year']!.text,
                                  style: pw.TextStyle(
                                      color: pdfGold, fontSize: 7)),
                            ],
                          ),
                        )),
                    pw.SizedBox(height: 14),
                    // Skills
                    pw.Text('SKILLS',
                        style: pw.TextStyle(
                            color: pdfGold,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5)),
                    pw.SizedBox(height: 6),
                    ..._skills.map((s) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(s.name,
                                  style: const pw.TextStyle(
                                      color: PdfColors.white, fontSize: 7.5)),
                              pw.SizedBox(height: 2),
                              pw.Container(
                                height: 3,
                                width: 160,
                                decoration: const pw.BoxDecoration(
                                    color: PdfColors.grey700),
                                child: pw.Align(
                                  alignment: pw.Alignment.centerLeft,
                                  child: pw.Container(
                                    height: 3,
                                    width: 160 * s.level,
                                    decoration:
                                        pw.BoxDecoration(color: pdfGold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    pw.Spacer(),
                    // Signature
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            sig,
                            style: pw.TextStyle(
                              color: pdfGold,
                              fontSize: 22,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'DESIGN • CREATE • INSPIRE',
                            style: pw.TextStyle(
                              color: pdfGold,
                              fontSize: 5,
                              letterSpacing: 1,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Right Content
              pw.Expanded(
                child: pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.fromLTRB(26, 26, 20, 20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _nameCtrl.text.toUpperCase().isEmpty
                            ? 'PRATEEK'
                            : _nameCtrl.text.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfNavy,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _titleCtrl.text.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfGold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(width: 40, height: 1.5, color: pdfGold),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        _taglineCtrl.text,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 16),
                      // Summary
                      pw.Text('PROFESSIONAL SUMMARY',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfNavy,
                              letterSpacing: 1)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _summaryCtrl.text,
                        style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.grey800,
                            lineSpacing: 2),
                      ),
                      pw.SizedBox(height: 16),
                      // Experience
                      pw.Text('EXPERIENCE',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfNavy,
                              letterSpacing: 1)),
                      pw.SizedBox(height: 6),
                      ..._expEntries.map((exp) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(exp.role,
                                        style: pw.TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: pw.FontWeight.bold,
                                            color: pdfNavy)),
                                    pw.Text(exp.dates,
                                        style: const pw.TextStyle(
                                            fontSize: 8,
                                            color: PdfColors.grey600)),
                                  ],
                                ),
                                pw.Text(exp.subtitle,
                                    style: pw.TextStyle(
                                        fontSize: 8,
                                        color: pdfGold,
                                        fontStyle: pw.FontStyle.italic)),
                                ...exp.bullets.map((b) => pw.Text(
                                      '• $b',
                                      style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.grey700),
                                    )),
                              ],
                            ),
                          )),
                      pw.Spacer(),
                      // Footer
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFF8F9FB),
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Father: ${_fatherCtrl.text}",
                                style: const pw.TextStyle(
                                    fontSize: 7, color: PdfColors.grey700)),
                            pw.Text("DOB: ${_dobCtrl.text}",
                                style: const pw.TextStyle(
                                    fontSize: 7, color: PdfColors.grey700)),
                            pw.Text("Gender: ${_genderCtrl.text}",
                                style: const pw.TextStyle(
                                    fontSize: 7, color: PdfColors.grey700)),
                            pw.Text("Marital: ${_maritalCtrl.text}",
                                style: const pw.TextStyle(
                                    fontSize: 7, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${_nameCtrl.text.replaceAll(' ', '_')}_Resume.pdf',
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sig = _nameCtrl.text.isEmpty
        ? 'Prateek'
        : _nameCtrl.text
            .split(' ')
            .first
            .toLowerCase()
            .replaceFirst(RegExp(r'.'), _nameCtrl.text[0].toUpperCase());

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C30),
        elevation: 0,
        title: const Text('Mahii Luxury Template',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded,
                color: Colors.white),
            tooltip: 'Export PDF / Print',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: Icon(
                _showControls
                    ? Icons.visibility_off_rounded
                    : Icons.tune_rounded,
                color: Colors.white70),
            tooltip: _showControls ? 'Hide Panel' : 'Show Panel',
            onPressed: () =>
                setState(() => _showControls = !_showControls),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;

          if (isNarrow) {
            // Mobile layout with top tabs
            return Column(
              children: [
                // Top Tab Bar for Mobile
                Container(
                  color: const Color(0xFF0F1C30),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _mobileTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _mobileTab == 0 ? _gold : Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility_rounded,
                                    size: 15,
                                    color: _mobileTab == 0
                                        ? Colors.black
                                        : Colors.white70),
                                const SizedBox(width: 6),
                                Text('View Resume',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _mobileTab == 0
                                            ? Colors.black
                                            : Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _mobileTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _mobileTab == 1 ? _gold : Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tune_rounded,
                                    size: 15,
                                    color: _mobileTab == 1
                                        ? Colors.black
                                        : Colors.white70),
                                const SizedBox(width: 6),
                                Text('Customize',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _mobileTab == 1
                                            ? Colors.black
                                            : Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _mobileTab == 0
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Container(
                                width: 794,
                                constraints:
                                    const BoxConstraints(minHeight: 1123),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.25),
                                        blurRadius: 20,
                                        offset: const Offset(0, 5))
                                  ],
                                ),
                                child: _buildResumeBody(sig),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1A1D26),
                          child: _buildEditPanel(sig),
                        ),
                ),
              ],
            );
          }

          // Desktop/Tablet layout (side by side)
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showControls)
                Container(
                  width: 310,
                  color: const Color(0xFF1A1D26),
                  child: _buildEditPanel(sig),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      width: 794,
                      constraints: const BoxConstraints(minHeight: 1123),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 40,
                              offset: const Offset(0, 10))
                        ],
                      ),
                      child: _buildResumeBody(sig),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EDIT PANEL (LEFT)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildEditPanel(String sig) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // COLOR PALETTE
        _panelSection('🎨 Sidebar Color'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(kMahiiPalettes.length, (i) {
            final pal = kMahiiPalettes[i];
            return GestureDetector(
              onTap: () => setState(() => _paletteIndex = i),
              child: Container(
                width: 54,
                height: 36,
                decoration: BoxDecoration(
                  color: pal.sidebarColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _paletteIndex == i
                        ? pal.goldAccent
                        : Colors.white12,
                    width: _paletteIndex == i ? 2.5 : 1,
                  ),
                ),
                child: _paletteIndex == i
                    ? Icon(Icons.check_rounded,
                        color: pal.goldAccent, size: 18)
                    : null,
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(kMahiiPalettes[_paletteIndex].name,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11)),
        ),

        const SizedBox(height: 14),

        // PHOTO
        _panelSection('📷 Profile Photo'),
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D3A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_a_photo_outlined,
                    color: Colors.white54, size: 16),
                SizedBox(width: 8),
                Text('Choose Photo from Gallery',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // NAME / TITLE / TAGLINE
        _panelSection('✏️ Header'),
        _editField('Full Name', _nameCtrl, onChanged: (_) => setState(() {})),
        _editField('Job Title', _titleCtrl),
        _editField('Tagline', _taglineCtrl),

        const SizedBox(height: 8),

        // CONTACT
        _panelSection('📞 Contact'),
        _editField('Phone', _phoneCtrl),
        _editField('Email', _emailCtrl),
        _editField('Location', _locationCtrl),
        _editField('LinkedIn', _linkedinCtrl),
        _editField('Website', _websiteCtrl),

        const SizedBox(height: 8),

        // SUMMARY
        _panelSection('📝 Professional Summary'),
        _editField('Summary', _summaryCtrl, maxLines: 4),

        const SizedBox(height: 8),

        // SKILLS
        _panelSection('⚡ Skills  (drag bar to adjust level)'),
        ..._skills.asMap().entries.map((e) {
          final i = e.key;
          final skill = e.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(skill.name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11))),
                Text('${(skill.level * 100).round()}%',
                    style: TextStyle(
                        color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _gold,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: _gold,
                  overlayColor: _gold.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: skill.level,
                  min: 0,
                  max: 1,
                  onChanged: (v) => setState(() => _skills[i].level = v),
                ),
              ),
            ],
          );
        }),

        const SizedBox(height: 8),

        // LANGUAGES
        _panelSection('🌐 Languages  (tap dots to adjust)'),
        ..._langs.asMap().entries.map((e) {
          final i = e.key;
          final lang = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.name,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(7, (dotIdx) {
                    final filled = dotIdx < lang.dots;
                    return GestureDetector(
                      onTap: () => setState(
                          () => _langs[i].dots = dotIdx + 1),
                      child: Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: filled ? _gold : Colors.white12,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        // FOOTER
        _panelSection('🗂️ Footer Info'),
        _editField("Father's Name", _fatherCtrl),
        _editField('Date of Birth', _dobCtrl),
        _editField('Gender', _genderCtrl),
        _editField('Marital Status', _maritalCtrl),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _panelSection(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
      );

  Widget _editField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 3),
            TextField(
              controller: ctrl,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              onChanged: onChanged ?? (_) {},
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: const Color(0xFF2A2D3A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: _gold, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════
  // RESUME BODY (RIGHT CANVAS)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildResumeBody(String sig) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── NAVY LEFT SIDEBAR ──────────────────────────────────────────
          _buildSidebar(sig),

          // ── WHITE RIGHT CONTENT ────────────────────────────────────────
          Expanded(child: _buildRightContent()),
        ],
      ),
    );
  }

  // ── LEFT SIDEBAR ──────────────────────────────────────────────────────
  Widget _buildSidebar(String sig) {
    return Stack(
      children: [
        // Main sidebar container
        Container(
          width: 262,
          color: _sidebar,
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── PHOTO ──────────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_gold, _gold.withValues(alpha: 0.5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _sidebar, width: 3),
                          ),
                          child: ClipOval(
                            child: _photoFile != null
                                ? Image.file(_photoFile!,
                                    fit: BoxFit.cover)
                                : Container(
                                    color: _sidebar.withValues(alpha: 0.6),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo_outlined,
                                              color: _gold.withValues(alpha: 0.7),
                                              size: 28),
                                          const SizedBox(height: 4),
                                          Text('Add Photo',
                                              style: TextStyle(
                                                  color: _gold.withValues(alpha: 0.7),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ── CONTACT ───────────────────────────────────────────────
              _sidebarHeading('CONTACT'),
              const SizedBox(height: 8),
              _contactRow(Icons.phone_outlined, _phoneCtrl.text),
              _contactRow(Icons.email_outlined, _emailCtrl.text),
              _contactRow(Icons.location_on_outlined, _locationCtrl.text),
              _contactRow(Icons.link_outlined, _linkedinCtrl.text),
              _contactRow(Icons.language_outlined, _websiteCtrl.text),

              const SizedBox(height: 18),

              // ── EDUCATION ─────────────────────────────────────────────
              _sidebarHeading('EDUCATION'),
              const SizedBox(height: 8),
              ..._eduEntries.asMap().entries.map(
                    (e) => _eduTimelineItem(
                      e.value['degree']!.text,
                      e.value['inst']!.text,
                      e.value['year']!.text,
                      isLast: e.key == _eduEntries.length - 1,
                    ),
                  ),

              const SizedBox(height: 18),

              // ── SKILLS ────────────────────────────────────────────────
              _sidebarHeading('SKILLS'),
              const SizedBox(height: 8),
              ..._skills.map((s) => _skillBarRow(s.name, s.level)),

              const SizedBox(height: 18),

              // ── LANGUAGES ─────────────────────────────────────────────
              _sidebarHeading('LANGUAGES'),
              const SizedBox(height: 8),
              ..._langs.map((l) => _langRow(l.name, l.dots)),

              // ── SIGNATURE ─────────────────────────────────────────────
              const SizedBox(height: 20),
              Divider(color: _gold.withValues(alpha: 0.3), height: 1),
              const SizedBox(height: 14),
              Center(
                child: Column(
                  children: [
                    Text(
                      sig,
                      style: GoogleFonts.alexBrush(
                        fontSize: 38,
                        color: _gold,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DESIGN • CREATE • INSPIRE',
                      style: TextStyle(
                        fontSize: 7,
                        letterSpacing: 1.5,
                        color: _gold.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Gold wave ribbon on right edge
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: CustomPaint(
            size: const Size(28, double.infinity),
            painter: _WaveEdgePainter(
                sidebarColor: _sidebar, goldColor: _gold),
          ),
        ),

        // Decorative dot grid top-right of page
        Positioned(
          top: 12,
          right: 30,
          child: _DotGrid(color: _gold.withValues(alpha: 0.2)),
        ),
      ],
    );
  }

  Widget _sidebarHeading(String title) => Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _gold,
              shape: BoxShape.circle,
            ),
            child: Icon(_headingIcon(title), color: _sidebar, size: 11),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );

  IconData _headingIcon(String t) {
    switch (t) {
      case 'CONTACT': return Icons.person_outline;
      case 'EDUCATION': return Icons.school_outlined;
      case 'SKILLS': return Icons.settings_outlined;
      case 'LANGUAGES': return Icons.language_outlined;
      default: return Icons.circle;
    }
  }

  Widget _contactRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _gold, size: 12),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 9.5, height: 1.3),
              ),
            ),
          ],
        ),
      );

  Widget _eduTimelineItem(String degree, String inst, String year,
      {bool isLast = false}) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 16,
              child: Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: _gold, shape: BoxShape.circle),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: _gold.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(degree,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3)),
                    const SizedBox(height: 2),
                    Text(inst,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 8.5,
                            height: 1.3)),
                    Text(year,
                        style: TextStyle(
                            color: _gold.withValues(alpha: 0.8),
                            fontSize: 8,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _skillBarRow(String name, double level) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: level,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(_gold),
              ),
            ),
          ],
        ),
      );

  Widget _langRow(String name, int dots) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 9.5)),
            ),
            ...List.generate(7, (i) => Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: i < dots ? _gold : Colors.white12,
                    shape: BoxShape.circle,
                  ),
                )),
          ],
        ),
      );

  // ── RIGHT CONTENT ─────────────────────────────────────────────────────
  Widget _buildRightContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(36, 36, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── NAME HEADER ───────────────────────────────────────────────
          ListenableBuilder(
            listenable: Listenable.merge([_nameCtrl, _titleCtrl, _taglineCtrl]),
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dot grid top right
                Align(
                  alignment: Alignment.topRight,
                  child: _DotGrid(
                      color: _sidebar.withValues(alpha: 0.12), rows: 4, cols: 6),
                ),
                Text(
                  _nameCtrl.text.toUpperCase().isEmpty
                      ? 'PRATEEK'
                      : _nameCtrl.text.toUpperCase(),
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: _sidebar,
                    letterSpacing: 2,
                    height: 1,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _titleCtrl.text.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _gold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                      width: 40,
                      height: 1.5,
                      color: _gold),
                  const SizedBox(width: 6),
                  Icon(Icons.diamond_outlined, color: _gold, size: 10),
                  const SizedBox(width: 6),
                  Container(
                      width: 40,
                      height: 1.5,
                      color: _gold),
                ]),
                const SizedBox(height: 8),
                Text(
                  _taglineCtrl.text,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      letterSpacing: 1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── PROFESSIONAL SUMMARY ──────────────────────────────────────
          _rightSectionHeading('PROFESSIONAL SUMMARY'),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: _summaryCtrl,
            builder: (context, _) => _bulletPoint(_summaryCtrl.text),
          ),

          const SizedBox(height: 16),

          // ── EXPERIENCE ────────────────────────────────────────────────
          _rightSectionHeading('EXPERIENCE'),
          const SizedBox(height: 8),
          ..._expEntries.map((exp) => _expBlock(exp)),

          const SizedBox(height: 12),

          // ── EXPERTISE & ACHIEVEMENTS ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rightSectionHeading('EXPERTISE'),
                    const SizedBox(height: 8),
                    ..._expertiseCtrls
                        .map((c) => _checkItem(c.text)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rightSectionHeading('ACHIEVEMENTS'),
                    const SizedBox(height: 8),
                    ..._achievements.map((a) => _achieveItem(
                        a['title']!.text, a['sub']!.text)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── FOOTER STRIP ──────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _footerItem(Icons.person_outline, "FATHER'S NAME",
                    _fatherCtrl.text),
                _footerItem(Icons.calendar_month_outlined, 'DATE OF BIRTH',
                    _dobCtrl.text),
                _footerItem(Icons.transgender_outlined, 'GENDER',
                    _genderCtrl.text),
                _footerItem(Icons.favorite_outline, 'MARITAL STATUS',
                    _maritalCtrl.text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rightSectionHeading(String title) {
    IconData icon;
    switch (title) {
      case 'PROFESSIONAL SUMMARY': icon = Icons.person_outline; break;
      case 'EXPERIENCE': icon = Icons.work_outline; break;
      case 'EXPERTISE': icon = Icons.emoji_events_outlined; break;
      case 'ACHIEVEMENTS': icon = Icons.military_tech_outlined; break;
      default: icon = Icons.circle;
    }
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _sidebar,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _gold, size: 13),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _sidebar,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _bulletPoint(String text) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                      color: _gold, shape: BoxShape.circle)),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: Colors.grey[700])),
            ),
          ],
        ),
      );

  Widget _expBlock(_ExpEntry exp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold circle dot on left timeline
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: _gold, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(exp.role,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _sidebar)),
                    ),
                    Row(
                      children: [
                        Text(exp.dates,
                            style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.calendar_today_outlined,
                            size: 10, color: Colors.grey[400]),
                      ],
                    ),
                  ],
                ),
                Text(exp.subtitle,
                    style: TextStyle(
                        fontSize: 10,
                        color: _gold,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...exp.bullets.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey)),
                          Expanded(
                            child: Text(b,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.4,
                                    color: Colors.grey[700])),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkItem(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 13, color: _gold),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey[700])),
            ),
          ],
        ),
      );

  Widget _achieveItem(String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.star_rounded, color: _gold, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _sidebar)),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 9.5, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _footerItem(IconData icon, String label, String value) => Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 7,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _sidebar)),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════
// CustomPainter — Gold Wave Edge on Sidebar Right
// ═══════════════════════════════════════════════════════════════════════
class _WaveEdgePainter extends CustomPainter {
  final Color sidebarColor;
  final Color goldColor;
  const _WaveEdgePainter({required this.sidebarColor, required this.goldColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = sidebarColor;
    final goldPaint = Paint()
      ..color = goldColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(
          size.width * 1.2, size.height * 0.15,
          -size.width * 0.2, size.height * 0.35,
          size.width * 1.0, size.height * 0.5)
      ..cubicTo(
          size.width * 1.2, size.height * 0.65,
          -size.width * 0.2, size.height * 0.85,
          size.width * 1.0, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, goldPaint);
  }

  @override
  bool shouldRepaint(covariant _WaveEdgePainter oldDelegate) =>
      oldDelegate.sidebarColor != sidebarColor ||
      oldDelegate.goldColor != goldColor;
}

// ═══════════════════════════════════════════════════════════════════════
// Small dot grid decoration widget
// ═══════════════════════════════════════════════════════════════════════
class _DotGrid extends StatelessWidget {
  final Color color;
  final int rows;
  final int cols;
  const _DotGrid({required this.color, this.rows = 5, this.cols = 5});

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          rows,
          (r) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              cols,
              (c) => Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      );
}

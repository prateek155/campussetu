import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ────────────────────────────────────────────────────────────────────────────
// MATHEW EXECUTIVE RESUME — Professional Category
// Architectural Curved Cutout, High-Contrast Pill Badges & Contact Tabs
// Fully in-place customizable with 6 adaptive color palettes & 1:1 PDF export
// ────────────────────────────────────────────────────────────────────────────

class _MathewPalette {
  final String name;
  final Color accent;
  final Color sidebarBg;

  const _MathewPalette({
    required this.name,
    required this.accent,
    required this.sidebarBg,
  });
}

const List<_MathewPalette> kMathewPalettes = [
  // 1. Mustard Gold (Default as original design)
  _MathewPalette(
    name: 'Mustard Gold',
    accent: Color(0xFFF5B800),
    sidebarBg: Color(0xFF1B1D22),
  ),
  // 2. Royal Blue
  _MathewPalette(
    name: 'Royal Blue',
    accent: Color(0xFF2563EB),
    sidebarBg: Color(0xFF0F172A),
  ),
  // 3. Crimson Red
  _MathewPalette(
    name: 'Crimson Red',
    accent: Color(0xFFDC2626),
    sidebarBg: Color(0xFF1C1917),
  ),
  // 4. Emerald Green
  _MathewPalette(
    name: 'Emerald Green',
    accent: Color(0xFF059669),
    sidebarBg: Color(0xFF132E27),
  ),
  // 5. Sky Blue
  _MathewPalette(
    name: 'Sky Blue',
    accent: Color(0xFF0284C7),
    sidebarBg: Color(0xFF0B1E2D),
  ),
  // 6. Royal Purple
  _MathewPalette(
    name: 'Royal Purple',
    accent: Color(0xFF7C3AED),
    sidebarBg: Color(0xFF1E1035),
  ),
];

class _ExpItem {
  final TextEditingController datesCtrl;
  final TextEditingController roleCtrl;
  final TextEditingController companyCtrl;
  final TextEditingController descCtrl;

  _ExpItem({
    required String dates,
    required String role,
    required String company,
    required String desc,
  })  : datesCtrl = TextEditingController(text: dates),
        roleCtrl = TextEditingController(text: role),
        companyCtrl = TextEditingController(text: company),
        descCtrl = TextEditingController(text: desc);
}

class _EduItem {
  final TextEditingController majorCtrl;
  final TextEditingController uniCtrl;
  final TextEditingController yearsCtrl;

  _EduItem({
    required String major,
    required String uni,
    required String years,
  })  : majorCtrl = TextEditingController(text: major),
        uniCtrl = TextEditingController(text: uni),
        yearsCtrl = TextEditingController(text: years);
}

class _RefItem {
  final TextEditingController nameCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController phoneCtrl;

  _RefItem({
    required String name,
    required String title,
    required String phone,
  })  : nameCtrl = TextEditingController(text: name),
        titleCtrl = TextEditingController(text: title),
        phoneCtrl = TextEditingController(text: phone);
}

class _SkillItem {
  final TextEditingController nameCtrl;
  double level;

  _SkillItem(String name, this.level)
      : nameCtrl = TextEditingController(text: name);
}

class MathewExecutiveTemplate extends StatefulWidget {
  const MathewExecutiveTemplate({super.key});

  @override
  State<MathewExecutiveTemplate> createState() =>
      _MathewExecutiveTemplateState();
}

class _MathewExecutiveTemplateState extends State<MathewExecutiveTemplate> {
  int _paletteIndex = 0;
  bool _showTools = true;
  Uint8List? _photoBytes;

  _MathewPalette get _pal => kMathewPalettes[_paletteIndex];
  Color get _accent => _pal.accent;
  Color get _sidebar => _pal.sidebarBg;

  // Header controllers
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _titleCtrl;

  // About Me controller
  late TextEditingController _aboutCtrl;

  // Contact controllers
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _addressCtrl;

  // Dynamic lists
  late List<_ExpItem> _expList;
  late List<_EduItem> _eduList;
  late List<_RefItem> _refList;
  late List<_SkillItem> _skills;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: 'MATHEW');
    _lastNameCtrl = TextEditingController(text: 'PARKER');
    _titleCtrl = TextEditingController(text: 'GRAPHIC DESIGNER');

    _aboutCtrl = TextEditingController(
      text:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Quis ipsum suspendisse ultrices gravida.',
    );

    _phoneCtrl = TextEditingController(text: '+000 123 456 789');
    _emailCtrl = TextEditingController(text: 'yourname@gmail.com');
    _websiteCtrl = TextEditingController(text: 'yourwebsite.com');
    _addressCtrl =
        TextEditingController(text: 'Your street address, City - 123');

    _expList = [
      _ExpItem(
        dates: '2019–2022',
        role: 'JOB POSITION HERE',
        company: 'Company Name / California USA',
        desc:
            'Lorem ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the text ever since the 1500s when an unknown printer.',
      ),
      _ExpItem(
        dates: '2022–2024',
        role: 'JOB POSITION HERE',
        company: 'Company Name / California USA',
        desc:
            'Lorem ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the text ever since the 1500s when an unknown printer.',
      ),
      _ExpItem(
        dates: '2024–Present',
        role: 'JOB POSITION HERE',
        company: 'Company Name / California USA',
        desc:
            'Lorem ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the text ever since the 1500s when an unknown printer.',
      ),
    ];

    _eduList = [
      _EduItem(
        major: 'ENTER YOUR MAJOR',
        uni: 'Name Of Your University',
        years: '2013–2017',
      ),
      _EduItem(
        major: 'ENTER YOUR MAJOR',
        uni: 'Name Of Your University',
        years: '2017–2019',
      ),
    ];

    _refList = [
      _RefItem(
        name: 'Lorem Ipsum',
        title: 'Director | Company Name',
        phone: 'T: +1 234 56789',
      ),
      _RefItem(
        name: 'Lorem Ipsum',
        title: 'Sr. Graphic Designer | Company',
        phone: 'T: +1 234 56789',
      ),
    ];

    _skills = [
      _SkillItem('Adobe Photoshop', 0.85),
      _SkillItem('Adobe After Effects', 0.75),
      _SkillItem('Adobe Illustrator', 0.80),
      _SkillItem('Adobe Premiere Pro', 0.70),
      _SkillItem('Adobe InDesign', 0.65),
      _SkillItem('Figma & UI Design', 0.88),
    ];
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _titleCtrl.dispose();
    _aboutCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    for (final e in _expList) {
      e.datesCtrl.dispose();
      e.roleCtrl.dispose();
      e.companyCtrl.dispose();
      e.descCtrl.dispose();
    }
    for (final ed in _eduList) {
      ed.majorCtrl.dispose();
      ed.uniCtrl.dispose();
      ed.yearsCtrl.dispose();
    }
    for (final r in _refList) {
      r.nameCtrl.dispose();
      r.titleCtrl.dispose();
      r.phoneCtrl.dispose();
    }
    for (final s in _skills) {
      s.nameCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 92,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _photoBytes = bytes);
    }
  }

  void _clearPhoto() {
    setState(() => _photoBytes = null);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HIGH-QUALITY PDF EXPORT (1:1 PIXEL PERFECT A4 MATCH)
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final pdfAccent = PdfColor.fromInt(_accent.toARGB32());
    final pdfSidebar = PdfColor.fromInt(_sidebar.toARGB32());

    pw.Font regularFont = pw.Font.helvetica();
    pw.Font boldFont = pw.Font.helveticaBold();
    try {
      regularFont = await PdfGoogleFonts.plusJakartaSansRegular();
      boldFont = await PdfGoogleFonts.plusJakartaSansBold();
    } catch (e) {
      debugPrint('Font fallback: $e');
    }

    String clean(String s) => s
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('•', '')
        .trim();

    // Helper: Yellow Section Badge
    pw.Widget pdfSectionBadge(String title) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: pw.BoxDecoration(
          color: pdfAccent,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    // Helper: Contact Tab Row
    pw.Widget pdfContactTab(String tab, String value) {
      final v = clean(value);
      if (v.isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: pdfAccent,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2.5)),
              ),
              child: pw.Text(
                tab,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 6.2,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.SizedBox(height: 1.5),
            pw.Text(
              v,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 7.2,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Stack(
            children: [
              // 1. Full White Canvas
              pw.Container(color: PdfColors.white),

              // 2. Yellow Hanging Top Pill (Width 36, Height 65)
              pw.Positioned(
                top: 0,
                left: 200,
                child: pw.Container(
                  width: 36,
                  height: 65,
                  decoration: pw.BoxDecoration(
                    color: pdfAccent,
                    borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(18),
                      bottomRight: pw.Radius.circular(18),
                    ),
                  ),
                ),
              ),

              // 3. Main Row (Sidebar + Right Content)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // ── LEFT SIDEBAR (Width 185pt) ──
                  pw.Container(
                    width: 185,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Top Photo Block with bottom-right curve
                        pw.Container(
                          height: 155,
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF2B2D33),
                            borderRadius: pw.BorderRadius.only(
                              bottomRight: pw.Radius.circular(45),
                            ),
                          ),
                          child: _photoBytes != null
                              ? pw.ClipRRect(
                                  horizontalRadius: 45,
                                  child: pw.Image(
                                    pw.MemoryImage(_photoBytes!),
                                    fit: pw.BoxFit.cover,
                                  ),
                                )
                              : pw.Center(
                                  child: pw.Text(
                                    'PHOTO',
                                    style: pw.TextStyle(
                                      font: boldFont,
                                      color: PdfColors.grey500,
                                      fontSize: 10,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                        ),

                        pw.SizedBox(height: 10),

                        // Dark Lower Sidebar with top-right curve
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.fromLTRB(16, 18, 16, 14),
                            decoration: pw.BoxDecoration(
                              color: pdfSidebar,
                              borderRadius: const pw.BorderRadius.only(
                                topRight: pw.Radius.circular(55),
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                // EDUCATION
                                pdfSectionBadge('EDUCATION'),
                                pw.SizedBox(height: 8),
                                ..._eduList.map((ed) => pw.Padding(
                                      padding:
                                          const pw.EdgeInsets.only(bottom: 7),
                                      child: pw.Column(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text(
                                            clean(ed.majorCtrl.text),
                                            style: pw.TextStyle(
                                              font: boldFont,
                                              fontSize: 7.8,
                                              fontWeight: pw.FontWeight.bold,
                                              color: PdfColors.white,
                                            ),
                                          ),
                                          pw.Text(
                                            clean(ed.uniCtrl.text),
                                            style: pw.TextStyle(
                                              font: regularFont,
                                              fontSize: 6.8,
                                              color: PdfColors.grey400,
                                            ),
                                          ),
                                          pw.Text(
                                            clean(ed.yearsCtrl.text),
                                            style: pw.TextStyle(
                                              font: boldFont,
                                              fontSize: 6.8,
                                              color: pdfAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),

                                pw.SizedBox(height: 12),

                                // REFERENCE
                                pdfSectionBadge('REFERENCE'),
                                pw.SizedBox(height: 8),
                                ..._refList.map((r) => pw.Padding(
                                      padding:
                                          const pw.EdgeInsets.only(bottom: 7),
                                      child: pw.Column(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text(
                                            clean(r.nameCtrl.text),
                                            style: pw.TextStyle(
                                              font: boldFont,
                                              fontSize: 7.8,
                                              fontWeight: pw.FontWeight.bold,
                                              color: PdfColors.white,
                                            ),
                                          ),
                                          pw.Text(
                                            clean(r.titleCtrl.text),
                                            style: pw.TextStyle(
                                              font: regularFont,
                                              fontSize: 6.8,
                                              color: PdfColors.grey400,
                                            ),
                                          ),
                                          pw.Text(
                                            clean(r.phoneCtrl.text),
                                            style: pw.TextStyle(
                                              font: regularFont,
                                              fontSize: 6.8,
                                              color: PdfColors.grey400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),

                                pw.Spacer(),

                                // CONTACT TABS
                                pdfContactTab('Phone', _phoneCtrl.text),
                                pdfContactTab('Email', _emailCtrl.text),
                                pdfContactTab('website', _websiteCtrl.text),
                                pdfContactTab('Address', _addressCtrl.text),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── RIGHT CONTENT (Width 410pt) ──
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(24, 28, 24, 18),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Header Name & Title
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 45),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  clean(_firstNameCtrl.text),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold,
                                    color: const PdfColor.fromInt(0xFF111827),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                pw.Text(
                                  clean(_lastNameCtrl.text),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 22,
                                    fontWeight: pw.FontWeight.bold,
                                    color: const PdfColor.fromInt(0xFF1F2937),
                                    letterSpacing: 2,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  clean(_titleCtrl.text),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 8.8,
                                    color: const PdfColor.fromInt(0xFF4B5563),
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          pw.SizedBox(height: 18),

                          // ABOUT ME
                          pdfSectionBadge('ABOUT ME'),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            clean(_aboutCtrl.text),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 8.2,
                              color: const PdfColor.fromInt(0xFF1E293B),
                              lineSpacing: 1.45,
                            ),
                          ),

                          pw.SizedBox(height: 16),

                          // WORK EXPERIENCE
                          pdfSectionBadge('WORK EXPERIENCE'),
                          pw.SizedBox(height: 8),
                          ..._expList.map((exp) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 9),
                                child: pw.Row(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    // Left Dates column
                                    pw.Container(
                                      width: 62,
                                      child: pw.Text(
                                        clean(exp.datesCtrl.text),
                                        style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 7.6,
                                          fontWeight: pw.FontWeight.bold,
                                          color: const PdfColor.fromInt(
                                              0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    pw.SizedBox(width: 8),
                                    // Right Job & Description
                                    pw.Expanded(
                                      child: pw.Column(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text(
                                            clean(exp.roleCtrl.text),
                                            style: pw.TextStyle(
                                              font: boldFont,
                                              fontSize: 8.8,
                                              fontWeight: pw.FontWeight.bold,
                                              color: const PdfColor.fromInt(
                                                  0xFF111827),
                                            ),
                                          ),
                                          pw.Text(
                                            clean(exp.companyCtrl.text),
                                            style: pw.TextStyle(
                                              font: regularFont,
                                              fontSize: 7.6,
                                              color: const PdfColor.fromInt(
                                                  0xFF475569),
                                            ),
                                          ),
                                          pw.SizedBox(height: 2),
                                          pw.Text(
                                            clean(exp.descCtrl.text),
                                            style: pw.TextStyle(
                                              font: regularFont,
                                              fontSize: 7.6,
                                              color: const PdfColor.fromInt(
                                                  0xFF334155),
                                              lineSpacing: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),

                          pw.SizedBox(height: 14),

                          // SOFTWARE SKILL
                          pdfSectionBadge('SOFTWARE SKILL'),
                          pw.SizedBox(height: 8),
                          pw.Wrap(
                            spacing: 16,
                            runSpacing: 7,
                            children: _skills.map((s) {
                              return pw.Container(
                                width: 170,
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Row(
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text(
                                          clean(s.nameCtrl.text),
                                          style: pw.TextStyle(
                                            font: boldFont,
                                            fontSize: 7.6,
                                            color: const PdfColor.fromInt(
                                                0xFF1E293B),
                                          ),
                                        ),
                                        pw.Text(
                                          '${(s.level * 100).round()}%',
                                          style: pw.TextStyle(
                                            font: boldFont,
                                            fontSize: 7.0,
                                            color: pdfAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Container(
                                      height: 3,
                                      width: 170,
                                      decoration: const pw.BoxDecoration(
                                        color: PdfColor.fromInt(0xFFE2E8F0),
                                        borderRadius: pw.BorderRadius.all(
                                            pw.Radius.circular(1.5)),
                                      ),
                                      child: pw.Align(
                                        alignment: pw.Alignment.centerLeft,
                                        child: pw.Container(
                                          height: 3,
                                          width: 170 * s.level,
                                          decoration: pw.BoxDecoration(
                                            color: pdfAccent,
                                            borderRadius:
                                                const pw.BorderRadius.all(
                                                    pw.Radius.circular(1.5)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final fullName =
        '${clean(_firstNameCtrl.text)}_${clean(_lastNameCtrl.text)}'
            .replaceAll(' ', '_');
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${fullName}_Resume.pdf',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD SCREEN (Interactive Canvas + Tool Panel)
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1D22),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Mathew Executive',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PROFESSIONAL',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showTools ? 'Hide Palette Panel' : 'Show Palette Panel',
            icon: Icon(
              _showTools ? Icons.tune_rounded : Icons.tune_outlined,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _showTools = !_showTools),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _exportPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.download_rounded, size: 17),
              label: const Text(
                'Download PDF',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showTools)
                Container(
                  width: 320,
                  color: const Color(0xFF16181D),
                  child: _buildToolSidebar(),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: _buildA4Sheet(),
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
  // TOOL PANEL (Colors, Photo, Quick Helpers)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildToolSidebar() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _toolHeader('ACCENT COLOR PALETTE'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kMathewPalettes.asMap().entries.map((entry) {
            final idx = entry.key;
            final pal = entry.value;
            final isSel = idx == _paletteIndex;
            return GestureDetector(
              onTap: () => setState(() => _paletteIndex = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 135,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSel
                      ? pal.accent.withValues(alpha: 0.15)
                      : const Color(0xFF22252C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel ? pal.accent : Colors.white12,
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: pal.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: pal.accent.withValues(alpha: 0.5),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pal.name,
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight:
                              isSel ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        _toolHeader('PHOTO SETTINGS'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                label: const Text('Change Photo',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (_photoBytes != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove custom photo',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                onPressed: _clearPhoto,
              ),
            ],
          ],
        ),

        const SizedBox(height: 24),
        _toolHeader('HOW TO EDIT'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF22252C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            children: [
              Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Click directly on any text on the resume canvas to edit, copy, paste, or tweak!',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolHeader(String title) => Text(
        title,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════
  // A4 CANVAS CONTAINER (Width 794px, Height ~1123px)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildA4Sheet() {
    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Yellow Top Hanging Pill (Fixed Architectural Detail)
          Positioned(
            top: 0,
            left: 295,
            child: Container(
              width: 58,
              height: 92,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(29),
                  bottomRight: Radius.circular(29),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // Main Layout Row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── LEFT SIDEBAR ──────────────────────────────────────────
                _buildSidebar(),

                // ── RIGHT CONTENT CANVAS ──────────────────────────────────
                Expanded(child: _buildRightContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LEFT SIDEBAR (Architectural Curved Photo + Dark Curved Body + Contact)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildSidebar() {
    return SizedBox(
      width: 270,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── TOP PHOTO CONTAINER with Bottom-Right Curve ────────────────
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              height: 220,
              decoration: const BoxDecoration(
                color: Color(0xFF22252C),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(65),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(65),
                ),
                child: _photoBytes != null
                    ? Image.memory(
                        _photoBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Stack(
                        children: [
                          Center(
                            child: Icon(
                              Icons.person_rounded,
                              size: 110,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            left: 18,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_outlined,
                                      color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Tap to change photo',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── LOWER DARK SIDEBAR CONTAINER with Top-Right Curve ──────────
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 26, 24),
              decoration: BoxDecoration(
                color: _sidebar,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(75),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── EDUCATION ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionBadge('EDUCATION'),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded,
                              color: _accent, size: 17),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Add Education',
                          onPressed: () {
                            setState(() {
                              _eduList.add(_EduItem(
                                major: 'ENTER YOUR MAJOR',
                                uni: 'Name Of Your University',
                                years: '2020–2024',
                              ));
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._eduList.asMap().entries.map((e) {
                    final i = e.key;
                    final ed = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _InlineField(
                                  controller: ed.majorCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_eduList.length > 1)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 6, right: 2),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _eduList.removeAt(i)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          color: Colors.white70, size: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          _InlineField(
                            controller: ed.uniCtrl,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10),
                          ),
                          _InlineField(
                            controller: ed.yearsCtrl,
                            style: TextStyle(
                              color: _accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 18),

                  // ── REFERENCE ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionBadge('REFERENCE'),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded,
                              color: _accent, size: 17),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Add Reference',
                          onPressed: () {
                            setState(() {
                              _refList.add(_RefItem(
                                name: 'Full Name',
                                title: 'Designation | Company',
                                phone: 'T: +1 234 56789',
                              ));
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._refList.asMap().entries.map((e) {
                    final i = e.key;
                    final r = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _InlineField(
                                  controller: r.nameCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_refList.length > 1)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 6, right: 2),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _refList.removeAt(i)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          color: Colors.white70, size: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          _InlineField(
                            controller: r.titleCtrl,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10),
                          ),
                          _InlineField(
                            controller: r.phoneCtrl,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 9.5),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Spacer(),

                  // ── CONTACT TABS (DISTINCTIVE BOTTOM DETAIL) ───────────
                  _contactTab('Phone', _phoneCtrl),
                  const SizedBox(height: 8),
                  _contactTab('Email', _emailCtrl),
                  const SizedBox(height: 8),
                  _contactTab('website', _websiteCtrl),
                  const SizedBox(height: 8),
                  _contactTab('Address', _addressCtrl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RIGHT CONTENT (Header Name, About Me, Experience & Software Skills)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildRightContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(36, 38, 36, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP HEADER (First Name, Last Name, Subtitle) ──────────────
          Padding(
            padding: const EdgeInsets.only(left: 65),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InlineField(
                  controller: _firstNameCtrl,
                  style: GoogleFonts.montserrat(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: const Color(0xFF111827),
                    height: 1.05,
                  ),
                ),
                _InlineField(
                  controller: _lastNameCtrl,
                  style: GoogleFonts.montserrat(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: const Color(0xFF1F2937),
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                _InlineField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.5,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── ABOUT ME ──────────────────────────────────────────────────
          _sectionBadge('ABOUT ME'),
          const SizedBox(height: 8),
          _InlineField(
            controller: _aboutCtrl,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: Color(0xFF1E293B),
            ),
          ),

          const SizedBox(height: 24),

          // ── WORK EXPERIENCE ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionBadge('WORK EXPERIENCE'),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _expList.add(_ExpItem(
                      dates: '2024–Present',
                      role: 'JOB POSITION HERE',
                      company: 'Company Name / City',
                      desc:
                          'Key achievement or responsibility description goes here.',
                    ));
                  });
                },
                icon: Icon(Icons.add_rounded, size: 14, color: _sidebar),
                label: Text(
                  'Add Experience',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _sidebar,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._expList.asMap().entries.map((e) {
            final i = e.key;
            final exp = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Dates Column
                  SizedBox(
                    width: 90,
                    child: _InlineField(
                      controller: exp.datesCtrl,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Right Role, Company, Desc
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _InlineField(
                                controller: exp.roleCtrl,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            if (_expList.length > 1)
                              GestureDetector(
                                onTap: () => setState(
                                    () => _expList.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      size: 11, color: Colors.black54),
                                ),
                              ),
                          ],
                        ),
                        _InlineField(
                          controller: exp.companyCtrl,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _InlineField(
                          controller: exp.descCtrl,
                          maxLines: 3,
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.45,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // ── SOFTWARE SKILLS ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionBadge('SOFTWARE SKILL'),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _skills.add(_SkillItem('New Skill', 0.75));
                  });
                },
                icon: Icon(Icons.add_rounded, size: 14, color: _sidebar),
                label: Text(
                  'Add Skill',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _sidebar,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: _skills.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return SizedBox(
                width: 205,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _InlineField(
                            controller: s.nameCtrl,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Text(
                          '${(s.level * 100).round()}%',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _accent,
                          ),
                        ),
                        if (_skills.length > 1) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _skills.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  size: 10, color: Colors.black54),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          s.level = (details.localPosition.dx / 205)
                              .clamp(0.05, 1.0);
                        });
                      },
                      onTapDown: (details) {
                        setState(() {
                          s.level = (details.localPosition.dx / 205)
                              .clamp(0.05, 1.0);
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          height: 4,
                          color: const Color(0xFFE2E8F0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: s.level,
                              child: Container(color: _accent),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REUSABLE BADGES & CONTACT CARD HELPERS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _sectionBadge(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _contactTab(String tab, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tab,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 2),
        _InlineField(
          controller: ctrl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// INLINE EDITABLE TEXT FIELD WIDGET
// ═══════════════════════════════════════════════════════════════════════
class _InlineField extends StatelessWidget {
  final TextEditingController controller;
  final TextStyle style;
  final int maxLines;

  const _InlineField({
    required this.controller,
    required this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: style,
      cursorColor: style.color ?? Colors.blue,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: (style.color ?? Colors.blue).withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

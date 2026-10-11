import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ────────────────────────────────────────────────────────────────────────────
// MAHII LUXURY RESUME — Professional Category
// Canva-style Direct In-Place On-Canvas Editing with 5 Adaptive Color Palettes
// ────────────────────────────────────────────────────────────────────────────

class _MahiiPalette {
  final String name;
  final Color sidebarColor;
  final Color goldAccent;
  final Color indicatorColor; // High-contrast color for skill bars & dots
  final Color trackColor;
  final Color dotInactiveColor;

  const _MahiiPalette({
    required this.name,
    required this.sidebarColor,
    required this.goldAccent,
    required this.indicatorColor,
    required this.trackColor,
    required this.dotInactiveColor,
  });
}

final List<_MahiiPalette> kMahiiPalettes = [
  // 1. Blue (Deep Executive Navy)
  const _MahiiPalette(
    name: 'Blue',
    sidebarColor: Color(0xFF0F1C30),
    goldAccent: Color(0xFFC5A059),
    indicatorColor: Color(0xFFFFB800), // Vibrant Amber Gold
    trackColor: Color(0x33FFFFFF),
    dotInactiveColor: Color(0x2BFFFFFF),
  ),
  // 2. Red (Royal Crimson)
  const _MahiiPalette(
    name: 'Red',
    sidebarColor: Color(0xFF7A1526),
    goldAccent: Color(0xFFFCD34D),
    indicatorColor: Color(0xFFFACC15), // Luminous Warm Gold
    trackColor: Color(0x33FFFFFF),
    dotInactiveColor: Color(0x2BFFFFFF),
  ),
  // 3. Sky Blue (Crisp Modern Sky)
  const _MahiiPalette(
    name: 'Sky Blue',
    sidebarColor: Color(0xFF0284C7),
    goldAccent: Color(0xFFFFFFFF),
    indicatorColor: Color(0xFFFFFFFF), // Pure Crisp White pops on Sky Blue!
    trackColor: Color(0x40000000),
    dotInactiveColor: Color(0x40FFFFFF),
  ),
  // 4. Grey (Slate Graphite)
  const _MahiiPalette(
    name: 'Grey',
    sidebarColor: Color(0xFF334155),
    goldAccent: Color(0xFFE2B866),
    indicatorColor: Color(0xFF38BDF8), // Electric Cyan pops on Grey!
    trackColor: Color(0x33FFFFFF),
    dotInactiveColor: Color(0x2BFFFFFF),
  ),
  // 5. Golden (Dark Antique Bronze / Deep Amber)
  const _MahiiPalette(
    name: 'Golden',
    sidebarColor: Color(0xFF4A3510),
    goldAccent: Color(0xFFFEF08A),
    indicatorColor: Color(0xFFFFFFFF), // Crisp White so it never blends in!
    trackColor: Color(0x4A000000),
    dotInactiveColor: Color(0x38FFFFFF),
  ),
];

// ─── Editable Models ────────────────────────────────────────────────────────
class _SkillItem {
  TextEditingController nameCtrl;
  double level; // 0.0 – 1.0
  _SkillItem(String name, this.level)
      : nameCtrl = TextEditingController(text: name);

  void dispose() => nameCtrl.dispose();
}

class _LangItem {
  TextEditingController nameCtrl;
  int dots; // 1–7 filled out of 7
  _LangItem(String name, this.dots)
      : nameCtrl = TextEditingController(text: name);

  void dispose() => nameCtrl.dispose();
}

class _EduItem {
  TextEditingController degreeCtrl;
  TextEditingController instCtrl;
  TextEditingController yearCtrl;
  _EduItem({required String degree, required String inst, required String year})
      : degreeCtrl = TextEditingController(text: degree),
        instCtrl = TextEditingController(text: inst),
        yearCtrl = TextEditingController(text: year);

  void dispose() {
    degreeCtrl.dispose();
    instCtrl.dispose();
    yearCtrl.dispose();
  }
}

class _ExpItem {
  TextEditingController roleCtrl;
  TextEditingController subtitleCtrl;
  TextEditingController datesCtrl;
  List<TextEditingController> bulletCtrls;

  _ExpItem({
    required String role,
    required String subtitle,
    required String dates,
    required List<String> bullets,
  })  : roleCtrl = TextEditingController(text: role),
        subtitleCtrl = TextEditingController(text: subtitle),
        datesCtrl = TextEditingController(text: dates),
        bulletCtrls = bullets.map((b) => TextEditingController(text: b)).toList();

  void dispose() {
    roleCtrl.dispose();
    subtitleCtrl.dispose();
    datesCtrl.dispose();
    for (final b in bulletCtrls) {
      b.dispose();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MahiiLuxuryTemplate  — Root Widget
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
  Color get _indicator => _pal.indicatorColor;

  // ─── Photo (cross-platform Uint8List bytes) ─────────────────────────────
  Uint8List? _photoBytes;
  bool _isPickingPhoto = false;

  // ─── Header fields ─────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController(text: 'PRATEEK');
  final _titleCtrl = TextEditingController(text: 'GRAPHIC DESIGNER');
  final _taglineCtrl =
      TextEditingController(text: 'Creative  •  Detail-Oriented  •  Dedicated');
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
  final List<_EduItem> _eduEntries = [
    _EduItem(
      degree: 'Bachelor of Science Computer Science',
      inst: 'AISECT University, Bhopal',
      year: '2019 – 2023',
    ),
    _EduItem(
      degree: 'HSC (Pre-Engineering)',
      inst: 'Govt. Model School',
      year: '2017 – 2019',
    ),
    _EduItem(
      degree: 'Matric (Science)',
      inst: 'Govt. High School, Bhopal',
      year: '2015 – 2017',
    ),
  ];

  // ─── Skills ────────────────────────────────────────────────────────────
  final List<_SkillItem> _skills = [
    _SkillItem('Adobe Photoshop', 0.90),
    _SkillItem('Adobe Illustrator', 0.85),
    _SkillItem('Canva / Figma', 0.80),
    _SkillItem('Branding & Logo', 0.75),
    _SkillItem('Flutter / Dart', 0.88),
    _SkillItem('UI / UX Prototyping', 0.82),
    _SkillItem('Typography & Print', 0.70),
  ];

  // ─── Languages ─────────────────────────────────────────────────────────
  final List<_LangItem> _langs = [
    _LangItem('Urdu / Hindi', 7),
    _LangItem('English', 6),
  ];

  // ─── Experience ────────────────────────────────────────────────────────
  final List<_ExpItem> _expEntries = [
    _ExpItem(
      role: 'Senior Graphic Designer',
      subtitle: 'Creative Studio Pvt. Ltd.',
      dates: '2023 – Present',
      bullets: [
        'Designed high-converting branding assets, logos, and digital marketing banners.',
        'Collaborated with cross-functional teams to deliver pixel-perfect user experiences.',
      ],
    ),
    _ExpItem(
      role: 'UI/UX & Visual Designer (Freelance)',
      subtitle: 'Self-Employed',
      dates: '2022 – 2023',
      bullets: [
        'Delivered 20+ responsive web & mobile app visual prototypes for global clients.',
        'Structured complete brand identity systems including typography and color systems.',
      ],
    ),
    _ExpItem(
      role: 'Computer Graphics Instructor',
      subtitle: 'Private Academy, Bhopal',
      dates: '2021 – 2022',
      bullets: [
        'Taught digital design, image manipulation, and vector illustration to 60+ students.',
        'Managed student capstone design portfolios and design showcases.',
      ],
    ),
  ];

  // ─── Expertise Checklist ───────────────────────────────────────────────
  final List<TextEditingController> _expertiseCtrls = [
    TextEditingController(text: 'Brand Identity & Guidelines'),
    TextEditingController(text: 'Vector & Raster Illustration'),
    TextEditingController(text: 'Social Media Campaign Assets'),
    TextEditingController(text: 'UI Wireframing & Prototyping'),
    TextEditingController(text: 'Print Packaging & Merch Design'),
    TextEditingController(text: 'Typography & Layout Systems'),
  ];

  // ─── Achievements ──────────────────────────────────────────────────────
  final List<Map<String, TextEditingController>> _achievements = [
    {
      'title': TextEditingController(text: 'Best Designer Award'),
      'sub': TextEditingController(text: 'State Design Summit – 2023'),
    },
    {
      'title': TextEditingController(text: 'Certified UI/UX Professional'),
      'sub': TextEditingController(text: 'Design Accreditation Guild – 2022'),
    },
    {
      'title': TextEditingController(text: 'Creative Hackathon 1st Prize'),
      'sub': TextEditingController(text: 'Smart City Visual Challenge – 2021'),
    },
  ];

  // ─── Footer ────────────────────────────────────────────────────────────
  final _fatherCtrl = TextEditingController(text: 'Rajesh Kumar');
  final _dobCtrl = TextEditingController(text: '12 March 2001');
  final _genderCtrl = TextEditingController(text: 'Male');
  final _maritalCtrl = TextEditingController(text: 'Single');

  // ─── Studio Controls ───────────────────────────────────────────────────
  bool _showTools = true;
  int _mobileTab = 0; // 0: Canvas, 1: Tools

  @override
  void dispose() {
    for (final ctrl in [
      _nameCtrl,
      _titleCtrl,
      _taglineCtrl,
      _summaryCtrl,
      _phoneCtrl,
      _emailCtrl,
      _locationCtrl,
      _linkedinCtrl,
      _websiteCtrl,
      _fatherCtrl,
      _dobCtrl,
      _genderCtrl,
      _maritalCtrl,
      ..._expertiseCtrls,
    ]) {
      ctrl.dispose();
    }
    for (final edu in _eduEntries) {
      edu.dispose();
    }
    for (final s in _skills) {
      s.dispose();
    }
    for (final l in _langs) {
      l.dispose();
    }
    for (final exp in _expEntries) {
      exp.dispose();
    }
    for (final a in _achievements) {
      for (final c in a.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // ─── Safe Cross-Platform Photo Picker (bytes-based) ────────────────────
  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) return;
    setState(() => _isPickingPhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted) {
          setState(() => _photoBytes = bytes);
        }
      }
    } catch (e) {
      debugPrint('Photo upload error: $e');
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _removePhoto() {
    setState(() => _photoBytes = null);
  }

  // ─── Export High-Quality PDF (1:1 Pixel-Perfect Match with Screen) ─────
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final pdfNavy = PdfColor.fromInt(_sidebar.toARGB32());
    final pdfGold = PdfColor.fromInt(_gold.toARGB32());
    final pdfIndicator = PdfColor.fromInt(_indicator.toARGB32());
    final pdfTrack = PdfColor.fromInt(_pal.trackColor.toARGB32());

    // Load true Unicode fonts with fail-safe fallbacks
    pw.Font regularFont = pw.Font.helvetica();
    pw.Font boldFont = pw.Font.helveticaBold();
    pw.Font italicFont = pw.Font.helveticaOblique();
    pw.Font serifFont = pw.Font.timesBold();
    pw.Font cursiveFont = pw.Font.timesItalic();

    try {
      regularFont = await PdfGoogleFonts.plusJakartaSansRegular();
      boldFont = await PdfGoogleFonts.plusJakartaSansBold();
      italicFont = await PdfGoogleFonts.plusJakartaSansItalic();
      serifFont = await PdfGoogleFonts.playfairDisplayBold();
      cursiveFont = await PdfGoogleFonts.alexBrushRegular();
    } catch (e) {
      debugPrint('PdfGoogleFonts fallback: $e');
    }

    final rawSig = _nameCtrl.text.trim();
    final sig = rawSig.isEmpty
        ? 'Prateek'
        : rawSig.split(' ').first.toLowerCase().replaceFirst(
            RegExp(r'.'), rawSig[0].toUpperCase());

    String clean(String s) => s
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('•', '')
        .trim();

    // ── Helper: Sidebar Heading with Badge ──
    pw.Widget pdfSidebarHeading(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 13,
              height: 13,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: pdfIndicator,
              ),
              child: pw.Center(
                child: pw.Container(
                  width: 4.5,
                  height: 4.5,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: pdfNavy,
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 5),
            pw.Text(
              title,
              style: pw.TextStyle(
                font: boldFont,
                color: pdfIndicator,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    // ── Helper: Right Content Heading with Circular Badge ──
    pw.Widget pdfRightHeading(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 16,
              height: 16,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: pdfNavy,
              ),
              child: pw.Center(
                child: pw.Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: pdfGold,
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              title,
              style: pw.TextStyle(
                font: boldFont,
                color: pdfNavy,
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      );
    }

    // ── Helper: Contact Item with Label Pill ──
    pw.Widget pdfContactItem(String label, String value) {
      final text = clean(value);
      if (text.isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2.5)),
                color: pdfIndicator,
              ),
              child: pw.Center(
                child: pw.Text(
                  label,
                  style: const pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  font: regularFont,
                  color: PdfColors.white,
                  fontSize: 7.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Helper: Footer Icons (Crisp Vectors) ──
    pw.Widget pdfIconPerson() {
      return pw.CustomPaint(
        size: const PdfPoint(12, 12),
        painter: (canvas, size) {
          canvas.setStrokeColor(const PdfColor.fromInt(0xFF64748B));
          canvas.setLineWidth(0.85);
          // Head
          canvas.drawEllipse(size.x / 2, size.y * 0.72, 2.3, 2.3);
          canvas.strokePath();
          // Shoulders
          canvas.moveTo(size.x * 0.15, size.y * 0.15);
          canvas.curveTo(size.x * 0.22, size.y * 0.45, size.x * 0.78,
              size.y * 0.45, size.x * 0.85, size.y * 0.15);
          canvas.strokePath();
        },
      );
    }

    pw.Widget pdfIconCalendar() {
      return pw.CustomPaint(
        size: const PdfPoint(12, 12),
        painter: (canvas, size) {
          canvas.setStrokeColor(const PdfColor.fromInt(0xFF64748B));
          canvas.setLineWidth(0.85);
          // Box
          canvas.drawRect(
              size.x * 0.12, size.y * 0.12, size.x * 0.76, size.y * 0.68);
          canvas.strokePath();
          // Header divider
          canvas.moveTo(size.x * 0.12, size.y * 0.56);
          canvas.lineTo(size.x * 0.88, size.y * 0.56);
          canvas.strokePath();
          // Two top rings
          canvas.moveTo(size.x * 0.32, size.y * 0.8);
          canvas.lineTo(size.x * 0.32, size.y * 0.98);
          canvas.moveTo(size.x * 0.68, size.y * 0.8);
          canvas.lineTo(size.x * 0.68, size.y * 0.98);
          canvas.strokePath();
        },
      );
    }

    pw.Widget pdfIconGender() {
      return pw.CustomPaint(
        size: const PdfPoint(12, 12),
        painter: (canvas, size) {
          canvas.setStrokeColor(const PdfColor.fromInt(0xFF64748B));
          canvas.setLineWidth(0.85);
          // Central ring
          canvas.drawEllipse(size.x / 2, size.y * 0.42, 2.7, 2.7);
          canvas.strokePath();
          // Top right arrow (Male)
          canvas.moveTo(size.x * 0.7, size.y * 0.62);
          canvas.lineTo(size.x * 0.92, size.y * 0.88);
          canvas.moveTo(size.x * 0.92, size.y * 0.68);
          canvas.lineTo(size.x * 0.92, size.y * 0.88);
          canvas.lineTo(size.x * 0.72, size.y * 0.88);
          canvas.strokePath();
        },
      );
    }

    pw.Widget pdfIconHeart() {
      return pw.CustomPaint(
        size: const PdfPoint(12, 12),
        painter: (canvas, size) {
          canvas.setStrokeColor(const PdfColor.fromInt(0xFF64748B));
          canvas.setLineWidth(0.85);
          // Heart outline
          canvas.moveTo(size.x * 0.5, size.y * 0.18);
          canvas.curveTo(size.x * 0.12, size.y * 0.48, size.x * 0.12,
              size.y * 0.82, size.x * 0.5, size.y * 0.62);
          canvas.curveTo(size.x * 0.88, size.y * 0.82, size.x * 0.88,
              size.y * 0.48, size.x * 0.5, size.y * 0.18);
          canvas.strokePath();
        },
      );
    }

    pw.Widget pdfFooterItem(
        pw.Widget iconWidget, String label, String value) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            iconWidget,
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 5.2,
                color: const PdfColor.fromInt(0xFF94A3B8),
                letterSpacing: 0.4,
              ),
            ),
            pw.SizedBox(height: 1.5),
            pw.Text(
              clean(value),
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 7.2,
                fontWeight: pw.FontWeight.bold,
                color: pdfNavy,
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
              // 1. Full White Background
              pw.Container(color: PdfColors.white),

              // 2. Left Sidebar Solid Block (185pt)
              pw.Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: pw.Container(width: 185, color: pdfNavy),
              ),

              // 3. Golden Wave Decorative Ribbon Edge (Matches Screen _WaveEdgePainter)
              pw.Positioned(
                left: 175,
                top: 0,
                bottom: 0,
                child: pw.Container(
                  width: 22,
                  child: pw.CustomPaint(
                    size: const PdfPoint(22, 842),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      canvas.setFillColor(pdfNavy);
                      canvas.moveTo(0, 0);
                      canvas.curveTo(size.x * 1.2, size.y * 0.15, -size.x * 0.2,
                          size.y * 0.35, size.x * 1.0, size.y * 0.5);
                      canvas.curveTo(size.x * 1.2, size.y * 0.65, -size.x * 0.2,
                          size.y * 0.85, size.x * 1.0, size.y);
                      canvas.lineTo(0, size.y);
                      canvas.closePath();
                      canvas.fillPath();

                      canvas.setStrokeColor(pdfGold);
                      canvas.setLineWidth(2.2);
                      canvas.moveTo(0, 0);
                      canvas.curveTo(size.x * 1.2, size.y * 0.15, -size.x * 0.2,
                          size.y * 0.35, size.x * 1.0, size.y * 0.5);
                      canvas.curveTo(size.x * 1.2, size.y * 0.65, -size.x * 0.2,
                          size.y * 0.85, size.x * 1.0, size.y);
                      canvas.strokePath();
                    },
                  ),
                ),
              ),

              // 4. Foreground Content Row: Sidebar Content + Right Body Content
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // ═════════════════════════════════════════════════════════
                  // LEFT SIDEBAR CONTENT
                  // ═════════════════════════════════════════════════════════
                  pw.Container(
                    width: 185,
                    padding: const pw.EdgeInsets.fromLTRB(14, 20, 14, 16),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Concentric Gold Ring Photo Frame
                        pw.Center(
                          child: pw.Container(
                            width: 76,
                            height: 76,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              border: pw.Border.all(color: pdfGold, width: 2.2),
                              color: pdfNavy,
                            ),
                            padding: const pw.EdgeInsets.all(2.5),
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                border: pw.Border.all(
                                    color: pdfGold.luminance > 0.6
                                        ? pdfGold
                                        : pdfIndicator,
                                    width: 1),
                              ),
                              child: pw.ClipOval(
                                child: _photoBytes != null
                                    ? pw.Image(pw.MemoryImage(_photoBytes!),
                                        fit: pw.BoxFit.cover)
                                    : pw.Container(
                                        color: pdfNavy,
                                        child: pw.Center(
                                          child: pw.Text(
                                            sig.isNotEmpty ? sig[0] : 'P',
                                            style: pw.TextStyle(
                                              font: boldFont,
                                              color: pdfIndicator,
                                              fontSize: 26,
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        pw.SizedBox(height: 14),

                        // ── CONTACT ──
                        pdfSidebarHeading('CONTACT'),
                        pdfContactItem('P', _phoneCtrl.text),
                        pdfContactItem('@', _emailCtrl.text),
                        pdfContactItem('L', _locationCtrl.text),
                        pdfContactItem('in', _linkedinCtrl.text),
                        pdfContactItem('Bē', _websiteCtrl.text),

                        pw.SizedBox(height: 12),

                        // ── EDUCATION ──
                        pdfSidebarHeading('EDUCATION'),
                        ..._eduEntries.map((edu) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 5.5),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    clean(edu.degreeCtrl.text),
                                    style: pw.TextStyle(
                                      font: boldFont,
                                      color: PdfColors.white,
                                      fontSize: 7.2,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                    clean(edu.instCtrl.text),
                                    style: pw.TextStyle(
                                      font: regularFont,
                                      color: PdfColors.grey300,
                                      fontSize: 6.5,
                                    ),
                                  ),
                                  pw.Text(
                                    clean(edu.yearCtrl.text),
                                    style: pw.TextStyle(
                                      font: boldFont,
                                      color: pdfIndicator,
                                      fontSize: 6.5,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )),

                        pw.SizedBox(height: 12),

                        // ── SKILLS (WITH PERCENTAGE & ADAPTIVE BARS) ──
                        pdfSidebarHeading('SKILLS'),
                        ..._skills.map((s) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 4.5),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        clean(s.nameCtrl.text),
                                        style: pw.TextStyle(
                                          font: regularFont,
                                          color: PdfColors.white,
                                          fontSize: 7,
                                        ),
                                      ),
                                      pw.Text(
                                        '${(s.level * 100).round()}%',
                                        style: pw.TextStyle(
                                          font: boldFont,
                                          color: pdfIndicator,
                                          fontSize: 7,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Container(
                                    height: 3,
                                    width: 157,
                                    decoration: pw.BoxDecoration(
                                      borderRadius: const pw.BorderRadius.all(
                                          pw.Radius.circular(1.5)),
                                      color: pdfTrack,
                                    ),
                                    child: pw.Align(
                                      alignment: pw.Alignment.centerLeft,
                                      child: pw.Container(
                                        height: 3,
                                        width: 157 * s.level,
                                        decoration: pw.BoxDecoration(
                                          borderRadius:
                                              const pw.BorderRadius.all(
                                                  pw.Radius.circular(1.5)),
                                          color: pdfIndicator,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),

                        pw.SizedBox(height: 12),

                        // ── LANGUAGES (7-DOT INDICATORS) ──
                        pdfSidebarHeading('LANGUAGES'),
                        ..._langs.map((l) => pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    clean(l.nameCtrl.text),
                                    style: pw.TextStyle(
                                      font: regularFont,
                                      color: PdfColors.white,
                                      fontSize: 7,
                                    ),
                                  ),
                                  pw.Row(
                                    children: List.generate(7, (d) {
                                      final filled = d < l.dots;
                                      return pw.Container(
                                        width: 6,
                                        height: 6,
                                        margin:
                                            const pw.EdgeInsets.only(left: 2),
                                        decoration: pw.BoxDecoration(
                                          shape: pw.BoxShape.circle,
                                          color: filled
                                              ? pdfIndicator
                                              : const PdfColor.fromInt(0x35FFFFFF),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            )),

                        pw.Spacer(),

                        // ── SIGNATURE AT BOTTOM ──
                        pw.Center(
                          child: pw.Column(
                            children: [
                              pw.Container(
                                width: 120,
                                height: 0.8,
                                color: pdfIndicator,
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                sig,
                                style: pw.TextStyle(
                                  font: cursiveFont,
                                  color: pdfIndicator,
                                  fontSize: 24,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'DESIGN  |  CREATE  |  INSPIRE',
                                style: pw.TextStyle(
                                  font: boldFont,
                                  color: pdfIndicator,
                                  fontSize: 4.8,
                                  letterSpacing: 1.2,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Spacing clearance for wave ribbon
                  pw.SizedBox(width: 14),

                  // ═════════════════════════════════════════════════════════
                  // RIGHT MAIN BODY CONTENT
                  // ═════════════════════════════════════════════════════════
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.fromLTRB(14, 22, 22, 16),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // ── NAME & DESIGNATION ──
                          pw.Text(
                            _nameCtrl.text.toUpperCase().isEmpty
                                ? 'PRATEEK'
                                : _nameCtrl.text.toUpperCase(),
                            style: pw.TextStyle(
                              font: serifFont,
                              fontSize: 30,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfNavy,
                              letterSpacing: 2,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            _titleCtrl.text.toUpperCase(),
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfGold,
                              letterSpacing: 2.5,
                            ),
                          ),
                          pw.SizedBox(height: 3.5),

                          // Gold Diamond Ornament Line
                          pw.Row(
                            children: [
                              pw.Container(
                                  width: 32, height: 1.5, color: pdfGold),
                              pw.SizedBox(width: 4),
                              pw.Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: pw.BoxDecoration(
                                  shape: pw.BoxShape.circle,
                                  color: pdfGold,
                                ),
                              ),
                              pw.SizedBox(width: 4),
                              pw.Container(
                                  width: 32, height: 1.5, color: pdfGold),
                            ],
                          ),

                          pw.SizedBox(height: 5),

                          // Tagline with vector separators (zero box character issues!)
                          pw.Row(
                            children: [
                              pw.Text('Creative',
                                  style: pw.TextStyle(
                                      font: regularFont,
                                      fontSize: 7.8,
                                      color: PdfColors.grey600)),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 5),
                                child: pw.Container(
                                  width: 2.5,
                                  height: 2.5,
                                  decoration: const pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    color: PdfColors.grey500,
                                  ),
                                ),
                              ),
                              pw.Text('Detail-Oriented',
                                  style: pw.TextStyle(
                                      font: regularFont,
                                      fontSize: 7.8,
                                      color: PdfColors.grey600)),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 5),
                                child: pw.Container(
                                  width: 2.5,
                                  height: 2.5,
                                  decoration: const pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    color: PdfColors.grey500,
                                  ),
                                ),
                              ),
                              pw.Text('Dedicated',
                                  style: pw.TextStyle(
                                      font: regularFont,
                                      fontSize: 7.8,
                                      color: PdfColors.grey600)),
                            ],
                          ),

                          pw.SizedBox(height: 13),

                          // ── PROFESSIONAL SUMMARY ──
                          pdfRightHeading('PROFESSIONAL SUMMARY'),
                          pw.Text(
                            clean(_summaryCtrl.text),
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 7.8,
                              color: PdfColors.grey800,
                              lineSpacing: 1.6,
                            ),
                          ),

                          pw.SizedBox(height: 12),

                          // ── EXPERIENCE ──
                          pdfRightHeading('EXPERIENCE'),
                          ..._expEntries.map((exp) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 7),
                                child: pw.Row(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    // Gold timeline bullet dot
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(
                                          top: 3, right: 6),
                                      child: pw.Container(
                                        width: 5,
                                        height: 5,
                                        decoration: pw.BoxDecoration(
                                          shape: pw.BoxShape.circle,
                                          color: pdfGold,
                                        ),
                                      ),
                                    ),
                                    pw.Expanded(
                                      child: pw.Column(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Row(
                                            mainAxisAlignment:
                                                pw.MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              pw.Text(
                                                clean(exp.roleCtrl.text),
                                                style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 8.8,
                                                  fontWeight:
                                                      pw.FontWeight.bold,
                                                  color: pdfNavy,
                                                ),
                                              ),
                                              pw.Text(
                                                clean(exp.datesCtrl.text),
                                                style: pw.TextStyle(
                                                  font: regularFont,
                                                  fontSize: 7.2,
                                                  color: PdfColors.grey600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          pw.Text(
                                            clean(exp.subtitleCtrl.text),
                                            style: pw.TextStyle(
                                              font: italicFont,
                                              fontSize: 7.4,
                                              color: pdfGold,
                                              fontStyle: pw.FontStyle.italic,
                                            ),
                                          ),
                                          pw.SizedBox(height: 2),
                                          // Vector Circle Bullets (zero glyph errors!)
                                          ...exp.bulletCtrls.map((b) {
                                            final bText = clean(b.text);
                                            if (bText.isEmpty) {
                                              return pw.SizedBox();
                                            }
                                            return pw.Padding(
                                              padding: const pw.EdgeInsets.only(
                                                  bottom: 2),
                                              child: pw.Row(
                                                crossAxisAlignment:
                                                    pw.CrossAxisAlignment.start,
                                                children: [
                                                  pw.Padding(
                                                    padding:
                                                        const pw.EdgeInsets.only(
                                                            top: 3.2, right: 5),
                                                    child: pw.Container(
                                                      width: 2.5,
                                                      height: 2.5,
                                                      decoration:
                                                          const pw.BoxDecoration(
                                                        shape: pw.BoxShape
                                                            .circle,
                                                        color:
                                                            PdfColors.grey700,
                                                      ),
                                                    ),
                                                  ),
                                                  pw.Expanded(
                                                    child: pw.Text(
                                                      bText,
                                                      style: pw.TextStyle(
                                                        font: regularFont,
                                                        fontSize: 7.3,
                                                        color:
                                                            PdfColors.grey800,
                                                        lineSpacing: 1.3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),

                          pw.SizedBox(height: 10),

                          // ── EXPERTISE & ACHIEVEMENTS SPLIT GRID ──
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Expertise Column
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pdfRightHeading('EXPERTISE'),
                                    ..._expertiseCtrls.map((c) => pw.Padding(
                                          padding: const pw.EdgeInsets.only(
                                              bottom: 2.8),
                                          child: pw.Row(
                                            children: [
                                              pw.Container(
                                                width: 8,
                                                height: 8,
                                                decoration: pw.BoxDecoration(
                                                  shape: pw.BoxShape.circle,
                                                  color: pdfGold,
                                                ),
                                                child: pw.Center(
                                                  child: pw.Container(
                                                    width: 3,
                                                    height: 3,
                                                    decoration:
                                                        const pw.BoxDecoration(
                                                      shape:
                                                          pw.BoxShape.circle,
                                                      color: PdfColors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              pw.SizedBox(width: 5),
                                              pw.Expanded(
                                                child: pw.Text(
                                                  clean(c.text),
                                                  style: pw.TextStyle(
                                                    font: regularFont,
                                                    fontSize: 7.2,
                                                    color: PdfColors.grey800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              ),

                              pw.SizedBox(width: 14),

                              // Achievements Column
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pdfRightHeading('ACHIEVEMENTS'),
                                    ..._achievements.map((a) => pw.Padding(
                                          padding: const pw.EdgeInsets.only(
                                              bottom: 4),
                                          child: pw.Row(
                                            crossAxisAlignment:
                                                pw.CrossAxisAlignment.start,
                                            children: [
                                              pw.Container(
                                                width: 8,
                                                height: 8,
                                                margin:
                                                    const pw.EdgeInsets.only(
                                                        top: 1.5),
                                                decoration: pw.BoxDecoration(
                                                  shape: pw.BoxShape.circle,
                                                  color: pdfGold,
                                                ),
                                                child: pw.Center(
                                                  child: pw.Container(
                                                    width: 3,
                                                    height: 3,
                                                    decoration:
                                                        const pw.BoxDecoration(
                                                      shape:
                                                          pw.BoxShape.circle,
                                                      color: PdfColors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              pw.SizedBox(width: 5),
                                              pw.Expanded(
                                                child: pw.Column(
                                                  crossAxisAlignment:
                                                      pw.CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    pw.Text(
                                                      clean(
                                                          a['title']?.text ??
                                                              ''),
                                                      style: pw.TextStyle(
                                                        font: boldFont,
                                                        fontSize: 7.5,
                                                        fontWeight:
                                                            pw.FontWeight.bold,
                                                        color: pdfNavy,
                                                      ),
                                                    ),
                                                    pw.Text(
                                                      clean(
                                                          a['sub']?.text ?? ''),
                                                      style: pw.TextStyle(
                                                        font: regularFont,
                                                        fontSize: 6.8,
                                                        color:
                                                            PdfColors.grey600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          pw.Spacer(),

                          // ── FOOTER PROFILE STRIP (WITH ICONS) ──
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6.5),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFF8F9FB),
                              borderRadius:
                                  const pw.BorderRadius.all(pw.Radius.circular(6)),
                              border: pw.Border.all(
                                color: const PdfColor.fromInt(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pdfFooterItem(pdfIconPerson(), "FATHER'S NAME",
                                    _fatherCtrl.text),
                                pdfFooterItem(pdfIconCalendar(), 'DATE OF BIRTH',
                                    _dobCtrl.text),
                                pdfFooterItem(pdfIconGender(), 'GENDER',
                                    _genderCtrl.text),
                                pdfFooterItem(pdfIconHeart(), 'MARITAL STATUS',
                                    _maritalCtrl.text),
                              ],
                            ),
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

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${clean(_nameCtrl.text).replaceAll(' ', '_')}_Resume.pdf',
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sig = _nameCtrl.text.isEmpty
        ? 'Prateek'
        : _nameCtrl.text
            .trim()
            .split(' ')
            .first
            .toLowerCase()
            .replaceFirst(RegExp(r'.'), _nameCtrl.text.trim()[0].toUpperCase());

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C30),
        elevation: 0,
        title: Row(
          children: [
            const Text('Mahii Luxury Template',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _pal.indicatorColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _pal.indicatorColor, width: 0.8),
              ),
              child: Text(
                '🎨 ${_pal.name}',
                style: TextStyle(
                    color: _pal.indicatorColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Export PDF / Print',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: Icon(
                _showTools
                    ? Icons.tune_rounded
                    : Icons.tune_outlined,
                color: _showTools ? _pal.indicatorColor : Colors.white70),
            tooltip: _showTools ? 'Hide Toolbar' : 'Show Toolbar',
            onPressed: () => setState(() => _showTools = !_showTools),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;

          if (isNarrow) {
            // Mobile layout with tabs
            return Column(
              children: [
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
                                Icon(Icons.edit_note_rounded,
                                    size: 16,
                                    color: _mobileTab == 0
                                        ? Colors.black
                                        : Colors.white70),
                                const SizedBox(width: 6),
                                Text('Canvas Edit',
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
                                Icon(Icons.palette_rounded,
                                    size: 16,
                                    color: _mobileTab == 1
                                        ? Colors.black
                                        : Colors.white70),
                                const SizedBox(width: 6),
                                Text('Themes & Tools',
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
                              child: _buildA4Sheet(sig),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF181B24),
                          child: _buildToolSidebar(),
                        ),
                ),
              ],
            );
          }

          // Desktop/Tablet view: Left tool panel + Right interactive A4 canvas
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showTools)
                Container(
                  width: 320,
                  color: const Color(0xFF181B24),
                  child: _buildToolSidebar(),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: _buildA4Sheet(sig),
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
  // A4 SHEET CONTAINER (794px width)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildA4Sheet(String sig) {
    return Theme(
      data: ThemeData.light().copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          filled: false,
          fillColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
      child: Container(
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── LEFT SIDEBAR ──────────────────────────────────────────
              _buildSidebar(sig),

              // ── RIGHT CANVAS (DIRECT INLINE EDITABLE) ─────────────────
              Expanded(child: _buildRightContent()),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STUDIO TOOLBAR PANEL (LEFT)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildToolSidebar() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Helper Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF222634),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            children: [
              Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direct In-Place Edit: Click on any text directly on the resume to type, copy, or paste!',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 🎨 5 FIXED COLOR PALETTES
        _toolHeader('🎨 5 Color Themes (Adaptive Contrast)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(kMahiiPalettes.length, (i) {
            final pal = kMahiiPalettes[i];
            final isSelected = _paletteIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _paletteIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 42,
                decoration: BoxDecoration(
                  color: pal.sidebarColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? pal.indicatorColor : Colors.white12,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: pal.indicatorColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    // Indicator color pip inside swatch
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: pal.indicatorColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Center(
                        child: Icon(Icons.check_rounded,
                            color: pal.indicatorColor, size: 18),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Text(
                'Selected: ${_pal.name}',
                style: TextStyle(
                    color: _pal.indicatorColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _pal.indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text('Contrast Pip',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 📷 PHOTO UPLOAD / REMOVE
        _toolHeader('📷 Profile Photo (Circle Frame)'),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPickingPhoto ? null : _pickPhoto,
                icon: _isPickingPhoto
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_a_photo_outlined, size: 15),
                label: const Text('Choose Photo',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E3346),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (_photoBytes != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: _removePhoto,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 20),
                tooltip: 'Remove photo (reset to placeholder)',
              ),
            ],
          ],
        ),

        const SizedBox(height: 18),

        // ⚡ SKILLS SLIDERS
        _toolHeader('⚡ Skills Level (Adjust % Length)'),
        ..._skills.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.nameCtrl.text,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ),
                  Text(
                    '${(s.level * 100).round()}%',
                    style: TextStyle(
                        color: _indicator,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _indicator,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: _indicator,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: s.level,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (v) => setState(() => _skills[i].level = v),
                ),
              ),
            ],
          );
        }),

        const SizedBox(height: 12),

        // 🌐 LANGUAGES DOT INDICATOR
        _toolHeader('🌐 Languages (Tap Dots 1–7)'),
        ..._langs.asMap().entries.map((e) {
          final i = e.key;
          final lang = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(lang.nameCtrl.text,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ),
                Row(
                  children: List.generate(7, (d) {
                    final filled = d < lang.dots;
                    return GestureDetector(
                      onTap: () => setState(() => _langs[i].dots = d + 1),
                      child: Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          color: filled ? _indicator : Colors.white12,
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

        const SizedBox(height: 18),

        // 📥 EXPORT PDF BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Export / Print PDF',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _indicator,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _toolHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          title,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3),
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════
  // LEFT SIDEBAR (NAVY / RED / SKY BLUE / GREY / GOLDEN)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildSidebar(String sig) {
    return Stack(
      children: [
        Container(
          width: 265,
          color: _sidebar,
          padding: const EdgeInsets.fromLTRB(22, 32, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── PHOTO WITH GOLD RING ───────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 124,
                    height: 124,
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
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _sidebar, width: 3),
                      ),
                      child: ClipOval(
                        child: _photoBytes != null
                            ? Image.memory(
                                _photoBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Container(
                                color: _sidebar.withValues(alpha: 0.7),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          color: _indicator.withValues(alpha: 0.8),
                                          size: 28),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Add Photo',
                                        style: TextStyle(
                                            color: _indicator
                                                .withValues(alpha: 0.9),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ── CONTACT (INLINE EDITABLE) ──────────────────────────────
              _sidebarHeading('CONTACT'),
              const SizedBox(height: 8),
              _sidebarContactRow(Icons.phone_outlined, _phoneCtrl),
              _sidebarContactRow(Icons.email_outlined, _emailCtrl),
              _sidebarContactRow(Icons.location_on_outlined, _locationCtrl),
              _sidebarContactRow(Icons.link_outlined, _linkedinCtrl),
              _sidebarContactRow(Icons.language_outlined, _websiteCtrl),

              const SizedBox(height: 18),

              // ── EDUCATION (INLINE EDITABLE WITH + BUTTON) ───────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sidebarHeading('EDUCATION'),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: _indicator, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Add Education Degree',
                    onPressed: () {
                      setState(() {
                        _eduEntries.add(_EduItem(
                          degree: 'New Degree / Certification',
                          inst: 'Institute Name',
                          year: '2023 – 2024',
                        ));
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._eduEntries.asMap().entries.map((e) {
                final i = e.key;
                final edu = e.value;
                return _eduItemRow(edu, i);
              }),

              const SizedBox(height: 18),

              // ── SKILLS (INLINE EDITABLE + SLIDERS) ───────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sidebarHeading('SKILLS'),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: _indicator, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Add Skill',
                    onPressed: () {
                      setState(() {
                        _skills.add(_SkillItem('New Skill', 0.75));
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._skills.asMap().entries.map((e) {
                final i = e.key;
                final s = e.value;
                return _skillRow(s, i);
              }),

              const SizedBox(height: 18),

              // ── LANGUAGES (INLINE EDITABLE + TAPPABLE DOTS) ─────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sidebarHeading('LANGUAGES'),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: _indicator, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Add Language',
                    onPressed: () {
                      setState(() {
                        _langs.add(_LangItem('New Language', 5));
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._langs.asMap().entries.map((e) {
                final i = e.key;
                final l = e.value;
                return _langRow(l, i);
              }),

              // ── SIGNATURE AT BOTTOM (AUTO SYNCS WITH USER NAME) ─────────
              const SizedBox(height: 22),
              Divider(color: _indicator.withValues(alpha: 0.3), height: 1),
              const SizedBox(height: 14),
              Center(
                child: Column(
                  children: [
                    Text(
                      sig,
                      style: GoogleFonts.alexBrush(
                        fontSize: 38,
                        color: _indicator,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DESIGN • CREATE • INSPIRE',
                      style: TextStyle(
                        fontSize: 7,
                        letterSpacing: 1.5,
                        color: _indicator.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Gold wave decorative ribbon on right edge
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
      ],
    );
  }

  Widget _sidebarHeading(String title) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _indicator,
              shape: BoxShape.circle,
            ),
            child: Icon(_headingIcon(title), color: _sidebar, size: 11),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _indicator,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );

  IconData _headingIcon(String t) {
    switch (t) {
      case 'CONTACT':
        return Icons.person_outline;
      case 'EDUCATION':
        return Icons.school_outlined;
      case 'SKILLS':
        return Icons.settings_outlined;
      case 'LANGUAGES':
        return Icons.language_outlined;
      default:
        return Icons.circle;
    }
  }

  Widget _sidebarContactRow(IconData icon, TextEditingController ctrl) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, color: _indicator, size: 12),
            const SizedBox(width: 7),
            Expanded(
              child: _InlineField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 9.5),
              ),
            ),
          ],
        ),
      );

  Widget _eduItemRow(_EduItem edu, int index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _InlineField(
                    controller: edu.degreeCtrl,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (_eduEntries.length > 1)
                  GestureDetector(
                    onTap: () => setState(() => _eduEntries.removeAt(index)),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white38, size: 12),
                  ),
              ],
            ),
            _InlineField(
              controller: edu.instCtrl,
              style: const TextStyle(color: Colors.white60, fontSize: 8.5),
            ),
            _InlineField(
              controller: edu.yearCtrl,
              style: TextStyle(
                  color: _indicator,
                  fontSize: 8,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );

  Widget _skillRow(_SkillItem s, int index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _InlineField(
                    controller: s.nameCtrl,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${(s.level * 100).round()}%',
                  style: TextStyle(
                      color: _indicator,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold),
                ),
                if (_skills.length > 1) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _skills.removeAt(index)),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white38, size: 11),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: s.level,
                minHeight: 4,
                backgroundColor: _pal.trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(_indicator),
              ),
            ),
          ],
        ),
      );

  Widget _langRow(_LangItem l, int index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: _InlineField(
                controller: l.nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
            Row(
              children: List.generate(7, (d) {
                final filled = d < l.dots;
                return GestureDetector(
                  onTap: () => setState(() => l.dots = d + 1),
                  child: Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: filled ? _indicator : _pal.dotInactiveColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
            if (_langs.length > 1) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _langs.removeAt(index)),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white38, size: 11),
              ),
            ],
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════
  // RIGHT CONTENT (DIRECT INLINE EDITABLE ON CANVAS)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildRightContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(36, 36, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── NAME & DESIGNATION (DIRECT INLINE EDIT) ───────────────────
          _InlineField(
            controller: _nameCtrl,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: _sidebar,
              letterSpacing: 2,
              height: 1,
              fontFamily: 'serif',
            ),
            onChanged: (_) => setState(() {}), // Auto updates signature!
          ),
          const SizedBox(height: 6),
          _InlineField(
            controller: _titleCtrl,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _gold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(width: 40, height: 1.5, color: _gold),
              const SizedBox(width: 6),
              Icon(Icons.diamond_outlined, color: _gold, size: 10),
              const SizedBox(width: 6),
              Container(width: 40, height: 1.5, color: _gold),
            ],
          ),
          const SizedBox(height: 6),
          _InlineField(
            controller: _taglineCtrl,
            style: TextStyle(
                fontSize: 11, color: Colors.grey[600], letterSpacing: 1),
          ),

          const SizedBox(height: 18),

          // ── PROFESSIONAL SUMMARY (DIRECT INLINE EDIT) ─────────────────
          _rightHeading('PROFESSIONAL SUMMARY'),
          const SizedBox(height: 6),
          _InlineField(
            controller: _summaryCtrl,
            maxLines: 4,
            style: TextStyle(
                fontSize: 10.5, height: 1.5, color: Colors.grey[800]),
          ),

          const SizedBox(height: 18),

          // ── EXPERIENCE (DIRECT INLINE EDIT WITH + AND DELETE) ─────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _rightHeading('EXPERIENCE'),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _expEntries.add(_ExpItem(
                      role: 'New Role / Position',
                      subtitle: 'Company / Organization',
                      dates: '2023 – Present',
                      bullets: [
                        'Key achievement or responsibility description.',
                      ],
                    ));
                  });
                },
                icon: Icon(Icons.add_rounded, size: 14, color: _sidebar),
                label: Text('Add Experience',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _sidebar)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._expEntries.asMap().entries.map((e) {
            final i = e.key;
            final exp = e.value;
            return _expEntryWidget(exp, i);
          }),

          const SizedBox(height: 14),

          // ── EXPERTISE & ACHIEVEMENTS SPLIT ────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _rightHeading('EXPERTISE'),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: _sidebar),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _expertiseCtrls.add(
                                  TextEditingController(text: 'New Expertise'));
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._expertiseCtrls.asMap().entries.map((e) {
                      final i = e.key;
                      final c = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 12, color: _gold),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _InlineField(
                                controller: c,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[800]),
                              ),
                            ),
                            if (_expertiseCtrls.length > 1)
                              GestureDetector(
                                onTap: () => setState(
                                    () => _expertiseCtrls.removeAt(i)),
                                child: const Icon(Icons.close_rounded,
                                    size: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _rightHeading('ACHIEVEMENTS'),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: _sidebar),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _achievements.add({
                                'title': TextEditingController(
                                    text: 'Award / Recognition'),
                                'sub': TextEditingController(
                                    text: 'Organization – Year'),
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._achievements.asMap().entries.map((e) {
                      final i = e.key;
                      final a = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.star_rounded, color: _gold, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InlineField(
                                    controller: a['title']!,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: _sidebar),
                                  ),
                                  _InlineField(
                                    controller: a['sub']!,
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            if (_achievements.length > 1)
                              GestureDetector(
                                onTap: () => setState(
                                    () => _achievements.removeAt(i)),
                                child: const Icon(Icons.close_rounded,
                                    size: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── FOOTER PROFILE STRIP (DIRECT INLINE EDITABLE) ─────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _footerItem(Icons.person_outline, "FATHER'S NAME", _fatherCtrl),
                _footerItem(Icons.calendar_month_outlined, 'DATE OF BIRTH',
                    _dobCtrl),
                _footerItem(
                    Icons.transgender_outlined, 'GENDER', _genderCtrl),
                _footerItem(
                    Icons.favorite_outline, 'MARITAL STATUS', _maritalCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rightHeading(String title) {
    IconData icon;
    switch (title) {
      case 'PROFESSIONAL SUMMARY':
        icon = Icons.person_outline;
        break;
      case 'EXPERIENCE':
        icon = Icons.work_outline;
        break;
      case 'EXPERTISE':
        icon = Icons.emoji_events_outlined;
        break;
      case 'ACHIEVEMENTS':
        icon = Icons.military_tech_outlined;
        break;
      default:
        icon = Icons.circle;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: _sidebar, shape: BoxShape.circle),
          child: Icon(icon, color: _gold, size: 13),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: _sidebar,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _expEntryWidget(_ExpItem exp, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
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
                      child: _InlineField(
                        controller: exp.roleCtrl,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _sidebar),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: _InlineField(
                        controller: exp.datesCtrl,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 9.5,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_expEntries.length > 1) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _expEntries.removeAt(index)),
                        child: const Icon(Icons.close_rounded,
                            size: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                _InlineField(
                  controller: exp.subtitleCtrl,
                  style: TextStyle(
                      fontSize: 10,
                      color: _gold,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                ...exp.bulletCtrls.asMap().entries.map((bEntry) {
                  final bIndex = bEntry.key;
                  final bCtrl = bEntry.value;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                      Expanded(
                        child: _InlineField(
                          controller: bCtrl,
                          maxLines: 2,
                          style: TextStyle(
                              fontSize: 10.5,
                              height: 1.4,
                              color: Colors.grey[800]),
                        ),
                      ),
                      if (exp.bulletCtrls.length > 1)
                        GestureDetector(
                          onTap: () =>
                              setState(() => exp.bulletCtrls.removeAt(bIndex)),
                          child: const Icon(Icons.close_rounded,
                              size: 10, color: Colors.grey),
                        ),
                    ],
                  );
                }),
                // Add bullet action
                GestureDetector(
                  onTap: () {
                    setState(() {
                      exp.bulletCtrls.add(
                          TextEditingController(text: 'New bullet point.'));
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('+ Add bullet',
                        style: TextStyle(
                            fontSize: 9,
                            color: _sidebar.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerItem(
      IconData icon, String label, TextEditingController ctrl) =>
      Expanded(
        child: Column(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 7,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5)),
            _InlineField(
              controller: ctrl,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: _sidebar),
            ),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════
// INLINE EDITABLE TEXT FIELD WIDGET (CANVA STYLE)
// ═══════════════════════════════════════════════════════════════════════
class _InlineField extends StatelessWidget {
  final TextEditingController controller;
  final TextStyle style;
  final int maxLines;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;

  const _InlineField({
    required this.controller,
    required this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textAlign: textAlign,
      style: style,
      onChanged: onChanged,
      cursorColor: style.color ?? Colors.blue,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
              color: (style.color ?? Colors.blue).withValues(alpha: 0.6),
              width: 1.5),
        ),
      ),
    );
  }
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
      ..cubicTo(size.width * 1.2, size.height * 0.15, -size.width * 0.2,
          size.height * 0.35, size.width * 1.0, size.height * 0.5)
      ..cubicTo(size.width * 1.2, size.height * 0.65, -size.width * 0.2,
          size.height * 0.85, size.width * 1.0, size.height)
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

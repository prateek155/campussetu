import 'package:flutter/material.dart';
import 'resume_templates.dart';

class ResumeDocumentPreview extends StatelessWidget {
  final ResumeTemplateSpec template;
  final Map<String, dynamic> document;

  const ResumeDocumentPreview(
      {super.key, required this.template, required this.document});

  Map<String, dynamic> get _personal => _asMap(document['personal']);
  List<Map<String, dynamic>> get _sections => _asList(document['sections']);

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 210 / 297,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFDCE2E7)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 14,
                  offset: Offset(0, 5))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(width: 480, height: 679, child: _page()),
            ),
          ),
        ),
      );

  Widget _page() {
    if (template.id == 'mahii_luxury') {
      return _mahiiLuxuryPreview();
    }
    if (template.layout == ResumeTemplateLayout.sidebar) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 148,
            color: template.accent,
            padding: const EdgeInsets.fromLTRB(21, 35, 15, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_value(_personal, 'name', 'Your Name'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.06,
                      fontWeight: FontWeight.w800,
                      fontFamily: template.serif ? 'serif' : null)),
              const SizedBox(height: 8),
              Text(_value(_personal, 'headline', 'Professional title'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFFE6EDF2), fontSize: 10, height: 1.35)),
              const SizedBox(height: 22),
              ...['email', 'phone', 'location', 'linkedin', 'website', 'github']
                  .map((key) => _value(_personal, key, '').trim())
                  .where((value) => value.isNotEmpty)
                  .map((value) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7.5,
                              height: 1.2)))),
            ]),
          ),
          Expanded(
              child: _sectionColumn(
                  padding: const EdgeInsets.fromLTRB(23, 28, 20, 20))),
        ],
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(),
      Expanded(
          child: _sectionColumn(
              padding: const EdgeInsets.fromLTRB(31, 13, 31, 19))),
    ]);
  }

  Widget _header() {
    final name = _value(_personal, 'name', 'Your Name');
    final title = _value(_personal, 'headline', 'Professional title');
    final contacts = [
      'email',
      'phone',
      'location',
      'linkedin',
      'website',
      'github'
    ]
        .map((key) => _value(_personal, key, '').trim())
        .where((value) => value.isNotEmpty)
        .join('   ·   ');

    if (template.layout == ResumeTemplateLayout.band) {
      return Container(
        color: template.accent,
        padding: const EdgeInsets.fromLTRB(31, 29, 31, 23),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  fontFamily: template.serif ? 'serif' : null)),
          if (title.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(title,
                    style: const TextStyle(
                        color: Color(0xFFE6EDF2), fontSize: 11))),
          if (contacts.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(contacts,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 7.5))),
        ]),
      );
    }

    final centered = template.layout == ResumeTemplateLayout.centered;
    return Padding(
      padding: const EdgeInsets.fromLTRB(31, 29, 31, 10),
      child: Column(
          crossAxisAlignment:
              centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
                height: 4, width: centered ? 40 : 418, color: template.accent),
            const SizedBox(height: 12),
            Text(name,
                textAlign: centered ? TextAlign.center : TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: template.layout == ResumeTemplateLayout.centered
                        ? const Color(0xFF30343A)
                        : template.accent,
                    fontSize: 27,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                    letterSpacing:
                        template.layout == ResumeTemplateLayout.editorial
                            ? 0.4
                            : 0,
                    fontFamily: template.serif ? 'serif' : null)),
            if (title.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(title,
                      textAlign: centered ? TextAlign.center : TextAlign.left,
                      style: const TextStyle(
                          color: Color(0xFF59636D), fontSize: 10))),
            if (contacts.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(contacts,
                      textAlign: centered ? TextAlign.center : TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF59636D), fontSize: 7.5))),
            const SizedBox(height: 5),
          ]),
    );
  }

  Widget _sectionColumn({required EdgeInsets padding}) => Padding(
        padding: padding,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final section
              in _sections.where((item) => item['visible'] != false))
            _section(section),
        ]),
      );

  Widget _section(Map<String, dynamic> section) {
    final title = (section['title'] ?? '').toString().trim();
    final kind = (section['kind'] ?? '').toString();
    final fields = _asList(section['fields']);
    final entries = _asList(section['entries']);
    final visibleEntries = entries
        .where((entry) => entry.entries.any((item) =>
            item.key != 'id' && item.value.toString().trim().isNotEmpty))
        .toList();
    if (title.isEmpty || visibleEntries.isEmpty) return const SizedBox.shrink();
    final isSkills = kind == 'skills' || kind == 'languages';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (template.layout == ResumeTemplateLayout.editorial)
            Container(
                width: 3,
                height: 12,
                margin: const EdgeInsets.only(right: 7),
                color: template.accent),
          Expanded(
              child: Text(title.toUpperCase(),
                  style: TextStyle(
                      color: template.accent,
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      fontFamily: template.serif ? 'serif' : null))),
        ]),
        const SizedBox(height: 3),
        Container(height: 0.8, color: template.accent.withValues(alpha: 0.36)),
        const SizedBox(height: 5),
        if (isSkills)
          Wrap(spacing: 8, runSpacing: 5, children: [
            for (final entry in visibleEntries)
              Text(_entryTitle(entry, fields),
                  style:
                      const TextStyle(color: Color(0xFF39424B), fontSize: 8)),
          ])
        else
          for (final entry in visibleEntries.take(5)) _entry(entry, fields),
      ]),
    );
  }

  Widget _entry(Map<String, dynamic> entry, List<Map<String, dynamic>> fields) {
    final title = _entryTitle(entry, fields);
    final subtitle = _firstValue(entry, const [
      'organization',
      'institution',
      'issuer',
      'publisher',
      'technologies',
      'role'
    ]);
    final dates = [
      _firstValue(entry, const ['startDate', 'date']),
      _firstValue(entry, const ['endDate'])
    ].where((value) => value.isNotEmpty).join(' – ');
    final excluded = <String>{
      'id',
      'title',
      'role',
      'degree',
      'name',
      'skill',
      'language',
      'interest',
      'organization',
      'institution',
      'issuer',
      'publisher',
      'technologies',
      'startDate',
      'endDate',
      'date',
      'location',
      'url'
    };
    final details = <String>[];
    for (final field in fields) {
      final key = field['key']?.toString() ?? '';
      final value = entry[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && !excluded.contains(key)) details.add(value);
    }
    for (final item in entry.entries) {
      if (!excluded.contains(item.key) &&
          fields.every((field) => field['key'] != item.key)) {
        final value = item.value.toString().trim();
        if (value.isNotEmpty) details.add(value);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF282D32),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700))),
          if (dates.isNotEmpty)
            Text(dates,
                style:
                    const TextStyle(color: Color(0xFF68737D), fontSize: 6.8)),
        ]),
        if (subtitle.isNotEmpty ||
            _firstValue(entry, const ['location']).isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                  [
                    subtitle,
                    _firstValue(entry, const ['location'])
                  ].where((value) => value.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: template.accent.withValues(alpha: 0.94),
                      fontSize: 7.1,
                      fontStyle: template.serif
                          ? FontStyle.italic
                          : FontStyle.normal))),
        if (details.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(details.join('  •  '),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF46515C), fontSize: 7, height: 1.32))),
        if (_firstValue(entry, const ['url', 'credentialUrl']).isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_firstValue(entry, const ['url', 'credentialUrl']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: template.accent, fontSize: 6.5))),
      ]),
    );
  }

  String _entryTitle(
      Map<String, dynamic> entry, List<Map<String, dynamic>> fields) {
    final selected = _firstValue(entry, const [
      'role',
      'title',
      'degree',
      'name',
      'skill',
      'language',
      'interest',
      'summary'
    ]);
    if (selected.isNotEmpty) return selected;
    for (final field in fields) {
      final value = entry[field['key']?.toString()]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Details';
  }

  String _firstValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _value(Map<String, dynamic> map, String key, String fallback) {
    final value = map[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  Widget _mahiiLuxuryPreview() {
    const navy = Color(0xFF0F1C30);
    const gold = Color(0xFFC5A059);
    final name = _value(_personal, 'name', 'PRATEEK').toUpperCase();
    final title =
        _value(_personal, 'headline', 'GRAPHIC DESIGNER').toUpperCase();
    final firstName = name.split(' ').first;
    final sig = firstName.isEmpty
        ? 'Prateek'
        : firstName[0].toUpperCase() + firstName.substring(1).toLowerCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navy Sidebar
        Container(
          width: 152,
          color: navy,
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 2),
                  ),
                  child: Center(
                    child: Icon(Icons.person_outline_rounded,
                        color: gold.withValues(alpha: 0.8), size: 28),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.person_outline, size: 10, color: gold),
                const SizedBox(width: 4),
                const Text('CONTACT',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: gold,
                        letterSpacing: 1)),
              ]),
              const SizedBox(height: 4),
              Text('+91 98765 43210',
                  style: const TextStyle(fontSize: 6.5, color: Colors.white70)),
              Text('prateek@gmail.com',
                  style: const TextStyle(fontSize: 6.5, color: Colors.white70)),
              Text('Bhopal, India',
                  style: const TextStyle(fontSize: 6.5, color: Colors.white70)),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.school_outlined, size: 10, color: gold),
                const SizedBox(width: 4),
                const Text('EDUCATION',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: gold,
                        letterSpacing: 1)),
              ]),
              const SizedBox(height: 4),
              const Text('B.Sc Computer Science',
                  style: TextStyle(
                      fontSize: 6.5,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              const Text('AISECT University | 2019-2023',
                  style: TextStyle(fontSize: 6, color: Colors.white54)),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.settings_outlined, size: 10, color: gold),
                const SizedBox(width: 4),
                const Text('SKILLS',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: gold,
                        letterSpacing: 1)),
              ]),
              const SizedBox(height: 4),
              _miniSkillBar('Flutter / Dart', 0.9, gold),
              _miniSkillBar('Firebase', 0.85, gold),
              _miniSkillBar('UI Design', 0.78, gold),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Text(
                      sig,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        color: gold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DESIGN • CREATE • INSPIRE',
                      style: TextStyle(
                        fontSize: 5,
                        letterSpacing: 1,
                        color: gold.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Right Canvas
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: navy,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: gold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(width: 32, height: 1.5, color: gold),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.person_outline, size: 11, color: navy),
                  const SizedBox(width: 5),
                  const Text('PROFESSIONAL SUMMARY',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: navy,
                          letterSpacing: 0.5)),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Creative and detail-oriented professional with passion for designing visually stunning, modern and effective products.',
                  style: TextStyle(
                      fontSize: 7.5, color: Colors.grey[700], height: 1.3),
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.work_outline, size: 11, color: navy),
                  const SizedBox(width: 5),
                  const Text('EXPERIENCE',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: navy,
                          letterSpacing: 0.5)),
                ]),
                const SizedBox(height: 4),
                const Text('Software Developer',
                    style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: navy)),
                const Text('TechSolutions Pvt. Ltd. | 2023 - Present',
                    style: TextStyle(
                        fontSize: 7, color: gold, fontStyle: FontStyle.italic)),
                const SizedBox(height: 2),
                Text('• Built cross-platform mobile apps with Flutter & Firebase.',
                    style: TextStyle(fontSize: 7, color: Colors.grey[700])),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Father: Rajesh",
                          style: TextStyle(fontSize: 6, color: Colors.grey[600])),
                      Text("DOB: 12 Mar 2001",
                          style: TextStyle(fontSize: 6, color: Colors.grey[600])),
                      Text("Gender: Male",
                          style: TextStyle(fontSize: 6, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniSkillBar(String label, double level, Color gold) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 6, color: Colors.white70)),
            const SizedBox(height: 1),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: level,
                minHeight: 2.5,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(gold),
              ),
            ),
          ],
        ),
      );
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _asList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];

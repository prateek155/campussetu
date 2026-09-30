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
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _asList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];

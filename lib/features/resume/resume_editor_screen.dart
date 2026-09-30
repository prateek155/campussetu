import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/api_service.dart';
import 'resume_document_preview.dart';
import 'resume_templates.dart';

final Map<String, Future<UserCredential>> _resumeHandoffLogins = {};

Future<UserCredential> _signInFromResumeHandoff(String code) {
  final inFlight = _resumeHandoffLogins[code];
  if (inFlight != null) return inFlight;
  final login = () async {
    final customToken = await ApiService().exchangeResumeHandoff(code);
    return FirebaseAuth.instance.signInWithCustomToken(customToken);
  }();
  _resumeHandoffLogins[code] = login;
  return login.catchError((Object error) {
    _resumeHandoffLogins.remove(code);
    throw error;
  });
}

class ResumeEditorScreen extends StatefulWidget {
  final String templateId;
  final String? resumeId;
  final String? handoffCode;
  final bool downloadIntent;

  const ResumeEditorScreen({
    super.key,
    required this.templateId,
    this.resumeId,
    this.handoffCode,
    this.downloadIntent = false,
  });

  @override
  State<ResumeEditorScreen> createState() => _ResumeEditorScreenState();
}

class _ResumeEditorScreenState extends State<ResumeEditorScreen> {
  final _uuid = const Uuid();
  final Map<String, TextEditingController> _controllers = {};
  late final ResumeTemplateSpec? _template;
  Map<String, dynamic> _document = {};
  String? _resumeId;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _downloading = false;
  bool _showPreviewOnMobile = false;

  @override
  void initState() {
    super.initState();
    _template = resumeTemplateById(widget.templateId);
    _resumeId = widget.resumeId;
    _loadDocument();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDocument() async {
    if (_template == null) {
      setState(() {
        _error = 'This resume design does not exist.';
        _loading = false;
      });
      return;
    }
    try {
      if (widget.handoffCode != null && widget.handoffCode!.isNotEmpty) {
        await _signInFromResumeHandoff(widget.handoffCode!);
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null)
        throw Exception(
            'Open this editor from the CampusSetu app to sign in securely.');
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty)
        throw Exception(
            'Could not verify your CampusSetu session. Reopen the editor from the app.');
      ApiService().setToken(idToken);

      Map<String, dynamic> loaded;
      if (_resumeId != null) {
        loaded = await ApiService().getResume(_resumeId!);
        if (loaded['template_id']?.toString() != widget.templateId) {
          throw Exception('This resume does not match the selected design.');
        }
      } else {
        final profileResponse = await ApiService().getMe();
        final profile = profileResponse['data'] is Map
            ? Map<String, dynamic>.from(profileResponse['data'] as Map)
            : Map<String, dynamic>.from(profileResponse);
        loaded = defaultResumeDocument(profile: profile);
        loaded['template_id'] = widget.templateId;
      }

      final content = loaded['content'] is Map
          ? Map<String, dynamic>.from(loaded['content'] as Map)
          : loaded;
      _document = _normalizeDocument(content);
      if (loaded['title'] != null)
        _document['title'] = loaded['title'].toString();
      _resumeId = loaded['id']?.toString() ?? _resumeId;
      _syncTextControllers();
      if (mounted)
        setState(() {
          _error = null;
          _loading = false;
        });

      // Remove the one-time link code from the address bar after exchange.
      if (widget.handoffCode != null && mounted) {
        final query = <String, String>{
          if (_resumeId != null) 'resumeId': _resumeId!,
          if (widget.downloadIntent) 'intent': 'download',
        };
        final suffix =
            query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
        context.replace('/resume/${widget.templateId}$suffix');
      }
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Map<String, dynamic> _normalizeDocument(Map<String, dynamic> input) {
    final document = Map<String, dynamic>.from(input);
    document['title'] = (document['title'] ?? 'My Resume').toString();
    document['personal'] = document['personal'] is Map
        ? Map<String, dynamic>.from(document['personal'] as Map)
        : <String, dynamic>{};
    document['personalFields'] = document['personalFields'] is List
        ? (document['personalFields'] as List)
            .whereType<Map>()
            .map((field) => Map<String, dynamic>.from(field))
            .toList()
        : <Map<String, dynamic>>[];
    final sections = document['sections'] is List
        ? document['sections'] as List
        : <dynamic>[];
    document['sections'] = sections.whereType<Map>().map((rawSection) {
      final section = Map<String, dynamic>.from(rawSection);
      section['id'] = (section['id'] ?? _uuid.v4()).toString();
      section['title'] = (section['title'] ?? 'Section').toString();
      section['fields'] = section['fields'] is List
          ? (section['fields'] as List)
              .whereType<Map>()
              .map((field) => Map<String, dynamic>.from(field))
              .toList()
          : <Map<String, dynamic>>[];
      section['entries'] = section['entries'] is List
          ? (section['entries'] as List)
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList()
          : <Map<String, dynamic>>[];
      for (final field in section['fields'] as List<Map<String, dynamic>>) {
        field['key'] = (field['key'] ?? _uuid.v4()).toString();
        field['label'] = (field['label'] ?? 'Field').toString();
      }
      for (final entry in section['entries'] as List<Map<String, dynamic>>) {
        entry['id'] = (entry['id'] ?? _uuid.v4()).toString();
      }
      return section;
    }).toList();
    for (final field
        in document['personalFields'] as List<Map<String, dynamic>>) {
      field['key'] = (field['key'] ?? _uuid.v4()).toString();
      field['label'] = (field['label'] ?? 'Field').toString();
    }
    return document;
  }

  void _syncTextControllers() {
    void sync(String key, String value) {
      final controller =
          _controllers.putIfAbsent(key, () => TextEditingController());
      if (controller.text != value) controller.text = value;
    }

    sync('document.title', (_document['title'] ?? '').toString());
    final personal = _asMap(_document['personal']);
    for (final field in _asList(_document['personalFields'])) {
      final key = field['key']?.toString() ?? '';
      if (key.isNotEmpty)
        sync('personal.$key', (personal[key] ?? '').toString());
    }
    for (final section in _asList(_document['sections'])) {
      final id = section['id'].toString();
      sync('section.$id.title', (section['title'] ?? '').toString());
      for (final entry in _asList(section['entries'])) {
        final entryId = entry['id'].toString();
        for (final field in _asList(section['fields'])) {
          final key = field['key']?.toString() ?? '';
          if (key.isNotEmpty)
            sync('entry.$entryId.$key', (entry[key] ?? '').toString());
        }
      }
    }
  }

  void _setValue(String key, String value) {
    setState(() {
      if (key == 'document.title') {
        _document['title'] = value;
      } else if (key.startsWith('personal.')) {
        (_document['personal']
            as Map<String, dynamic>)[key.substring('personal.'.length)] = value;
      } else {
        final parts = key.split('.');
        if (parts.length == 3 && parts.first == 'section') {
          final section = _sectionById(parts[1]);
          if (section != null) section['title'] = value;
        } else if (parts.length == 3 && parts.first == 'entry') {
          final entry = _entryById(parts[1]);
          if (entry != null) entry[parts[2]] = value;
        }
      }
    });
  }

  Map<String, dynamic>? _sectionById(String id) {
    for (final section in _asList(_document['sections'])) {
      if (section['id'] == id) return section;
    }
    return null;
  }

  Map<String, dynamic>? _entryById(String id) {
    for (final section in _asList(_document['sections'])) {
      for (final entry in _asList(section['entries'])) {
        if (entry['id'] == id) return entry;
      }
    }
    return null;
  }

  Future<String?> _askText(String title,
      {String initial = '', String hint = ''}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _addPersonalField() async {
    final label = await _askText('Add a personal detail',
        hint: 'e.g. Portfolio, work authorization');
    if (label == null || label.isEmpty || !mounted) return;
    final key = _uuid.v4();
    setState(() {
      (_document['personalFields'] as List).add({'key': key, 'label': label});
      (_document['personal'] as Map<String, dynamic>)[key] = '';
    });
    _syncTextControllers();
  }

  void _removePersonalField(Map<String, dynamic> field) {
    setState(() {
      (_document['personalFields'] as List).remove(field);
      (_document['personal'] as Map<String, dynamic>).remove(field['key']);
    });
  }

  Future<void> _addSection() async {
    final title = await _askText('Add resume section',
        hint: 'e.g. Coursework, Hobbies, References');
    if (title == null || title.isEmpty || !mounted) return;
    setState(() {
      (_document['sections'] as List).add({
        'id': _uuid.v4(),
        'kind': 'custom',
        'title': title,
        'fields': <Map<String, dynamic>>[
          {'key': 'details', 'label': 'Details', 'multiline': true},
        ],
        'entries': <Map<String, dynamic>>[],
      });
    });
    _syncTextControllers();
  }

  void _removeSection(Map<String, dynamic> section) {
    setState(() => (_document['sections'] as List).remove(section));
  }

  void _addEntry(Map<String, dynamic> section) {
    final entry = <String, dynamic>{'id': _uuid.v4()};
    for (final field in _asList(section['fields'])) {
      entry[field['key'].toString()] = '';
    }
    setState(() => (section['entries'] as List).add(entry));
    _syncTextControllers();
  }

  void _removeEntry(Map<String, dynamic> section, Map<String, dynamic> entry) {
    setState(() => (section['entries'] as List).remove(entry));
  }

  Future<void> _addSectionField(Map<String, dynamic> section) async {
    final label =
        await _askText('Add a field', hint: 'e.g. Team size, award level');
    if (label == null || label.isEmpty || !mounted) return;
    final key = _uuid.v4();
    setState(() {
      (section['fields'] as List)
          .add({'key': key, 'label': label, 'multiline': false});
      for (final entry in _asList(section['entries'])) {
        entry[key] = '';
      }
    });
    _syncTextControllers();
  }

  void _removeSectionField(
      Map<String, dynamic> section, Map<String, dynamic> field) {
    final key = field['key'];
    setState(() {
      (section['fields'] as List).remove(field);
      for (final entry in _asList(section['entries'])) {
        entry.remove(key);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = (_document['title'] ?? '').toString().trim();
    if (title.isEmpty) {
      _notice('Add a title for this resume before saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'title': title,
        'template_id': widget.templateId,
        'content': _document
      };
      final saved = _resumeId == null
          ? await ApiService().createResume(body)
          : await ApiService().updateResume(_resumeId!, body);
      _resumeId = saved['id']?.toString() ?? _resumeId;
      if (mounted) {
        setState(() => _saving = false);
        _notice('Resume saved to your CampusSetu account.');
        _cleanHandoffFromUrl();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _notice(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _cleanHandoffFromUrl() {
    if (widget.handoffCode == null || !mounted) return;
    final query = _resumeId == null
        ? ''
        : '?resumeId=${Uri.encodeQueryComponent(_resumeId!)}';
    context.replace('/resume/${widget.templateId}$query');
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _downloadPdf() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final pdf = _buildPdf();
      final safeName = (_document['title'] ?? 'CampusSetu resume')
          .toString()
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
      await Printing.layoutPdf(
          name: '$safeName.pdf', onLayout: (_) async => pdf.save());
    } catch (error) {
      if (mounted) _notice('Could not create PDF: $error');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  pw.Document _buildPdf() {
    final pdf = pw.Document();
    final accent = PdfColor.fromHex(
        '#${_template!.accent.value.toRadixString(16).padLeft(8, '0').substring(2)}');
    final personal = _asMap(_document['personal']);
    final name = _value(personal, 'name', 'Your Name');
    final headline = _value(personal, 'headline', '');
    final contacts = [
      'email',
      'phone',
      'location',
      'linkedin',
      'website',
      'github'
    ]
        .map((key) => _value(personal, key, ''))
        .where((value) => value.isNotEmpty)
        .join('   |   ');
    final isBand = _template!.layout == ResumeTemplateLayout.band ||
        _template!.layout == ResumeTemplateLayout.sidebar;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 42),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Text('${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.fromLTRB(
              isBand ? 18 : 0, isBand ? 17 : 7, 18, isBand ? 17 : 12),
          decoration: isBand
              ? pw.BoxDecoration(
                  color: accent, borderRadius: pw.BorderRadius.circular(5))
              : null,
          child: pw.Column(
            crossAxisAlignment:
                _template!.layout == ResumeTemplateLayout.centered
                    ? pw.CrossAxisAlignment.center
                    : pw.CrossAxisAlignment.start,
            children: [
              if (!isBand)
                pw.Container(
                    width: double.infinity,
                    height: 3,
                    color: accent,
                    margin: const pw.EdgeInsets.only(bottom: 13)),
              pw.Text(name,
                  style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: isBand ? PdfColors.white : accent)),
              if (headline.isNotEmpty)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(headline,
                        style: pw.TextStyle(
                            fontSize: 11,
                            color:
                                isBand ? PdfColors.white : PdfColors.grey700))),
              if (contacts.isNotEmpty)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 7),
                    child: pw.Text(contacts,
                        style: pw.TextStyle(
                            fontSize: 8,
                            color:
                                isBand ? PdfColors.white : PdfColors.grey700))),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        for (final section in _asList(_document['sections']))
          ..._pdfSection(section, accent),
      ],
    ));
    return pdf;
  }

  List<pw.Widget> _pdfSection(Map<String, dynamic> section, PdfColor accent) {
    if (section['visible'] == false) return [];
    final title = (section['title'] ?? '').toString().trim();
    final fields = _asList(section['fields']);
    final entries = _asList(section['entries'])
        .where((entry) => entry.entries.any((item) =>
            item.key != 'id' && item.value.toString().trim().isNotEmpty))
        .toList();
    if (title.isEmpty || entries.isEmpty) return [];
    final widgets = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(bottom: 4),
        margin: const pw.EdgeInsets.only(bottom: 6, top: 5),
        decoration: pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: accent, width: 0.8))),
        child: pw.Text(title.toUpperCase(),
            style: pw.TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.6)),
      ),
    ];
    if (section['kind'] == 'skills' || section['kind'] == 'languages') {
      final labels = entries
          .map((entry) => _pdfEntryValues(entry, fields)
              .where((value) => value.isNotEmpty)
              .join(' — '))
          .where((value) => value.isNotEmpty)
          .toList();
      widgets.add(pw.Text(labels.join('     •     '),
          style: const pw.TextStyle(fontSize: 9, lineSpacing: 3)));
    } else {
      for (final entry in entries) {
        final values = _pdfEntryValues(entry, fields);
        final first = values.isNotEmpty ? values.first : '';
        final other =
            values.skip(1).where((value) => value.isNotEmpty).toList();
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(first,
                    style: pw.TextStyle(
                        fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                if (other.isNotEmpty)
                  pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(other.join('   ·   '),
                          style: pw.TextStyle(fontSize: 8.5, color: accent))),
              ]),
        ));
      }
    }
    widgets.add(pw.SizedBox(height: 7));
    return widgets;
  }

  List<String> _pdfEntryValues(
          Map<String, dynamic> entry, List<Map<String, dynamic>> fields) =>
      [
        for (final field in fields)
          if ((entry[field['key']?.toString()] ?? '')
              .toString()
              .trim()
              .isNotEmpty)
            (entry[field['key']?.toString()] ?? '').toString().trim(),
      ];

  Widget _textInput(
      {required String controllerKey,
      required String label,
      required String value,
      bool multiline = false,
      String? hint}) {
    final controller = _controllers.putIfAbsent(
        controllerKey, () => TextEditingController(text: value));
    if (controller.text != value) controller.text = value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 5 : 1,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (text) => _setValue(controllerKey, text),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF6F8FA),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: Color(0xFFDCE2E7))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: Color(0xFFDCE2E7))),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        ),
      ),
    );
  }

  Widget _editorForm() {
    final personal = _asMap(_document['personal']);
    final personalFields = _asList(_document['personalFields']);
    final sections = _asList(_document['sections']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        if (widget.downloadIntent)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5F3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB8DDD5)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF187866)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your resume is ready. Tap “Download PDF” at the top to save or print it.',
                    style: TextStyle(
                      color: Color(0xFF245B52),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _panel(
          title: 'Resume details',
          subtitle: 'Give this version a name so you can find it later.',
          child: _textInput(
              controllerKey: 'document.title',
              label: 'Resume name',
              value: (_document['title'] ?? '').toString(),
              hint: 'e.g. Software Engineer Resume'),
        ),
        _panel(
          title: 'Personal information',
          subtitle: 'Add the details employers need to contact you.',
          trailing: IconButton(
              tooltip: 'Add personal detail',
              onPressed: _addPersonalField,
              icon: const Icon(Icons.add_circle_outline_rounded)),
          child: Column(children: [
            for (final field in personalFields)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _textInput(
                  controllerKey: 'personal.${field['key']}',
                  label: (field['label'] ?? 'Detail').toString(),
                  value: (personal[field['key']] ?? '').toString(),
                )),
                IconButton(
                    tooltip: 'Remove field',
                    onPressed: () => _removePersonalField(field),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Color(0xFF9A5961))),
              ]),
          ]),
        ),
        for (final section in sections) _sectionEditor(section),
        OutlinedButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a custom section')),
        const SizedBox(height: 18),
        FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save resume')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: _downloading ? null : _downloadPdf,
            icon: _downloading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            label:
                Text(_downloading ? 'Preparing PDF…' : 'Download / print PDF')),
      ],
    );
  }

  Widget _sectionEditor(Map<String, dynamic> section) {
    final sectionId = section['id'].toString();
    final fields = _asList(section['fields']);
    final entries = _asList(section['entries']);
    return _panel(
      title: '',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: _textInput(
                  controllerKey: 'section.$sectionId.title',
                  label: 'Section name',
                  value: (section['title'] ?? '').toString())),
          IconButton(
              tooltip: 'Remove section',
              onPressed: () => _removeSection(section),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFF9A5961))),
        ]),
        for (var index = 0; index < entries.length; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 11),
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 4),
            decoration: BoxDecoration(
                color: const Color(0xFFFAFBFC),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFE2E7EC))),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Text('Entry ${index + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF586573)))),
                IconButton(
                    tooltip: 'Remove entry',
                    onPressed: () => _removeEntry(section, entries[index]),
                    icon: const Icon(Icons.close_rounded, size: 18))
              ]),
              for (final field in fields)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _textInput(
                    controllerKey:
                        'entry.${entries[index]['id']}.${field['key']}',
                    label: (field['label'] ?? 'Field').toString(),
                    value: (entries[index][field['key']] ?? '').toString(),
                    multiline: field['multiline'] == true,
                  )),
                  IconButton(
                      tooltip: 'Remove field',
                      onPressed: () => _removeSectionField(section, field),
                      icon: const Icon(Icons.remove_circle_outline,
                          size: 18, color: Color(0xFF9A5961))),
                ]),
            ]),
          ),
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton.icon(
              onPressed: () => _addEntry(section),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add entry')),
          TextButton.icon(
              onPressed: () => _addSectionField(section),
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: const Text('Add field')),
        ]),
      ]),
    );
  }

  Widget _panel(
          {required String title,
          String? subtitle,
          Widget? trailing,
          required Widget child}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE3E8EC)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 11,
                  offset: Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title.isNotEmpty || trailing != null)
            Row(children: [
              Expanded(
                  child: title.isEmpty
                      ? const SizedBox.shrink()
                      : Text(title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF202831)))),
              if (trailing != null) trailing
            ]),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 13),
                child: Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF73808B), fontSize: 12))),
          child,
        ]),
      );

  Widget _previewPanel() => ColoredBox(
        color: const Color(0xFFE9EEF2),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 11),
              child: Row(children: [
                const Icon(Icons.visibility_outlined, color: Color(0xFF586573)),
                const SizedBox(width: 8),
                const Text('Live preview',
                    style: TextStyle(
                        color: Color(0xFF35414C), fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(_template!.name,
                    style: TextStyle(
                        color: _template!.accent, fontWeight: FontWeight.w700))
              ])),
          Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: ResumeDocumentPreview(
                              template: _template!, document: _document))))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
          backgroundColor: Color(0xFFF3F5F7),
          body: Center(child: CircularProgressIndicator()));
    if (_error != null || _template == null) {
      return Scaffold(
          backgroundColor: const Color(0xFFF3F5F7),
          appBar: AppBar(title: const Text('Resume editor')),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_clock_outlined,
                        size: 42, color: Color(0xFF71808A)),
                    const SizedBox(height: 14),
                    Text(_error ?? 'Template not found',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => context.go('/resume'),
                        child: const Text('Back to templates'))
                  ]))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
            tooltip: 'Back to templates',
            onPressed: () => context.go('/resume'),
            icon: const Icon(Icons.arrow_back_rounded)),
        title: Row(children: [
          const Icon(Icons.description_outlined, color: Color(0xFF147D92)),
          const SizedBox(width: 9),
          const Text('CampusSetu Resume Studio',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(width: 9),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _template!.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_template!.name,
                  style: TextStyle(
                      color: _template!.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)))
        ]),
        actions: [
          if (_resumeId != null)
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('Saved resume',
                        style: TextStyle(
                            color: Colors.green.shade700, fontSize: 12)))),
          IconButton(
              tooltip: 'Save resume',
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined)),
          Padding(
              padding: const EdgeInsets.only(right: 9),
              child: FilledButton.icon(
                  onPressed: _downloading ? null : _downloadPdf,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(_downloading ? 'Preparing…' : 'Download PDF'))),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 980) {
          return Row(children: [
            Expanded(flex: 11, child: _editorForm()),
            const VerticalDivider(width: 1),
            Expanded(flex: 10, child: _previewPanel())
          ]);
        }
        return Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Edit'),
                      icon: Icon(Icons.edit_outlined)),
                  ButtonSegment(
                      value: true,
                      label: Text('Preview'),
                      icon: Icon(Icons.visibility_outlined))
                ],
                selected: {_showPreviewOnMobile},
                onSelectionChanged: (values) =>
                    setState(() => _showPreviewOnMobile = values.first),
              )),
          Expanded(
              child: _showPreviewOnMobile ? _previewPanel() : _editorForm()),
        ]);
      }),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _asList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];

String _value(Map<String, dynamic> map, String key, String fallback) {
  final value = map[key]?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

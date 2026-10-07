import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/app_config.dart';
import '../../core/services/api_service.dart';
import 'widgets/admin_toast.dart';

class AddEventScreen extends StatefulWidget {
  final Map<String, dynamic>? event;
  const AddEventScreen({super.key, this.event});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  static const _bg      = Color(0xFF0D0F1A);
  static const _card    = Color(0xFF141728);
  static const _border  = Color(0xFF252840);
  static const _purple  = Color(0xFFA855F7);
  static const _red     = Color(0xFFEF4444);
  static const _green   = Color(0xFF22C55E);
  static const _ink     = Color(0xFFE9EBEE);

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _timeDateCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  
  XFile? _photo;
  String? _existingPictureUrl;
  bool _loading = false;
  bool _inAppRegistration = false;
  bool _enableOrganizerAccess = false;
  final _organizerIdCtrl = TextEditingController();
  final _organizerPasswordCtrl = TextEditingController();
  bool _showOrganizerPassword = false;
  final _picker = ImagePicker();

  bool get _isEditing => widget.event != null;
  String get _eventId => (widget.event?['_id'] ?? widget.event?['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.event!;
      _nameCtrl.text = (e['name'] ?? e['title'] ?? '').toString();
      _descCtrl.text = (e['description'] ?? '').toString();
      _placeCtrl.text = (e['place'] ?? e['venue'] ?? '').toString();
      _timeDateCtrl.text = (e['time_date'] ?? e['date'] ?? '').toString();
      _inAppRegistration = e['registration_mode'] == 'internal';
      _linkCtrl.text = (e['registration_link'] ?? e['link'] ?? '').toString();
      _existingPictureUrl = (e['picture_url'] ?? e['image_url'] ?? e['image'] ?? '').toString();
      _enableOrganizerAccess = e['organizer_access_enabled'] == true;
      _organizerIdCtrl.text = (e['organizer_id'] ?? '').toString();
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Event name is required', _red);
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _snack('Description is required', _red);
      return;
    }
    if (_placeCtrl.text.trim().isEmpty) {
      _snack('Place/Venue is required', _red);
      return;
    }
    if (_timeDateCtrl.text.trim().isEmpty) {
      _snack('Time & Date is required', _red);
      return;
    }
    if (!_inAppRegistration) {
      final rawLink = _linkCtrl.text.trim();
      final normalizedLink = rawLink.contains('://') ? rawLink : 'https://$rawLink';
      final uri = Uri.tryParse(normalizedLink);
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        _snack('Enter a valid HTTP or HTTPS registration link', _red);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'place': _placeCtrl.text.trim(),
        'time_date': _timeDateCtrl.text.trim(),
        'registration_mode': _inAppRegistration ? 'internal' : 'external',
        'registration_link': _inAppRegistration ? null : _linkCtrl.text.trim(),
        if (_inAppRegistration) ...{
          'organizer_access_enabled': _enableOrganizerAccess,
          if (_enableOrganizerAccess) ...{
            if (_organizerIdCtrl.text.trim().isNotEmpty)
              'organizer_id': _organizerIdCtrl.text.trim(),
            if (_organizerPasswordCtrl.text.trim().isNotEmpty)
              'organizer_password': _organizerPasswordCtrl.text.trim(),
          },
        },
      };

      if (_isEditing) {
        await ApiService().updateEvent(_eventId, payload, photoPath: _photo?.path);
        if (mounted) {
          _snack('Event updated successfully!', _green);
          context.pop(true);
        }
      } else {
        await ApiService().createEvent(payload, photoPath: _photo?.path);
        if (mounted) {
          _snack('Event added successfully!', _green);
          context.pop(true);
        }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', _red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color bg) {
    if (bg == _green) {
      AdminToast.success(context, msg);
    } else {
      AdminToast.error(context, msg);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _placeCtrl.dispose();
    _timeDateCtrl.dispose();
    _linkCtrl.dispose();
    _organizerIdCtrl.dispose();
    _organizerPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Campus Event' : 'Add Campus Event',
          style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: _ink),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Event Name'),
            _Field(controller: _nameCtrl, hint: 'e.g. Annual Tech Fest'),
            const SizedBox(height: 20),
            
            const _Label('Description'),
            _Field(controller: _descCtrl, hint: 'Enter details about the event...', maxLines: 4),
            const SizedBox(height: 20),
            
            const _Label('Place / Venue'),
            _Field(controller: _placeCtrl, hint: 'e.g. Main Auditorium / Campus Ground'),
            const SizedBox(height: 20),
            
            const _Label('Time & Date'),
            _Field(controller: _timeDateCtrl, hint: 'e.g. Tomorrow at 5:00 PM'),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141728),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _inAppRegistration
                      ? const Color(0xFF3FD8F5).withValues(alpha: 0.5)
                      : _border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _inAppRegistration ? Icons.how_to_reg_rounded : Icons.link_rounded,
                        color: _inAppRegistration ? const Color(0xFF3FD8F5) : const Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'In-App Registration',
                          style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: _inAppRegistration,
                        onChanged: (val) => setState(() => _inAppRegistration = val),
                        activeThumbColor: const Color(0xFF3FD8F5),
                        activeTrackColor: const Color(0xFF3FD8F5).withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _inAppRegistration
                        ? 'Students can register directly inside CampusSetu with 1 tap. You can track, manage, edit, and export attendees.'
                        : 'Students will be directed to your external Google Form / website link.',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                  if (!_inAppRegistration) ...[
                    const SizedBox(height: 14),
                    const _Label('Registration Link'),
                    _Field(controller: _linkCtrl, hint: 'https://forms.gle/...'),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Divider(color: _border),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Organizer / Manager Login Access',
                            style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch(
                          value: _enableOrganizerAccess,
                          onChanged: (val) => setState(() => _enableOrganizerAccess = val),
                          activeThumbColor: const Color(0xFFF59E0B),
                          activeTrackColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Allow college fest / event club team to view attendees, mark attendance, and export Excel on desk without Super Admin access.',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                    if (_enableOrganizerAccess) ...[
                      const SizedBox(height: 14),
                      const _Label('Organizer Username / ID'),
                      _Field(
                        controller: _organizerIdCtrl,
                        hint: 'e.g. techfest2026 or leave blank for auto code',
                      ),
                      const SizedBox(height: 14),
                      const _Label('Organizer Password'),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141728),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: TextField(
                          controller: _organizerPasswordCtrl,
                          obscureText: !_showOrganizerPassword,
                          style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _isEditing ? 'Enter new password to update' : 'Set password for event desk team',
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: InputBorder.none,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showOrganizerPassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF9CA3AF),
                                size: 18,
                              ),
                              onPressed: () => setState(() => _showOrganizerPassword = !_showOrganizerPassword),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final orgId = _organizerIdCtrl.text.trim().isNotEmpty
                                ? _organizerIdCtrl.text.trim()
                                : (_isEditing ? (widget.event?['event_code'] ?? widget.event?['id']) : 'Auto Event Code');
                            final pwd = _organizerPasswordCtrl.text.trim();
                            final link = '${AppConfig.userWebBaseUrl}/events?manage=true';
                            final creds = 'Event: ${_nameCtrl.text.trim()}\nOrganizer ID: $orgId\nPassword: $pwd\nLogin Link: $link';
                            Clipboard.setData(ClipboardData(text: creds));
                            AdminToast.success(context, 'Organizer credentials copied to clipboard!');
                          },
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFFF59E0B), size: 16),
                          label: const Text(
                            'Copy Organizer Credentials',
                            style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            const _Label('Event Banner / Photo (Optional)'),
            _PhotoPicker(
              photo: _photo,
              existingImageUrl: _existingPictureUrl,
              onTap: () async {
                final xf = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (xf != null) setState(() => _photo = xf);
              },
            ),
            const SizedBox(height: 32),

            GestureDetector(
              onTap: _loading ? null : _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _loading ? _purple.withValues(alpha: 0.5) : _purple,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isEditing ? 'Update Event' : 'Publish Event',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(text, style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _Field({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF252840)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final XFile? photo;
  final String? existingImageUrl;
  final VoidCallback onTap;

  const _PhotoPicker({
    required this.photo,
    this.existingImageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const border  = Color(0xFF252840);
    const purple  = Color(0xFFA855F7);
    const cardAlt = Color(0xFF1C2033);

    final hasExisting = existingImageUrl != null && existingImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (photo != null || hasExisting) ? purple.withValues(alpha: 0.4) : border),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo != null
            ? Stack(fit: StackFit.expand, children: [
                Image.file(File(photo!.path), fit: BoxFit.cover),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ])
            : hasExisting
                ? Stack(fit: StackFit.expand, children: [
                    Image.network(existingImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Change Image', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ])
                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, color: purple, size: 32),
                    SizedBox(height: 8),
                    Text('Add event photo', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  ]),
      ),
    );
  }
}

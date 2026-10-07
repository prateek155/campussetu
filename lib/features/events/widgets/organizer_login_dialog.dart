import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../admin/widgets/admin_toast.dart';
import '../../admin/widgets/admin_event_registrations_sheet.dart';

class OrganizerLoginDialog extends StatefulWidget {
  final String? initialEventCode;

  const OrganizerLoginDialog({
    super.key,
    this.initialEventCode,
  });

  static Future<void> show(BuildContext context, {String? initialEventCode}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => OrganizerLoginDialog(initialEventCode: initialEventCode),
    );
  }

  @override
  State<OrganizerLoginDialog> createState() => _OrganizerLoginDialogState();
}

class _OrganizerLoginDialogState extends State<OrganizerLoginDialog> {
  static const _card = Color(0xFF141728);
  static const _cardLighter = Color(0xFF1C2035);
  static const _border = Color(0xFF252840);
  static const _orange = Color(0xFFF59E0B);
  static const _textMain = Color(0xFFE9EBEE);
  static const _textSub = Color(0xFF9CA3AF);
  static const _red = Color(0xFFEF4444);

  late final TextEditingController _idCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.initialEventCode ?? '');
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _idCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Please enter Event Code or Organizer ID');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter the organizer password');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService().organizerLogin(
        organizerId: identifier,
        eventCode: identifier,
        password: password,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close login modal

      final event = Map<String, dynamic>.from(res['event'] as Map);
      final eventId = (event['id'] ?? '').toString();
      final eventName = (event['name'] ?? 'Event Attendees').toString();

      AdminToast.success(context, 'Organizer access unlocked: $eventName');

      // Open the registrations sheet in organizer mode
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AdminEventRegistrationsSheet(
          eventId: eventId,
          eventName: eventName,
          isOrganizer: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errStr = e.toString();
      if (errStr.contains('401') || errStr.toLowerCase().contains('incorrect password')) {
        errStr = 'Incorrect password or invalid Event ID';
      } else if (errStr.contains('403') || errStr.toLowerCase().contains('disabled')) {
        errStr = 'Organizer access is currently disabled for this event';
      } else if (errStr.contains('429')) {
        errStr = 'Too many attempts. Please try again after 15 minutes.';
      }
      setState(() {
        _loading = false;
        _errorMessage = errStr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: _orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Organizer Portal',
                          style: TextStyle(
                            color: _textMain,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Desk access for attendee management',
                          style: TextStyle(color: _textSub, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _textSub, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _red.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: _red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Event Code / Organizer ID Field
              const Text(
                'Event Code or Organizer ID',
                style: TextStyle(color: _textSub, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: _cardLighter,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _idCtrl,
                  style: const TextStyle(color: _textMain, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'e.g. EVT-4A9B2C or techfest2026',
                    hintStyle: TextStyle(color: _textSub, fontSize: 13),
                    prefixIcon: Icon(Icons.confirmation_number_outlined, color: _orange, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Password Field
              const Text(
                'Organizer Password',
                style: TextStyle(color: _textSub, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: _cardLighter,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  style: const TextStyle(color: _textMain, fontSize: 14),
                  onSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    hintText: 'Enter event password',
                    hintStyle: const TextStyle(color: _textSub, fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: _orange, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: _textSub,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: const Color(0xFF0F111A),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _loading ? null : _handleLogin,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Unlock Attendee Desk',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
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

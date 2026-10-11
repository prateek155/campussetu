import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/models/event_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/router/app_router.dart';
import 'widgets/organizer_login_dialog.dart';


class EventsScreen extends StatefulWidget {
  final String? initialEventId;
  final String? initialEventCode;
  final bool openOrganizerLogin;

  const EventsScreen({
    super.key,
    this.initialEventId,
    this.initialEventCode,
    this.openOrganizerLogin = false,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<EventModel> _events = [];
  bool _isLoading = true;
  bool _initialTargetHandled = false;
  EventModel? _focusedEvent;
  final Set<String> _registeringEventIds = {};
  final Set<String> _bookmarkedEventIds = {};

  // Breakpoint: below this width => original mobile layout (unchanged).
  // At/above this width => web/desktop layout (2-3 cards per row).
  static const double _webBreakpoint = 650;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    if (widget.initialEventCode != null || widget.initialEventId != null) {
      _checkInitialTarget();
    }
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEventCode != oldWidget.initialEventCode ||
        widget.initialEventId != oldWidget.initialEventId) {
      _initialTargetHandled = false;
      _checkInitialTarget();
    }
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final rawEvents = await ApiService().getEvents();
      setState(() {
        _events = rawEvents.map((e) => EventModel.fromJson(e)).toList();
      });
      _checkInitialTarget();
    } catch (e) {
      _checkInitialTarget();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load events: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkInitialTarget() async {
    if (_initialTargetHandled) return;
    final target = widget.initialEventCode ?? widget.initialEventId;
    if (widget.openOrganizerLogin && (target == null || target.trim().isEmpty)) {
      _initialTargetHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) OrganizerLoginDialog.show(context);
      });
      return;
    }
    if (target == null || target.trim().isEmpty) return;
    _initialTargetHandled = true;

    // Search in loaded events
    final q = target.trim().toLowerCase();
    EventModel? matched;
    for (final e in _events) {
      if (e.id.toLowerCase() == q || (e.eventCode != null && e.eventCode!.toLowerCase() == q)) {
        matched = e;
        break;
      }
    }

    final found = matched;
    if (found != null) {
      setState(() {
        _focusedEvent = found;
        _isLoading = false;
      });
      if (widget.openOrganizerLogin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            OrganizerLoginDialog.show(context, initialEventCode: found.eventCode ?? found.id);
          }
        });
      }
      return;
    }

    // If not found in current catalog (e.g., direct public link), fetch via public API
    try {
      final res = await ApiService().getPublicEvent(target);
      final raw = res['event'];
      if (raw != null && raw is Map) {
        final publicEvent = EventModel.fromJson(Map<String, dynamic>.from(raw));
        if (mounted) {
          setState(() {
            _focusedEvent = publicEvent;
            _isLoading = false;
            if (!_events.any((e) => e.id == publicEvent.id)) {
              _events.insert(0, publicEvent);
            }
          });
          if (widget.openOrganizerLogin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                OrganizerLoginDialog.show(context, initialEventCode: publicEvent.eventCode ?? publicEvent.id);
              }
            });
          }
        }
      }
    } catch (_) {}
  }


  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  void _copyEventLink(EventModel event) {
    final identifier = (event.eventCode != null && event.eventCode!.isNotEmpty) ? event.eventCode! : event.id;
    final shareUrl = '${AppConfig.userWebBaseUrl}/events?code=$identifier';
    Clipboard.setData(ClipboardData(text: shareUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Event link copied ($identifier)! Anyone can register directly without sign-up.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.tealAccent,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _handleRegistration(EventModel event) async {
    if (event.registrationMode != 'internal') {
      await _launchUrl(event.registrationLink);
      return;
    }

    final bool isUserLoggedIn = AuthService().currentUser != null;

    // If student is not logged in, prompt direct guest registration form
    if (!isUserLoggedIn) {
      await _showGuestRegistrationModal(event);
      return;
    }

    if (event.isRegistered) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel registration?'),
          content: Text('You will give up your place for ${event.name}.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep registration')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Cancel registration')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _registeringEventIds.add(event.id));
    try {
      if (event.isRegistered) {
        await ApiService().cancelEventRegistration(event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your event registration was cancelled')));
        }
      } else {
        await ApiService().registerForEvent(event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are registered for this event!')));
        }
      }
      if (mounted) await _fetchEvents();
    } catch (e) {
      // If student account has an issue, offer guest registration fallback
      if (mounted && !event.isRegistered) {
        _showGuestRegistrationModal(event);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update your registration: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _registeringEventIds.remove(event.id));
    }
  }

  Future<void> _showGuestRegistrationModal(EventModel event) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final collegeCtrl = TextEditingController();
    final branchCtrl = TextEditingController();

    bool isSubmitting = false;
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              decoration: const BoxDecoration(
                color: Color(0xFF141728),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.how_to_reg_rounded, color: Color(0xFF3FD8F5), size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Register for Event',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (event.eventCode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3FD8F5).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF3FD8F5).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              event.eventCode!,
                              style: const TextStyle(
                                color: Color(0xFF3FD8F5),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.name,
                      style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Direct Registration — No sign up or password required.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    if (formError != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          formError!,
                          style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
                        ),
                      ),

                    _modalField(nameCtrl, 'Full Name *', Icons.person_outline, TextInputType.name),
                    const SizedBox(height: 10),
                    _modalField(emailCtrl, 'Email Address *', Icons.email_outlined, TextInputType.emailAddress),
                    const SizedBox(height: 10),
                    _modalField(phoneCtrl, 'WhatsApp / Phone Number *', Icons.phone_outlined, TextInputType.phone),
                    const SizedBox(height: 10),
                    _modalField(collegeCtrl, 'College / Institute (Optional)', Icons.school_outlined, TextInputType.text),
                    const SizedBox(height: 10),
                    _modalField(branchCtrl, 'Course / Branch (Optional)', Icons.auto_stories_outlined, TextInputType.text),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final phone = phoneCtrl.text.trim();

                                if (name.length < 2) {
                                  setModalState(() => formError = 'Enter your full name (at least 2 characters)');
                                  return;
                                }
                                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                                  setModalState(() => formError = 'Enter a valid email address');
                                  return;
                                }
                                if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
                                  setModalState(() => formError = 'Enter a valid 10-digit phone number');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  formError = null;
                                });

                                try {
                                  final identifier = (event.eventCode != null && event.eventCode!.isNotEmpty)
                                      ? event.eventCode!
                                      : event.id;
                                  final payload = {
                                    'name': name,
                                    'email': email,
                                    'phone': phone,
                                    'college': collegeCtrl.text.trim(),
                                    'branch': branchCtrl.text.trim(),
                                  };

                                  final res = await ApiService().publicRegisterForEvent(identifier, payload);
                                  if (!mounted) return;
                                  Navigator.pop(bottomSheetContext);

                                  final msg = res['message']?.toString() ?? 'You are registered for ${event.name}!';
                                  await _showRegistrationSuccessDialog(event.name, msg);
                                  await _fetchEvents();
                                } catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    formError = e.toString().replaceAll('Exception:', '').trim();
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Confirm Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalField(TextEditingController ctrl, String label, IconData icon, TextInputType kType) {
    return TextField(
      controller: ctrl,
      keyboardType: kType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 18),
        filled: true,
        fillColor: const Color(0xFF1E2238),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3FD8F5), width: 1.2),
        ),
      ),
    );
  }

  Future<void> _showRegistrationSuccessDialog(String eventName, String message) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141728),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('Registered!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eventName, style: const TextStyle(color: Color(0xFF3FD8F5), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade300, fontSize: 13)),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _toggleBookmark(EventModel event) {
    setState(() {
      if (_bookmarkedEventIds.contains(event.id)) {
        _bookmarkedEventIds.remove(event.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from saved events'),
            backgroundColor: Color(0xFF1E2438),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        _bookmarkedEventIds.add(event.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bookmark_rounded, color: Color(0xFF4361EE), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Saved "${event.name}" to bookmarks!')),
              ],
            ),
            backgroundColor: const Color(0xFF1E2438),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  static const List<String> _monthNames = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  Map<String, String> _extractEventDate(EventModel event) {
    final lower = event.timeDate.toLowerCase();

    if (lower.contains('tomorrow')) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return {
        'day': tomorrow.day.toString().padLeft(2, '0'),
        'month': _monthNames[tomorrow.month - 1],
      };
    }
    if (lower.contains('today')) {
      final today = DateTime.now();
      return {
        'day': today.day.toString().padLeft(2, '0'),
        'month': _monthNames[today.month - 1],
      };
    }

    final monthRegex = RegExp(
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)',
      caseSensitive: false,
    );
    final dayRegex = RegExp(r'\b([0-2]?[0-9]|3[01])(?:st|nd|rd|th)?\b');

    final monthMatch = monthRegex.firstMatch(event.timeDate);
    if (monthMatch != null) {
      final monthStr = monthMatch.group(1)!.substring(0, 3).toUpperCase();
      final dayMatch = dayRegex.firstMatch(event.timeDate);
      final dayStr = dayMatch != null
          ? dayMatch.group(1)!.padLeft(2, '0')
          : event.createdAt.day.toString().padLeft(2, '0');
      return {'day': dayStr, 'month': monthStr};
    }

    return {
      'day': event.createdAt.day.toString().padLeft(2, '0'),
      'month': _monthNames[event.createdAt.month - 1],
    };
  }

  String _extractCategory(EventModel event) {
    final text = '${event.name} ${event.description}'.toLowerCase();
    if (text.contains('hackathon') ||
        text.contains('coding') ||
        text.contains('tech') ||
        text.contains('code') ||
        text.contains('developer') ||
        text.contains('ai') ||
        text.contains('ml') ||
        text.contains('web') ||
        text.contains('app') ||
        text.contains('cyber') ||
        text.contains('robot') ||
        text.contains('cloud') ||
        text.contains('software')) {
      return 'Tech';
    }
    if (text.contains('dance') ||
        text.contains('music') ||
        text.contains('cultural') ||
        text.contains('art') ||
        text.contains('fest') ||
        text.contains('drama') ||
        text.contains('theatre') ||
        text.contains('singing')) {
      return 'Cultural';
    }
    if (text.contains('cricket') ||
        text.contains('football') ||
        text.contains('sports') ||
        text.contains('badminton') ||
        text.contains('chess') ||
        text.contains('athletics') ||
        text.contains('tournament')) {
      return 'Sports';
    }
    if (text.contains('workshop') ||
        text.contains('bootcamp') ||
        text.contains('hands-on') ||
        text.contains('masterclass')) {
      return 'Workshop';
    }
    if (text.contains('seminar') ||
        text.contains('webinar') ||
        text.contains('conference') ||
        text.contains('talk') ||
        text.contains('lecture')) {
      return 'Seminar';
    }
    if (text.contains('gaming') ||
        text.contains('esports') ||
        text.contains('bgmi') ||
        text.contains('valorant')) {
      return 'Gaming';
    }
    return 'Tech';
  }

  String _extractTimingBadge(EventModel event) {
    final lower = event.timeDate.toLowerCase();
    if (lower.contains('tomorrow')) {
      return 'Starts tomorrow';
    }
    if (lower.contains('today')) {
      return 'Live today';
    }
    if (event.timeDate.trim().isNotEmpty) {
      final parts = event.timeDate.split(',');
      if (parts.length > 1 && parts.last.trim().isNotEmpty) {
        return 'Starts ${parts.last.trim()}';
      }
    }
    return 'Starts tomorrow';
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 200),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 64, color: Color(0xFF64748B)),
              SizedBox(height: 16),
              Text(
                'No events scheduled yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              SizedBox(height: 8),
              Text(
                'Check back later for upcoming campus events!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B98AD)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventModel event, {bool isWeb = false}) {
    final eventDate = _extractEventDate(event);
    final category = _extractCategory(event);
    final timingBadge = _extractTimingBadge(event);
    final isBookmarked = _bookmarkedEventIds.contains(event.id);

    return Container(
      margin: isWeb ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF141927),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Section
          SizedBox(
            height: isWeb ? 150 : 180,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (event.pictureUrl != null && event.pictureUrl!.isNotEmpty) ...[
                  Image.network(
                    event.pictureUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3548BF), Color(0xFF263595)],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF263595).withValues(alpha: 0.4),
                          const Color(0xFF141927).withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3548BF), Color(0xFF263595)],
                      ),
                    ),
                  ),
                  // Overlapping circles creating the curved wave graphics
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -65,
                    right: 15,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A2670).withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],

                // Top-Left Date Badge
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    width: 52,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          eventDate['day']!,
                          style: const TextStyle(
                            color: Color(0xFF1B2559),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          eventDate['month']!,
                          style: const TextStyle(
                            color: Color(0xFF1B2559),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-Right Category Pill
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Color(0xFF1B2559),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Bottom-Left Urgency/Timing Label
                Positioned(
                  bottom: 14,
                  left: 14,
                  child: Text(
                    timingBadge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lower Card Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.organizerAccessEnabled == true) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.shield_outlined, size: 20, color: Color(0xFFF59E0B)),
                        tooltip: 'Organizer Desk Login',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => OrganizerLoginDialog.show(
                          context,
                          initialEventCode: event.eventCode ?? event.id,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 17, color: Color(0xFF8B98AD)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.place.isNotEmpty ? event.place : 'Campus Venue',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 17, color: Color(0xFF8B98AD)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.timeDate.isNotEmpty ? event.timeDate : 'Time to be announced',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  event.description.isNotEmpty
                      ? event.description
                      : 'Add a short event description here.',
                  style: const TextStyle(
                    color: Color(0xFF8B98AD),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: isWeb ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _registeringEventIds.contains(event.id)
                              ? null
                              : () => _handleRegistration(event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4361EE),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _registeringEventIds.contains(event.id)
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  event.registrationMode != 'internal'
                                      ? 'Register Now'
                                      : event.isRegistered
                                          ? 'Registered · Cancel'
                                          : 'Register Now',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bookmark button
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isBookmarked ? const Color(0xFF273462) : const Color(0xFF1B2236),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isBookmarked
                              ? const Color(0xFF4361EE)
                              : Colors.white.withValues(alpha: 0.12),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _toggleBookmark(event),
                          child: Center(
                            child: Icon(
                              isBookmarked
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
                              color: isBookmarked ? const Color(0xFF4361EE) : Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Share button
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2236),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _copyEventLink(event),
                          child: const Center(
                            child: Icon(
                              Icons.share_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (event.registrationMode == 'internal' && event.registrationCount > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text(
                        '${event.registrationCount} ${event.registrationCount == 1 ? 'attendee' : 'attendees'} registered',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B98AD)),
                      ),
                      const Spacer(),
                      if (event.isRegistered)
                        const Text(
                          'You’re in ✓',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF34D399),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleEventView(EventModel event) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() => _focusedEvent = null);
                  if (kIsWeb) {
                    context.go('/events');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF818CF8)),
                      const SizedBox(width: 6),
                      Text(
                        'View All Campus Events (${_events.length})',
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildEventCard(event, isWeb: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _events.length + 1,
      itemBuilder: (context, index) {
        if (index == _events.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'More events coming soon',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        }
        return _buildEventCard(_events[index]);
      },
    );
  }

  Widget _buildWebGrid(double screenWidth) {
    final int crossAxisCount = screenWidth >= 1050 ? 3 : 2;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _events.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  mainAxisExtent: 440,
                ),
                itemBuilder: (context, index) =>
                    _buildEventCard(_events[index], isWeb: true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'More events coming soon',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101C),
      appBar: AppBar(
        title: Text(
          _focusedEvent != null ? 'Event Details' : 'Campus Events',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: const Color(0xFF2E3E96),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _focusedEvent != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'All Events',
                onPressed: () {
                  setState(() => _focusedEvent = null);
                  if (kIsWeb) {
                    context.go('/events');
                  }
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to Home',
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.home);
                  }
                },
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Organizer Desk Login',
            onPressed: () => OrganizerLoginDialog.show(
              context,
              initialEventCode: _focusedEvent?.eventCode ?? _focusedEvent?.id,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4361EE)))
          : _focusedEvent != null
              ? _buildSingleEventView(_focusedEvent!)
              : RefreshIndicator(
                  color: const Color(0xFF4361EE),
                  backgroundColor: const Color(0xFF141927),
                  onRefresh: _fetchEvents,
                  child: _events.isEmpty
                      ? _buildEmptyState()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWeb = constraints.maxWidth >= _webBreakpoint;
                            return isWeb
                                ? _buildWebGrid(constraints.maxWidth)
                                : _buildMobileList();
                          },
                        ),
                ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/models/event_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import 'package:timeago/timeago.dart' as timeago;
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

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 200),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No events scheduled yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Check back later for upcoming campus events!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventModel event, {bool isWeb = false}) {
    return Card(
      margin: isWeb ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.pictureUrl != null && event.pictureUrl!.isNotEmpty)
            Image.network(
              event.pictureUrl!,
              height: isWeb ? 130 : 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                height: isWeb ? 130 : 180,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
              ),
            )
          else
            Container(
              height: isWeb ? 110 : 120,
              width: double.infinity,
              color: Colors.indigo.shade100,
              child: Center(
                child: Icon(Icons.event, size: 40, color: Colors.indigo.shade400),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.organizerAccessEnabled == true) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFF59E0B)),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.place,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.timeDate,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  maxLines: isWeb ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.registrationMode == 'internal') ...[
                  const SizedBox(height: 9),
                  Row(children: [
                    Icon(Icons.people_alt_outlined, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 5),
                    Text(
                      '${event.registrationCount} ${event.registrationCount == 1 ? 'attendee' : 'attendees'} registered',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const Spacer(),
                    if (event.isRegistered)
                      const Text('You’re in ✓', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.teal)),
                  ]),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _registeringEventIds.contains(event.id) ? null : () => _handleRegistration(event),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: event.registrationMode == 'internal' ? Colors.teal.shade700 : Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _registeringEventIds.contains(event.id)
                            ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                event.registrationMode != 'internal'
                                    ? 'Register Now'
                                    : event.isRegistered
                                        ? 'Registered · Cancel'
                                        : 'Register on CampusSetu',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _copyEventLink(event),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo.shade400,
                        side: BorderSide(color: Colors.indigo.shade300.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Added ${timeago.format(event.createdAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
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
                      const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        'View All Campus Events (${_events.length})',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
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
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (context, index) => _buildEventCard(_events[index]),
    );
  }

  Widget _buildWebGrid(double screenWidth) {
    final int crossAxisCount = screenWidth >= 1050 ? 3 : 2;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            itemCount: _events.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 380,
            ),
            itemBuilder: (context, index) =>
                _buildEventCard(_events[index], isWeb: true),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _focusedEvent != null ? 'Event Details' : 'Campus Events',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
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
            icon: const Icon(Icons.notifications_outlined),
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
          ? const Center(child: CircularProgressIndicator())
          : _focusedEvent != null
              ? _buildSingleEventView(_focusedEvent!)
              : RefreshIndicator(
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


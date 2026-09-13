import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/event_model.dart';
import '../../core/services/api_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<EventModel> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final rawEvents = await ApiService().getEvents();
      setState(() {
        _events = rawEvents.map((e) => EventModel.fromJson(e)).toList();
      });
    } catch (e) {
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
  
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Events', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchEvents,
            child: _events.isEmpty
                ? ListView(
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
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event.pictureUrl != null && event.pictureUrl!.isNotEmpty)
                              Image.network(
                                event.pictureUrl!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  height: 180,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                ),
                              )
                            else
                              Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.indigo.shade100,
                                child: Center(
                                  child: Icon(Icons.event, size: 50, color: Colors.indigo.shade400),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.name,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(event.place, style: TextStyle(color: Colors.grey.shade700))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(event.timeDate, style: TextStyle(color: Colors.grey.shade700))),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    event.description,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _launchUrl(event.registrationLink),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text('Register Now'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Added ${timeago.format(event.createdAt)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:campussetu/core/models/travel_model.dart';
import 'package:campussetu/core/services/api_service.dart';
import 'package:campussetu/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  List<TravelModel> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    try {
      final api = ApiService();
      final data = await api.getTravelRides();
      if (mounted) {
        setState(() {
          _rides = data.map((e) => TravelModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching travel rides: $e');
    }
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.pedal_bike;
      case 'scooty':
        return Icons.moped;
      default:
        return Icons.directions_car;
    }
  }

  Future<void> _openWhatsApp(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Helping Travel'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push('/travel/add');
          if (result == true) {
            setState(() => _isLoading = true);
            _fetchRides();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
              ? const Center(child: Text('No travel rides available right now.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rides.length,
                  itemBuilder: (context, index) {
                    final ride = _rides[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: ride.avatar != null
                                      ? NetworkImage(ride.avatar!)
                                      : null,
                                  child: ride.avatar == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ride.userName ?? 'Unknown User',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        ride.college ?? 'Unknown College',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getVehicleIcon(ride.vehicleType),
                                    color: AppColors.primary,
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 20, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Going to: ${ride.destination}',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 20, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ride.timeDate,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openWhatsApp(ride.contactNumber),
                                icon: const Icon(Icons.chat),
                                label: const Text('Chat'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366), // WhatsApp green
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:campussetu/core/models/travel_model.dart';
import 'package:campussetu/core/services/api_service.dart';
import 'package:campussetu/core/router/app_router.dart';
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
  String _selectedFilter = 'all';

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

  List<TravelModel> get _filteredRides {
    if (_selectedFilter == 'all') return _rides;
    return _rides.where((r) => r.vehicleType.toLowerCase().contains(_selectedFilter)).toList();
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'PA';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  IconData _getVehicleIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('bike')) {
      return Icons.two_wheeler_rounded;
    } else if (t.contains('scooty') || t.contains('moped')) {
      return Icons.moped_rounded;
    } else {
      return Icons.directions_car_rounded;
    }
  }

  String _getVehicleLabel(String type) {
    final t = type.toLowerCase();
    if (t.contains('bike')) {
      return 'Bike';
    } else if (t.contains('scooty')) {
      return 'Scooty';
    } else {
      return 'Car';
    }
  }

  String _getSeats(TravelModel ride) {
    final v = ride.vehicleType.toLowerCase();
    if (v.contains('bike') || v.contains('scooty') || v.contains('moped')) {
      return '1 seat';
    }
    return '2 seats';
  }

  Map<String, String> _extractRoute(TravelModel ride) {
    final dest = ride.destination.trim();
    if (dest.contains(' to ') || dest.contains(' To ') || dest.contains(' -> ')) {
      final delimiter = dest.contains(' -> ') ? ' -> ' : (dest.contains(' to ') ? ' to ' : ' To ');
      final parts = dest.split(delimiter);
      if (parts.length >= 2 && parts[0].trim().isNotEmpty && parts[1].trim().isNotEmpty) {
        String from = parts[0].trim();
        if (from.toLowerCase().startsWith('from ')) {
          from = from.substring(5).trim();
        }
        return {
          'from': from,
          'to': parts[1].trim(),
        };
      }
    }

    final from = (ride.college != null && ride.college!.trim().isNotEmpty)
        ? ride.college!.trim()
        : 'Jain University';
    return {
      'from': from,
      'to': dest.isNotEmpty ? dest : 'Zolo Pele',
    };
  }

  Future<void> _requestRide(TravelModel ride) async {
    final route = _extractRoute(ride);
    final msg = Uri.encodeComponent(
      'Hi ${ride.userName ?? 'there'}! I saw your ride on CampusSetu (${route['from']} -> ${route['to']}) for ${ride.timeDate}. Can I join?',
    );
    final cleanNumber = ride.contactNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final whatsappUrl = Uri.parse('https://wa.me/$cleanNumber?text=$msg');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      final telUrl = Uri.parse('tel:$cleanNumber');
      if (await canLaunchUrl(telUrl)) {
        await launchUrl(telUrl);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact rider at: ${ride.contactNumber}'),
            backgroundColor: const Color(0xFF1E2438),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final telUrl = Uri.parse('tel:$cleanNumber');
      if (await canLaunchUrl(telUrl)) {
        await launchUrl(telUrl);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact number: $number'),
            backgroundColor: const Color(0xFF1E2438),
          ),
        );
      }
    }
  }

  void _showFilterModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF141927),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Filter by Vehicle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _filterTile('All Vehicles', 'all', Icons.commute_rounded),
            _filterTile('Bikes Only', 'bike', Icons.two_wheeler_rounded),
            _filterTile('Cars Only', 'car', Icons.directions_car_rounded),
            _filterTile('Scooties Only', 'scooty', Icons.moped_rounded),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _filterTile(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF14B8C7) : const Color(0xFF8B98AD),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF14B8C7) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: Color(0xFF14B8C7))
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        setState(() => _selectedFilter = value);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedRides = _filteredRides;

    return Scaffold(
      backgroundColor: const Color(0xFF0C101C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C101C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: const Text(
          'Helping Travel',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            tooltip: 'Filter rides',
            onPressed: _showFilterModal,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF14B8C7),
        foregroundColor: const Color(0xFF0A1C24),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: const Icon(Icons.add_rounded, color: Color(0xFF0A1C24), size: 24),
        label: const Text(
          'Offer a ride',
          style: TextStyle(
            color: Color(0xFF0A1C24),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        onPressed: () async {
          final result = await context.push('/travel/add');
          if (result == true) {
            setState(() => _isLoading = true);
            _fetchRides();
          }
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8C7)))
          : displayedRides.isEmpty
              ? _buildEmptyState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    if (width >= 650) {
                      final cols = width >= 1050 ? 3 : 2;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                            itemCount: displayedRides.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: 18,
                              mainAxisSpacing: 18,
                              mainAxisExtent: 340,
                            ),
                            itemBuilder: (context, index) =>
                                _buildRideCard(displayedRides[index], isWeb: true),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: displayedRides.length,
                      itemBuilder: (context, index) =>
                          _buildRideCard(displayedRides[index]),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF14B8C7).withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                size: 56,
                color: Color(0xFF14B8C7),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No rides available right now',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Heading somewhere? Be the first to offer a ride and help fellow students!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8B98AD),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await context.push('/travel/add');
                if (result == true) {
                  setState(() => _isLoading = true);
                  _fetchRides();
                }
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Offer a ride', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8C7),
                foregroundColor: const Color(0xFF0A1C24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideCard(TravelModel ride, {bool isWeb = false}) {
    final route = _extractRoute(ride);
    final vehicleIcon = _getVehicleIcon(ride.vehicleType);
    final vehicleLabel = _getVehicleLabel(ride.vehicleType);
    final seats = _getSeats(ride);
    final initials = _getInitials(ride.userName);

    return Container(
      margin: isWeb ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141927),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Avatar, Name & College, Vehicle Pill
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF13B5D1),
                  shape: BoxShape.circle,
                  image: (ride.avatar != null && ride.avatar!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(ride.avatar!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (ride.avatar == null || ride.avatar!.isEmpty)
                    ? Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Color(0xFF0A1C24),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.userName != null && ride.userName!.isNotEmpty
                          ? ride.userName!
                          : 'Campus Rider',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ride.college != null && ride.college!.isNotEmpty
                          ? ride.college!
                          : 'Jain University Bangalore',
                      style: const TextStyle(
                        color: Color(0xFF8B98AD),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Vehicle Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E2C38),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF14B8C7).withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      vehicleIcon,
                      size: 16,
                      color: const Color(0xFF14B8C7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vehicleLabel,
                      style: const TextStyle(
                        color: Color(0xFF14B8C7),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Route Indicator: Vertical line with From & To
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical Path Indicator
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 14),
                child: Column(
                  children: [
                    // Hollow circle
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF14B8C7),
                          width: 2.5,
                        ),
                      ),
                    ),
                    // Vertical connecting line
                    Container(
                      width: 1.5,
                      height: 28,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: const Color(0xFF2E3E55),
                    ),
                    // Solid location pin / dot
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF14B8C7),
                      ),
                    ),
                  ],
                ),
              ),

              // From & To Labels and Values
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FROM',
                      style: TextStyle(
                        color: Color(0xFF75859B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      route['from']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'TO',
                      style: TextStyle(
                        color: Color(0xFF75859B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      route['to']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Time & Seats Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2438),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: Color(0xFF14B8C7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ride.timeDate.isNotEmpty ? ride.timeDate : 'Today, 4:30 PM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2438),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Center(
                  child: Text(
                    seats,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Action Buttons: Request Ride + Chat Button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _requestRide(ride),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8C7),
                      foregroundColor: const Color(0xFF0A1C24),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Request Ride',
                      style: TextStyle(
                        color: Color(0xFF0A1C24),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2438),
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
                    onTap: () => _openWhatsApp(ride.contactNumber),
                    child: const Center(
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

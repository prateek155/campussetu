import 'package:flutter/material.dart';
import 'package:campussetu/core/services/api_service.dart';
import 'package:campussetu/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

class AddTravelScreen extends StatefulWidget {
  const AddTravelScreen({super.key});

  @override
  State<AddTravelScreen> createState() => _AddTravelScreenState();
}

class _AddTravelScreenState extends State<AddTravelScreen> {
  final _formKey = GlobalKey<FormState>();
  String _vehicleType = 'car';
  final _destinationController = TextEditingController();
  final _timeController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _destinationController.dispose();
    _timeController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      await api.createTravelRide({
        'vehicle_type': _vehicleType,
        'destination': _destinationController.text.trim(),
        'time_date': _timeController.text.trim(),
        'contact_number': _contactController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Travel ride posted successfully!')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post travel ride: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a Ride'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vehicle Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'car', label: Text('Car'), icon: Icon(Icons.directions_car)),
                  ButtonSegment(value: 'bike', label: Text('Bike'), icon: Icon(Icons.pedal_bike)),
                  ButtonSegment(value: 'scooty', label: Text('Scooty'), icon: Icon(Icons.moped)),
                ],
                selected: {_vehicleType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _vehicleType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: 'Destination / Going To',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Time & Date (e.g., Today 5:00 PM)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number (with country code)',
                  hintText: '+91 9876543210',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Post Ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:campussetu/core/services/api_service.dart';
import 'package:go_router/go_router.dart';

class AddTravelScreen extends StatefulWidget {
  const AddTravelScreen({super.key});

  @override
  State<AddTravelScreen> createState() => _AddTravelScreenState();
}

class _AddTravelScreenState extends State<AddTravelScreen> {
  final _formKey = GlobalKey<FormState>();
  String _vehicleType = 'bike';
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
          const SnackBar(
            content: Text('Travel ride posted successfully!'),
            backgroundColor: Color(0xFF141927),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post travel ride: $e'),
            backgroundColor: const Color(0xFF141927),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildVehicleOption(String type, String label, IconData icon) {
    final isSelected = _vehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0E2C38) : const Color(0xFF141927),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF14B8C7) : Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF14B8C7) : const Color(0xFF8B98AD),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF14B8C7) : const Color(0xFF8B98AD),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF8B98AD), fontSize: 13.5),
      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF14B8C7), size: 19),
      filled: true,
      fillColor: const Color(0xFF141927),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF14B8C7), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C101C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Offer a Ride',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Vehicle Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildVehicleOption('bike', 'Bike', Icons.two_wheeler_rounded),
                  const SizedBox(width: 10),
                  _buildVehicleOption('scooty', 'Scooty', Icons.moped_rounded),
                  const SizedBox(width: 10),
                  _buildVehicleOption('car', 'Car', Icons.directions_car_rounded),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _destinationController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDecoration(
                  label: 'Destination / Route',
                  hint: 'e.g., Jain University to Zolo Pele',
                  icon: Icons.location_on_outlined,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter destination' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timeController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDecoration(
                  label: 'Time & Date',
                  hint: 'e.g., Today, 4:30 PM',
                  icon: Icons.access_time_rounded,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter time' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDecoration(
                  label: 'WhatsApp / Phone Number',
                  hint: '+91 9876543210',
                  icon: Icons.phone_outlined,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter phone number' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8C7),
                    foregroundColor: const Color(0xFF0A1C24),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A1C24)),
                        )
                      : const Text(
                          'Post Ride',
                          style: TextStyle(
                            color: Color(0xFF0A1C24),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
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
}

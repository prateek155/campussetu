// lib/features/enterprise/screens/enterprise_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/enterprise_providers.dart';
import '../widgets/pos_pill_switch.dart';

class EnterpriseSettingsScreen extends ConsumerStatefulWidget {
  const EnterpriseSettingsScreen({super.key});

  @override
  ConsumerState<EnterpriseSettingsScreen> createState() => _EnterpriseSettingsScreenState();
}

class _EnterpriseSettingsScreenState extends ConsumerState<EnterpriseSettingsScreen> {
  final _emailCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _restaurantCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _tablesCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();

  String _theme = 'Auto';
  bool _notifications = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(enterpriseProfileProvider);
    _populateFields(profile);
  }

  void _populateFields(dynamic profile) {
    final curUser = FirebaseAuth.instance.currentUser;
    _emailCtrl.text = profile.email.isNotEmpty ? profile.email : (curUser?.email ?? '');
    _ownerCtrl.text = profile.ownerName;
    _restaurantCtrl.text = profile.restaurantName;
    _mobileCtrl.text = profile.mobileNumber;
    _cityCtrl.text = profile.city;
    _stateCtrl.text = profile.state;
    _upiCtrl.text = profile.upiId;
    _gstCtrl.text = profile.gstPercent.toStringAsFixed(0);
    _tablesCtrl.text = profile.tablesCount.toString();
    _prefixCtrl.text = profile.billPrefix;
    _theme = profile.theme;
    _notifications = profile.notificationsEnabled;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _ownerCtrl.dispose();
    _restaurantCtrl.dispose();
    _mobileCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _upiCtrl.dispose();
    _gstCtrl.dispose();
    _tablesCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final curProfile = ref.read(enterpriseProfileProvider);

    final updated = curProfile.copyWith(
      email: _emailCtrl.text.trim(),
      ownerName: _ownerCtrl.text.trim(),
      restaurantName: _restaurantCtrl.text.trim().isEmpty ? 'Naya restaurant' : _restaurantCtrl.text.trim(),
      mobileNumber: _mobileCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      upiId: _upiCtrl.text.trim(),
      gstPercent: double.tryParse(_gstCtrl.text.trim()) ?? 5.0,
      tablesCount: int.tryParse(_tablesCtrl.text.trim()) ?? 8,
      billPrefix: _prefixCtrl.text.trim().isEmpty ? 'POS' : _prefixCtrl.text.trim(),
      theme: _theme,
      notificationsEnabled: _notifications,
    );

    await ref.read(enterpriseProfileProvider.notifier).updateProfile(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings save ho gayi hain!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _showSetPasswordDialog() {
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool settingPass = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A2236),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Set Account Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Apne Google account ke sath password set karein, jisse aap baad me email aur password se bhi login kar sakein.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'New Password (min 6 chars)',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF131929),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF131929),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                onPressed: settingPass
                    ? null
                    : () async {
                        final p1 = newPassCtrl.text.trim();
                        final p2 = confirmCtrl.text.trim();
                        if (p1.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password kam se kam 6 characters ka hona chahiye')),
                          );
                          return;
                        }
                        if (p1 != p2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords match nahi kar rahe hain')),
                          );
                          return;
                        }
                        setDialogState(() => settingPass = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.updatePassword(p1);
                            if (mounted) {
                              nav.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Password successfully set ho gaya! Ab aap email-password se bhi login kar sakte hain.'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          setDialogState(() => settingPass = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                child: settingPass ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Set Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(enterpriseProfileProvider);
    final modules = profile.enabledModules;
    final isGoogleUser = FirebaseAuth.instance.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          return Flex(
            direction: isWide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── LEFT COLUMN: PROFILE ───────────────────────
              Expanded(
                flex: isWide ? 6 : 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171E30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF26334D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Warning / Info banner (from screenshot)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF382711),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF7A4E12)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Owner aur restaurant ka naam bharke save karo, phir billing shuru karo.',
                                style: TextStyle(color: Color(0xFFFCD34D), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email & Owner Name row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput('Email (login)', _emailCtrl, readOnly: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInput('Owner ka naam', _ownerCtrl, hint: 'e.g. Ramesh Kumar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Restaurant Name & Mobile row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput('Restaurant ka naam', _restaurantCtrl, hint: 'e.g. Campus Cafe'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInput('Mobile number', _mobileCtrl, hint: '9876543210', keyboardType: TextInputType.phone),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // City & State row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput('City', _cityCtrl, hint: 'e.g. Jaipur'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInput('State', _stateCtrl, hint: 'e.g. Rajasthan'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // UPI ID & GST % row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput('UPI ID (name@bank)', _upiCtrl, hint: 'merchant@okaxis'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInput('GST %', _gstCtrl, keyboardType: TextInputType.number),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tables count & Bill prefix
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput('Tables ki sankhya', _tablesCtrl, keyboardType: TextInputType.number),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInput('Bill prefix', _prefixCtrl, hint: 'POS'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Theme Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Theme', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1422),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF26334D)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _theme,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF171E30),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                items: const [
                                  DropdownMenuItem(value: 'Auto', child: Text('Auto')),
                                  DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                                  DropdownMenuItem(value: 'Light', child: Text('Light')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _theme = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Notifications Switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                          PosPillSwitch(
                            value: _notifications,
                            onChanged: (v) => setState(() => _notifications = v),
                          ),
                        ],
                      ),

                      if (isGoogleUser) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1422),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF26334D)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.key_rounded, color: Color(0xFF10B981), size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Google Login account ke liye password set karein.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: _showSetPasswordDialog,
                                child: const Text('Set Password', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Save Button
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Settings save karo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),

              if (isWide) const SizedBox(width: 24) else const SizedBox(height: 24),

              // ── RIGHT COLUMN: FEATURES ON / OFF ───────────
              Expanded(
                flex: isWide ? 4 : 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171E30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF26334D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Features on/off',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'OFF karne par feature menu se hat jata hai aur uska data load nahi hota. Billing aur Food Menu hamesha ON rehte hain.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 24),

                      _buildFeatureToggle(
                        title: 'Inventory',
                        subtitle: 'Stock add/edit, kam stock alert',
                        value: modules['inventory'] ?? true,
                        onChanged: (val) {
                          ref.read(enterpriseProfileProvider.notifier).toggleModule('inventory', val);
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildFeatureToggle(
                        title: 'Udhaar / CRM',
                        subtitle: 'Kisko kitna udhaar, kab diya, kab mila',
                        value: modules['udhaar'] ?? true,
                        onChanged: (val) {
                          ref.read(enterpriseProfileProvider.notifier).toggleModule('udhaar', val);
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildFeatureToggle(
                        title: 'Staff',
                        subtitle: 'Salary, attendance, advance',
                        value: modules['staff'] ?? true,
                        onChanged: (val) {
                          ref.read(enterpriseProfileProvider.notifier).toggleModule('staff', val);
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildFeatureToggle(
                        title: 'Redeem',
                        subtitle: 'CampusSetu student offer codes',
                        value: modules['redeem'] ?? true,
                        onChanged: (val) {
                          ref.read(enterpriseProfileProvider.notifier).toggleModule('redeem', val);
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildFeatureToggle(
                        title: 'Reports',
                        subtitle: 'Sale, cash vs UPI, top items',
                        value: modules['reports'] ?? true,
                        onChanged: (val) {
                          ref.read(enterpriseProfileProvider.notifier).toggleModule('reports', val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboardType, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF0F1422),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF26334D))),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ),
        PosPillSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// lib/features/enterprise/screens/enterprise_pos_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import '../providers/enterprise_providers.dart';
import '../services/enterprise_storage_service.dart';
import 'enterprise_billing_screen.dart';
import 'enterprise_food_menu_screen.dart';
import 'enterprise_inventory_screen.dart';
import 'enterprise_udhaar_screen.dart';
import 'enterprise_staff_screen.dart';
import 'enterprise_redeem_screen.dart';
import 'enterprise_reports_screen.dart';
import 'enterprise_settings_screen.dart';

class EnterprisePosShell extends ConsumerStatefulWidget {
  const EnterprisePosShell({super.key});

  @override
  ConsumerState<EnterprisePosShell> createState() => _EnterprisePosShellState();
}

class _EnterprisePosShellState extends ConsumerState<EnterprisePosShell> {
  String _activeTab = 'Billing';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(enterpriseProfileProvider);
      if (!profile.isProfileComplete) {
        setState(() => _activeTab = 'Settings');
      }
    });
  }

  Future<void> _logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/ent-login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(enterpriseProfileProvider);
    final modules = profile.enabledModules;
    final networkMode = ref.watch(enterpriseNetworkModeProvider);
    final syncStatus = ref.watch(enterpriseSyncStatusProvider);

    // Calculate loaded modules count out of 5 toggleable modules
    final enabledCount = modules.values.where((v) => v).length;

    // Available tabs based on features toggled in settings
    final navItems = <Map<String, dynamic>>[
      {'id': 'Billing', 'label': 'Billing'},
      {'id': 'Food Menu', 'label': 'Food Menu'},
      if (modules['inventory'] ?? true) {'id': 'Inventory', 'label': 'Inventory'},
      if (modules['udhaar'] ?? true) {'id': 'Udhaar (CRM)', 'label': 'Udhaar (CRM)'},
      if (modules['staff'] ?? true) {'id': 'Staff', 'label': 'Staff'},
      if (modules['redeem'] ?? true) {'id': 'Redeem', 'label': 'Redeem'},
      if (modules['reports'] ?? true) {'id': 'Reports', 'label': 'Reports'},
      {'id': 'Settings', 'label': 'Settings'},
    ];

    // If active tab was disabled, fallback to Billing
    if (!navItems.any((item) => item['id'] == _activeTab)) {
      _activeTab = 'Billing';
    }

    Widget contentBody;
    switch (_activeTab) {
      case 'Billing':
        contentBody = const EnterpriseBillingScreen();
        break;
      case 'Food Menu':
        contentBody = const EnterpriseFoodMenuScreen();
        break;
      case 'Inventory':
        contentBody = const EnterpriseInventoryScreen();
        break;
      case 'Udhaar (CRM)':
        contentBody = const EnterpriseUdhaarScreen();
        break;
      case 'Staff':
        contentBody = const EnterpriseStaffScreen();
        break;
      case 'Redeem':
        contentBody = const EnterpriseRedeemScreen();
        break;
      case 'Reports':
        contentBody = const EnterpriseReportsScreen();
        break;
      case 'Settings':
      default:
        contentBody = const EnterpriseSettingsScreen();
        break;
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    Widget buildDrawer() {
      return Drawer(
        backgroundColor: const Color(0xFF0F1422),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/enterprise_icon.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981), size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CampusSetu POS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'serif',
                                ),
                              ),
                              Text(
                                profile.restaurantName.isNotEmpty ? profile.restaurantName : 'My Restaurant',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$enabledCount/5 active',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: syncStatus.contains('Offline')
                                ? const Color(0xFF78350F)
                                : (syncStatus.contains('Syncing') ? const Color(0xFF1E3A8A) : const Color(0xFF064E3B)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            syncStatus,
                            style: TextStyle(
                              color: syncStatus.contains('Offline')
                                  ? const Color(0xFFFBBF24)
                                  : (syncStatus.contains('Syncing') ? const Color(0xFF60A5FA) : const Color(0xFF10B981)),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Nav items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  children: navItems.map((item) {
                    final isSelected = _activeTab == item['id'];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0B2D26) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item['label'],
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF10B981) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          setState(() => _activeTab = item['id']);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Drawer Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Demo network', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        DropdownButton<DemoNetworkMode>(
                          value: networkMode,
                          dropdownColor: const Color(0xFF171E30),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          underline: const SizedBox(),
                          items: DemoNetworkMode.values.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m.label));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(enterpriseNetworkModeProvider.notifier).setMode(val);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                      label: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3B1818)),
                        backgroundColor: const Color(0xFF1F1215),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1422),
        drawer: buildDrawer(),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F1422),
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/enterprise_icon.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981), size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _activeTab,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: syncStatus.contains('Offline')
                    ? const Color(0xFF78350F)
                    : (syncStatus.contains('Syncing') ? const Color(0xFF1E3A8A) : const Color(0xFF064E3B)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                syncStatus.contains('Offline') ? 'Offline' : (syncStatus.contains('Syncing') ? 'Syncing' : 'Online'),
                style: TextStyle(
                  color: syncStatus.contains('Offline')
                      ? const Color(0xFFFBBF24)
                      : (syncStatus.contains('Syncing') ? const Color(0xFF60A5FA) : const Color(0xFF10B981)),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: contentBody,
      );
    }

    // Desktop / Wide Layout (Matches Image 1, 2, 3)
    return Scaffold(
      backgroundColor: const Color(0xFF0F1422),
      body: Column(
        children: [
          // ── TOP HEADER BAR ─────────────────────────────────
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1422),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                // Enterprise App Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/enterprise_icon.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                ),
                const SizedBox(width: 10),

                // Brand Title
                const Text(
                  'CampusSetu POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(width: 32),

                // Restaurant Name
                Text(
                  profile.restaurantName.isNotEmpty ? profile.restaurantName : 'My Restaurant',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 24),

                // Modules Loaded Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$enabledCount/5 modules loaded',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),

                // Sync Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: syncStatus.contains('Offline')
                        ? const Color(0xFF78350F)
                        : (syncStatus.contains('Syncing') ? const Color(0xFF1E3A8A) : const Color(0xFF064E3B)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    syncStatus,
                    style: TextStyle(
                      color: syncStatus.contains('Offline')
                          ? const Color(0xFFFBBF24)
                          : (syncStatus.contains('Syncing') ? const Color(0xFF60A5FA) : const Color(0xFF10B981)),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const Spacer(),

                // Demo Network Dropdown
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Demo network', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171E30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF26334D)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<DemoNetworkMode>(
                          value: networkMode,
                          dropdownColor: const Color(0xFF171E30),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: DemoNetworkMode.values.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m.label));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(enterpriseNetworkModeProvider.notifier).setMode(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Logout Button
                OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF26334D)),
                    backgroundColor: const Color(0xFF171E30),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),

          // ── MAIN BODY: SIDEBAR + CONTENT ───────────────────
          Expanded(
            child: Row(
              children: [
                // Left Sidebar
                Container(
                  width: 180,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F1422),
                    border: Border(right: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: ListView(
                    children: navItems.map((item) {
                      final isSelected = _activeTab == item['id'];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0B2D26) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            item['label'],
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF10B981) : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () {
                            setState(() => _activeTab = item['id']);
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Content View
                Expanded(
                  child: contentBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

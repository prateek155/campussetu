import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/router/app_router.dart';

class ManageNetworkScreen extends StatefulWidget {
  const ManageNetworkScreen({super.key});
  @override
  State<ManageNetworkScreen> createState() => _ManageNetworkScreenState();
}

class _ManageNetworkScreenState extends State<ManageNetworkScreen> {
  int _connectionsCount = 0;
  @override
  void initState() { super.initState(); _loadCount(); }
  Future<void> _loadCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken(true);
        if (token != null) ApiService().setToken(token);
      }
      final list = await ApiService().getMyConnections();
      if (mounted) setState(() => _connectionsCount = list.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink), onPressed: () => context.pop()),
      title: Text('Manage my network', style: AppTypography.soraHeading3(color: AppColors.ink)),
      iconTheme: IconThemeData(color: AppColors.ink),
    ),
    body: ListView(
      children: [
        _tile(Icons.people_rounded, 'Connections', '$_connectionsCount', onTap: () async {
          await context.push(AppRoutes.connections);
          if (mounted) _loadCount();
        }),
        _tile(Icons.person_rounded, 'Following & followers', null, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
        _tile(Icons.groups_rounded, 'Groups', null, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
        _tile(Icons.calendar_month_rounded, 'Events', null, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
        _tile(Icons.business_rounded, 'Pages', null, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
        _tile(Icons.newspaper_rounded, 'Newsletters', null, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
      ],
    ),
  );

  Widget _tile(IconData icon, String title, String? badge, {VoidCallback? onTap}) {
    final tileColor = AppColors.isDark ? AppColors.darkTile : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: tileColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: AppTypography.interButton(color: AppColors.ink, size: 15))),
          if (badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF0A66C2), borderRadius: BorderRadius.circular(12)), child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

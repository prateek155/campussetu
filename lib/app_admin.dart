import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/admin_router.dart';

class CampusSetuAdminApp extends ConsumerWidget {
  const CampusSetuAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: 'CampusSetu Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3FD8F5),
          surface: Color(0xFF141728),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/auth/admin_login_screen.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/add_deal_screen.dart';
import '../../features/admin/add_event_screen.dart';

final _adminAuthStream = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final adminRouterProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(_adminAuthStream);
  final user = authAsync.value;
  final loading = authAsync.isLoading;

  return GoRouter(
    initialLocation: '/admin-login',
    redirect: (context, state) {
      if (loading) return null;
      final onLogin = state.matchedLocation == '/admin-login';
      if (user == null && !onLogin) return '/admin-login';
      if (user != null && onLogin) return '/admin-home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/admin-login',
        builder: (_, __) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin-home',
        builder: (_, __) => const AdminShell(),
      ),
      GoRoute(
        path: '/admin/add-deal',
        builder: (_, __) => const AddDealScreen(),
      ),
      GoRoute(
        path: '/admin/add-event',
        builder: (_, __) => const AddEventScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      body: Center(
        child: Text(
          'Error: ${state.error}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/enterprise/screens/enterprise_auth_screen.dart';
import '../../features/enterprise/screens/enterprise_pos_shell.dart';

final _entAuthStream = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final enterpriseRouterProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(_entAuthStream);
  final user = authAsync.value;
  final loading = authAsync.isLoading;

  return GoRouter(
    initialLocation: '/ent-login',
    redirect: (context, state) {
      if (loading) return null;
      final loggedIn = user != null;
      final isLogin = state.uri.path == '/ent-login';

      if (!loggedIn && !isLogin) return '/ent-login';
      if (loggedIn && isLogin) return '/ent-home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/ent-login',
        builder: (_, __) => const EnterpriseAuthScreen(),
      ),
      GoRoute(
        path: '/ent-home',
        builder: (_, __) => const EnterprisePosShell(),
      ),
    ],
  );
});

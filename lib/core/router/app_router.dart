// lib/core/router/app_router.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/welcome_screen.dart';
import '../../features/auth/auth_confirm_screen.dart';
import '../../features/auth/profile_setup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/connect/connect_screen.dart';
import '../../features/connect/invitation_manager_screen.dart';
import '../../features/connect/manage_network_screen.dart';
import '../../features/connect/connections_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_detail_screen.dart';
import '../../features/tshare/tshare_screen.dart';
import '../../features/jobs/jobs_screen.dart';
import '../../features/helping/helping_task_detail_screen.dart';
import '../../features/points/transfer_points_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/products/product_detail_screen.dart';
import '../../features/resume/resume_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/deals/deals_screen.dart';
import '../../features/flatmates/flatmates_screen.dart';
import '../../features/startup/startup_screen.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/add_deal_screen.dart';
import '../../features/admin/add_event_screen.dart';
import '../../features/events/events_screen.dart';
import '../../features/travel/travel_screen.dart';
import '../../features/travel/add_travel_screen.dart';
import '../../features/legal/privacy_screen.dart';
import '../../features/legal/terms_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/quiz/quiz_list_screen.dart';
import '../../features/quiz/quiz_join_screen.dart';
import '../../features/quiz/quiz_play_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../features/landing/web_landing_screen.dart';
import '../../features/tools/tools_home_screen.dart';
import '../../features/tools/tools_category_screen.dart';
import '../../features/tools/tool_workspace_screen.dart';
import '../shell/main_shell.dart';


final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

class AppRoutes {
  static const welcome = '/';
  static const login = '/login';
  static const authConfirm = '/auth-confirm';
  static const profileSetup = '/profile-setup';
  static const home = '/home';
  static const connect = '/connect';
  static const chat = '/chat';
  static const chatDetail = '/chat/:chatId';
  static const tshare = '/tshare';
  static const jobs = '/jobs';
  static const helping = '/helping';
  static const helpingDetail = '/helping/:taskId';
  static const products = '/products';
  static const productDetail = '/products/:productId';
  static const deals = '/deals';
  static const flatmates = '/flatmates';
  static const resume = '/resume';
  static const profile = '/profile';
  static const startup = '/startup';
  static const admin = '/admin';
  static const adminAddDeal = '/admin/add-deal';
  static const adminUsers = '/admin/users';
  static const adminContent = '/admin/content';
  static const adminFlatmates = '/admin/flatmates';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const notifications = '/notifications';
  static const pointsTransfer = '/points-transfer';
  static const tools = '/tools';
  static const invitations = '/connect/invitations';
  static const manageNetwork = '/connect/manage';
  static const connections = '/connect/connections';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final isLoading = authAsync.isLoading;
  final user = authAsync.value;
  return GoRouter(
    initialLocation: AppRoutes.welcome,
    redirect: (context, state) {
      if (isLoading) return null;
      final loc = state.matchedLocation;
      final isOnAuthRoute = loc == AppRoutes.welcome ||
          loc == AppRoutes.login ||
          loc == AppRoutes.authConfirm ||
          loc == AppRoutes.profileSetup;

      if (user == null && !isOnAuthRoute) return AppRoutes.welcome;
      if (user != null && (loc == AppRoutes.welcome || loc == AppRoutes.login)) return AppRoutes.home;
      return null;
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, __) => kIsWeb ? const WebLandingScreen() : const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.authConfirm,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AuthConfirmScreen(userData: extra ?? {});
        },
      ),
      GoRoute(path: AppRoutes.profileSetup, builder: (_, __) => const ProfileSetupScreen()),

      GoRoute(path: AppRoutes.privacy, builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: AppRoutes.terms, builder: (_, __) => const TermsScreen()),
      GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationsScreen()),

      // Admin shell (with its own 4-tab bottom nav)
      GoRoute(path: AppRoutes.admin, builder: (_, __) => const AdminShell()),
      GoRoute(path: AppRoutes.adminAddDeal, builder: (_, __) => const AddDealScreen()),
      GoRoute(path: '/events/add', builder: (_, __) => const AddEventScreen()),
      GoRoute(path: '/travel', builder: (_, __) => const TravelScreen()),
      GoRoute(path: '/travel/add', builder: (_, __) => const AddTravelScreen()),
      GoRoute(path: AppRoutes.tools, builder: (_, __) => const ToolsHomeScreen()),
      GoRoute(path: '/tools/pdf', builder: (_, __) => const ToolsCategoryScreen(category: ToolCategory.pdf)),
      GoRoute(path: '/tools/image', builder: (_, __) => const ToolsCategoryScreen(category: ToolCategory.image)),
      GoRoute(
        path: '/tools/workspace',
        builder: (_, state) => ToolWorkspaceScreen(toolId: state.uri.queryParameters['toolId'] ?? 'image_convert'),
      ),

      // Main app shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(path: AppRoutes.connect, builder: (_, __) => const ConnectScreen()),
          GoRoute(path: AppRoutes.chat, builder: (_, __) => const ChatListScreen()),
          GoRoute(
            path: AppRoutes.chatDetail,
            builder: (_, state) => ChatDetailScreen(chatId: state.pathParameters['chatId']!),
          ),
          GoRoute(path: AppRoutes.tshare, builder: (_, __) => const TshareScreen()),
          GoRoute(
            path: AppRoutes.jobs,
            builder: (_, state) => JobsScreen(initialTab: state.uri.queryParameters['tab'] == 'helping' ? 1 : 0),
          ),
          GoRoute(path: AppRoutes.helping, builder: (_, __) => const JobsScreen(initialTab: 1)),
          GoRoute(path: AppRoutes.helpingDetail, builder: (_, state) => HelpingTaskDetailScreen(taskId: state.pathParameters['taskId']!)),
          GoRoute(
            path: AppRoutes.pointsTransfer,
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return TransferPointsScreen(toCampusId: extra?['toCampusId']?.toString(), toName: extra?['toName']?.toString());
            },
          ),
          GoRoute(path: AppRoutes.products, builder: (_, __) => const ProductsScreen()),
          GoRoute(path: AppRoutes.deals, builder: (_, __) => const DealsScreen()),
          GoRoute(path: AppRoutes.flatmates, builder: (_, __) => const FlatmatesScreen()),
          GoRoute(
            path: AppRoutes.productDetail,
            builder: (_, state) =>
                ProductDetailScreen(productId: state.pathParameters['productId']!),
          ),
          GoRoute(path: AppRoutes.resume, builder: (_, __) => const ResumeScreen()),
          GoRoute(path: AppRoutes.invitations, builder: (_, __) => const InvitationManagerScreen()),
          GoRoute(path: AppRoutes.manageNetwork, builder: (_, __) => const ManageNetworkScreen()),
          GoRoute(path: AppRoutes.connections, builder: (_, __) => const ConnectionsScreen()),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, state) {
              final userId = state.uri.queryParameters['userId'];
              return ProfileScreen(userId: userId);
            },
          ),
          GoRoute(path: AppRoutes.startup, builder: (_, __) => const StartupScreen()),
        ],
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/admin/add-event',
        builder: (context, state) => const AddEventScreen(),
      ),
      // ── Quiz routes ─────────────────────────────────────────
      GoRoute(path: '/quiz', builder: (_, __) => const QuizListScreen()),
      GoRoute(
        path: '/quiz/join',
        builder: (_, state) => QuizJoinScreen(quizData: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: '/quiz/play',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return QuizPlayScreen(
            quizId: extra['quizId'] ?? '',
            quizTitle: extra['quizTitle'] ?? 'Quiz',
            pin: extra['pin'] ?? '',
          );
        },
      ),

    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFFE9EBEE),
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

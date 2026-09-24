// lib/app_faculty.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/faculty/auth/faculty_login_screen.dart';
import 'features/faculty/auth/faculty_register_screen.dart';
import 'features/faculty/quiz/my_quizzes_screen.dart';
import 'features/faculty/quiz/create_quiz_screen.dart';
import 'features/faculty/quiz/quiz_dashboard_screen.dart';
import 'features/faculty/quiz/quiz_results_screen.dart';
import 'features/faculty/faculty_assessment_screens.dart';
import 'features/faculty/faculty_dashboard_screen.dart';
import 'features/faculty/faculty_portal_shell.dart';
import 'features/faculty/paper_test_builder_screen.dart';
import 'features/tools/tools_home_screen.dart';
import 'features/tools/tools_category_screen.dart';
import 'features/tools/tool_workspace_screen.dart';

final _router = GoRouter(
  initialLocation: '/faculty/login',
  routes: [
    GoRoute(path: '/faculty/login', builder: (_, __) => const FacultyLoginScreen()),
    GoRoute(path: '/faculty/register', builder: (_, __) => const FacultyRegisterScreen()),
    ShellRoute(
      builder: (_, __, child) => FacultyPortalShell(child: child),
      routes: [
        GoRoute(path: '/faculty/dashboard', builder: (_, __) => const FacultyDashboardScreen()),
        GoRoute(path: '/faculty/quizzes', builder: (_, __) => const MyQuizzesScreen()),
        GoRoute(path: '/faculty/quizzes/create', builder: (_, __) => const CreateQuizScreen()),
        GoRoute(path: '/faculty/quizzes/:id/dashboard', builder: (_, state) => QuizDashboardScreen(quizId: state.pathParameters['id']!)),
        GoRoute(path: '/faculty/quizzes/:id/results', builder: (_, state) => QuizResultsScreen(quizId: state.pathParameters['id']!)),
        GoRoute(path: '/faculty/tests', builder: (_, __) => const FacultyTestsScreen()),
        GoRoute(path: '/faculty/tests/create', builder: (_, __) => const PaperTestBuilderScreen()),
        GoRoute(path: '/faculty/tests/:id/edit', builder: (_, state) => PaperTestBuilderScreen(quizId: state.pathParameters['id']!)),
        GoRoute(path: '/faculty/question-bank', builder: (_, __) => const FacultyQuestionBankScreen()),
        GoRoute(path: '/faculty/analytics', builder: (_, __) => const FacultyAnalyticsScreen()),
        GoRoute(path: '/faculty/tools', builder: (_, __) => const ToolsHomeScreen(backRoute: '/faculty/dashboard')),
      ],
    ),
    GoRoute(path: '/tools/pdf', builder: (_, __) => const ToolsCategoryScreen(category: ToolCategory.pdf)),
    GoRoute(path: '/tools/image', builder: (_, __) => const ToolsCategoryScreen(category: ToolCategory.image)),
    GoRoute(path: '/tools/workspace', builder: (_, state) => ToolWorkspaceScreen(toolId: state.uri.queryParameters['toolId'] ?? 'image_convert')),
  ],
);

class CampusSetuFacultyApp extends ConsumerWidget {
  const CampusSetuFacultyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CampuSetu — Faculty Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE28B16), brightness: Brightness.dark).copyWith(
          surface: facultySurface,
          primary: facultyAccent,
          secondary: const Color(0xFF43C7A1),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: facultyBg,
        canvasColor: facultyBg,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: facultyBg,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(color: facultySurface, surfaceTintColor: Colors.transparent),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: facultyAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF101A30),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: facultyBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: facultyBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: facultyAccent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      routerConfig: _router,
    );
  }
}

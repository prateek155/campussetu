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

final _router = GoRouter(
  initialLocation: '/faculty/login',
  routes: [
    GoRoute(path: '/faculty/login', builder: (_, __) => const FacultyLoginScreen()),
    GoRoute(path: '/faculty/register', builder: (_, __) => const FacultyRegisterScreen()),
    GoRoute(path: '/faculty/quizzes', builder: (_, __) => const MyQuizzesScreen()),
    GoRoute(path: '/faculty/quizzes/create', builder: (_, __) => const CreateQuizScreen()),
    GoRoute(
      path: '/faculty/quizzes/:id/dashboard',
      builder: (_, state) => QuizDashboardScreen(quizId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/faculty/quizzes/:id/results',
      builder: (_, state) => QuizResultsScreen(quizId: state.pathParameters['id']!),
    ),
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      routerConfig: _router,
    );
  }
}

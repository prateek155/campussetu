// lib/core/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  // ── Backend API ───────────────────────────────────────────
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://campussetu-lvlq.onrender.com/api/v1';

  static String get apiHealthUrl => dotenv.env['API_HEALTH_URL'] ?? 'https://campussetu-lvlq.onrender.com/health';

  // ── GitHub (update service) ───────────────────────────────
  static String get githubRepo => dotenv.env['GITHUB_REPO'] ?? 'prateek155/campussetu';

  static String get githubApiUrl => 'https://api.github.com/repos/$githubRepo/releases/latest';

  static String get githubRawPubspecUrl => 'https://raw.githubusercontent.com/$githubRepo/main/pubspec.yaml';

  static String get githubApkUrl => 'https://github.com/$githubRepo/releases/latest/download/app-release.apk';

  static String get fallbackVersionUrl => '$apiBaseUrl/version';

  // ── App Environment ───────────────────────────────────────
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'production';

  static bool get isDev => appEnv == 'development';
  static bool get isProd => appEnv == 'production';
}

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Authenticated API client for the separately hosted faculty application.
class FacultyApi {
  static Future<Dio> client() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to continue.');
    final token = await user.getIdToken();
    final baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();
    if (baseUrl.isEmpty) throw StateError('API_BASE_URL is not configured.');
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  static Future<List<Map<String, dynamic>>> list(String path) async {
    final response = await (await client()).get(path);
    final data = response.data;
    if (data is! List) return const [];
    return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final response = await (await client()).get(path);
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    final response = await (await client()).post(path, data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> put(String path, {Object? data}) async {
    final response = await (await client()).put(path, data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }
}

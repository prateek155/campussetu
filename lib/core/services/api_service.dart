import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:campussetu/core/config/app_config.dart';
import 'package:uuid/uuid.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) options.headers['Authorization'] = 'Bearer $_token';
        if (kDebugMode) debugPrint('→ ${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) debugPrint('← ${response.statusCode} ${response.requestOptions.path}');
        handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) debugPrint('✕ API Error: ${error.message}');
        _retryOnce(error, handler);
      },
    ));
  }

  Future<void> _retryOnce(DioException error, ErrorInterceptorHandler handler) async {
    final opts = error.requestOptions;
    final retries = (opts.extra['retries'] as int?) ?? 0;
    final statusCode = error.response?.statusCode;
    final isColdStartStatus = statusCode == 404 || statusCode == 502 || statusCode == 503;
    final method = opts.method.toUpperCase();
    final hasIdempotencyKey = opts.headers.keys.any(
      (key) => key.toLowerCase() == 'idempotency-key' &&
          opts.headers[key]?.toString().trim().isNotEmpty == true,
    );
    final operationCanBeRetried = method == 'GET' ||
        (hasIdempotencyKey && opts.extra['idempotentRetry'] == true);
    final shouldRetry = operationCanBeRetried && (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        isColdStartStatus) && retries < 2;
    if (shouldRetry) {
      opts.extra['retries'] = retries + 1;
      final delayMs = retries == 0 ? 1500 : 2500;
      await Future.delayed(Duration(milliseconds: delayMs));
      try {
        final res = await _dio.fetch(opts);
        handler.resolve(res);
        return;
      } catch (_) {}
    }
    handler.next(error);
  }



  late final Dio _dio;
  String? _token;

  void setToken(String? token) => _token = token;

  // Generic methods
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final res = await _dio.get(path, queryParameters: queryParameters);
    return res.data;
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final res = await _dio.post(path, data: data);
    return res.data;
  }

  // Quiz API
  Future<List<dynamic>> getLiveQuizzes() async {
    final res = await _dio.get('/quiz/live');
    if (res.data is List) return res.data as List;
    if (res.data is Map && res.data['data'] is List) return res.data['data'] as List;
    return [];
  }

  Future<List<dynamic>> getPaperTests() async {
    final res = await _dio.get('/quiz/tests');
    if (res.data is List) return res.data as List;
    if (res.data is Map && res.data['data'] is List) return res.data['data'] as List;
    return [];
  }

  Future<Map<String, dynamic>> getPaperTest(String testId) async {
    final res = await _dio.get('/quiz/$testId/paper');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<int> recordPaperTestFlag(String testId) async {
    final res = await _dio.post('/quiz/$testId/flag', data: {'event': 'tab_switch'});
    final data = res.data;
    return data is Map ? (data['violation_count'] as num?)?.toInt() ?? 0 : 0;
  }

  Future<void> savePaperTestAnswer(String testId, String questionId, int selectedIndex) async {
    await _dio.patch('/quiz/$testId/answer', data: {
      'question_id': questionId,
      'selected_index': selectedIndex,
    });
  }

  Future<Map<String, dynamic>> submitPaperTest(String testId, Map<String, int> answers) async {
    final res = await _dio.post(
      '/quiz/$testId/submit',
      data: {'answers': answers},
      options: Options(
        headers: {'Idempotency-Key': const Uuid().v4()},
        extra: {'retries': 0, 'idempotentRetry': true},
      ),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> joinQuiz(String pin) async {
    final res = await _dio.post('/quiz/join', data: {'pin': pin});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyQuizResult(String quizId) async {
    final res = await _dio.get('/quiz/$quizId/my-result');
    return res.data as Map<String, dynamic>;
  }

  void clearToken() { _token = null; }


  void warmup() {
    // Fire-and-forget pings to wake up the server
    // ignore: unawaited_futures
    Dio().get(AppConfig.apiHealthUrl).catchError((e) => Response<dynamic>(requestOptions: RequestOptions(path: '/health'), statusCode: 0));
    // ignore: unawaited_futures
    _dio.get('/health').catchError((e) => Response<dynamic>(requestOptions: RequestOptions(path: '/health'), statusCode: 0));
  }

  Future<List<dynamic>> getPendingRequests() async {
    final res = await _dio.get('/connect/pending');
    final data = res.data;
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return (data as List?) ?? [];
  }

  Future<List<dynamic>> getSentRequests() async {
    final res = await _dio.get('/connect/sent');
    final data = res.data;
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return (data as List?) ?? [];
  }

  Future<List<dynamic>> getMyConnections() async {
    final res = await _dio.get('/connect/my');
    final data = res.data;
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return (data as List?) ?? [];
  }

  Future<void> removeConnection(String connectionId) async {
    await _dio.delete('/connect/$connectionId');
  }

  Dio get dioForDebug => _dio;
  Dio getDioForCustom() => _dio;

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/users/me');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(String userId) async {
    final res = await _dio.get('/users/$userId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(String userId, Map<String, dynamic> data) async {
    final res = await _dio.put('/users/$userId/profile', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(String userId, String filePath) async {
    final formData = FormData.fromMap({'photo': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg')});
    final res = await _dio.post('/users/$userId/photo', data: formData);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 20}) async {
    try {
      final res = await _dio.get('/posts/feed', queryParameters: {'page': page, 'limit': limit});
      return res.data as Map<String, dynamic>;
    } catch (_) {
      final res = await _dio.get('/posts', queryParameters: {'page': page, 'limit': limit});
      return res.data as Map<String, dynamic>;
    }
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    final res = await _dio.post('/posts', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final res = await _dio.post('/posts/$postId/like');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getComments(String postId) async {
    final res = await _dio.get('/posts/$postId/comments');
    final data = res.data;
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return [];
  }

  Future<Map<String, dynamic>> addComment(String postId, String content) async {
    final res = await _dio.post('/posts/$postId/comment', data: {'content': content});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> discoverStudents({String? college, String? state, String? city, String? branch, int? year, String? skill, String? q, int page = 1}) async {
    try {
      final res = await _dio.get('/users/discover', queryParameters: {if (college != null) 'college': college, if (state != null) 'state': state, if (city != null) 'city': city, if (branch != null) 'branch': branch, if (year != null) 'year': year, if (skill != null) 'skill': skill, if (q != null) 'q': q, 'page': page});
      return res.data as Map<String, dynamic>;
    } catch (_) {
      final res = await _dio.get('/connect/discover', queryParameters: {if (college != null) 'college': college, if (state != null) 'state': state, if (city != null) 'city': city, if (branch != null) 'branch': branch, if (year != null) 'year': year, if (skill != null) 'skill': skill, if (q != null) 'q': q, 'page': page});
      return res.data as Map<String, dynamic>;
    }
  }

  Future<Map<String, dynamic>> sendConnectionRequest(String receiverId) async {
    final res = await _dio.post('/connect/request', data: {'receiver_id': receiverId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> respondToConnection(String connectionId, String status) async {
    final res = await _dio.put('/connect/$connectionId/respond', data: {'status': status});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTshare(Map<String, dynamic> data) async {
    final res = await _dio.post('/tshare', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> retrieveTshare(String code) async {
    final res = await _dio.get('/tshare/$code');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJobs({String? type, String? state, String? city, bool? isRemote, int page = 1}) async {
    final res = await _dio.get('/jobs', queryParameters: {if (type != null) 'type': type, if (state != null) 'state': state, if (city != null) 'city': city, if (isRemote != null) 'is_remote': isRemote, 'page': page});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProducts({String? category, int page = 1}) async {
    final res = await _dio.get('/products', queryParameters: {if (category != null) 'category': category, 'page': page});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await _dio.post('/products', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNotes({String? subject, int? semester}) async {
    final res = await _dio.get('/notes', queryParameters: {if (subject != null) 'subject': subject, if (semester != null) 'semester': semester});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getChats() async {
    final res = await _dio.get('/chats');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createChat(Map<String, dynamic> data) async {
    final res = await _dio.post('/chats', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> submitReport(Map<String, dynamic> data) async {
    await _dio.post('/reports', data: data);
  }

  Future<Map<String, dynamic>> getVerificationQueue() async {
    final res = await _dio.get('/admin/verification-queue');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReportsQueue() async {
    final res = await _dio.get('/admin/reports');
    if (res.data is List) return {'data': res.data};
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJobApprovalQueue() async {
    final res = await _dio.get('/admin/jobs/pending');
    if (res.data is List) return {'data': res.data};
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHelpingTasks({String? type, bool? mine, String status = 'open', String? q}) async {
    final res = await _dio.get('/helping', queryParameters: {
      if (type != null) 'type': type,
      if (mine == true) 'mine': 'true',
      'status': status,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHelpingTask(String id) async {
    final res = await _dio.get('/helping/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createHelpingTask({required String title, required String description, required String type, double? amount, int? points, String? deadline, String? imagePath}) async {
    final form = FormData.fromMap({
      'title': title,
      'description': description,
      'type': type,
      if (amount != null) 'amount': amount.toString(),
      if (points != null) 'points': points.toString(),
      if (deadline != null) 'deadline': deadline,
      if (imagePath != null) 'image': await MultipartFile.fromFile(imagePath),
    });
    try {
      final res = await _dio.post('/helping', data: form);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data is Map && e.response?.data['error'] != null) {
        throw Exception(e.response?.data['error']);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> applyHelpingTask(String id) async {
    final res = await _dio.post('/helping/$id/apply');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptHelpingApplicant(String id, String applicantId) async {
    final res = await _dio.post('/helping/$id/accept', data: {'applicant_id': applicantId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeHelpingTask(String id) async {
    final res = await _dio.post('/helping/$id/complete');
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteHelpingTask(String id) async {
    await _dio.delete('/helping/$id');
  }

  Future<Map<String, dynamic>> getUserByCampusId(String campusId) async {
    final res = await _dio.get('/users/by-campus/$campusId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transferPoints({
    required String toCampusId,
    required int amount,
    required String idempotencyKey,
  }) async {
    final res = await _dio.post(
      '/users/transfer',
      data: {'to_campus_id': toCampusId, 'amount': amount},
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
        extra: {'retries': 1, 'idempotentRetry': true},
      ),
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Deals API ────────────────────────────────────────────────
  
  Future<List<dynamic>> getDeals() async {
    final res = await _dio.get('/deals');
    final data = res.data;
    if (data is Map) {
      return (data['deals'] as List<dynamic>?) ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>> createDeal(
    Map<String, dynamic> data, {
    String? photoPath,
  }) async {
    if (photoPath != null && photoPath.isNotEmpty) {
      final formData = FormData.fromMap({
        ...data,
        'image': await MultipartFile.fromFile(photoPath),
      });
      final res = await _dio.post('/deals', data: formData);
      return res.data as Map<String, dynamic>;
    }
    final res = await _dio.post('/deals', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Events API ───────────────────────────────────────────────
  
  Future<List<dynamic>> getEvents() async {
    final res = await _dio.get('/events');
    final data = res.data;
    if (data is Map) {
      return (data['events'] as List<dynamic>?) ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>> createEvent(
    Map<String, dynamic> data, {
    String? photoPath,
  }) async {
    if (photoPath != null && photoPath.isNotEmpty) {
      final formData = FormData.fromMap({
        ...data,
        'image': await MultipartFile.fromFile(photoPath),
      });
      final res = await _dio.post('/events', data: formData);
      return res.data as Map<String, dynamic>;
    }
    final res = await _dio.post('/events', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Travel API ───────────────────────────────────────────────
  
  Future<List<dynamic>> getTravelRides() async {
    final res = await _dio.get('/travel');
    final data = res.data;
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return [];
  }

  Future<Map<String, dynamic>> createTravelRide(Map<String, dynamic> data) async {
    final res = await _dio.post('/travel', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Admin Stats & Reports ────────────────────────────────────

  Future<Map<String, dynamic>> getAdminStats() async {
    final res = await _dio.get('/admin/stats');
    return res.data as Map<String, dynamic>;
  }

  Future<void> broadcast(String message) async {
    await _dio.post('/admin/broadcast', data: {
      'title': 'CampusSetu',
      'body': message,
    });
  }

  // ── Admin User Management ────────────────────────────────────

  Future<Map<String, dynamic>> getAdminUsers({
    int page = 1,
    String? q,
    bool? isBanned,
    String? state,
    String? city,
    String? college,
  }) async {
    final res = await _dio.get('/admin/users', queryParameters: {
      'page': page,
      if (q != null && q.isNotEmpty) 'q': q,
      if (isBanned != null) 'is_banned': isBanned.toString(),
      if (state != null && state.isNotEmpty) 'state': state,
      if (city != null && city.isNotEmpty) 'city': city,
      if (college != null && college.isNotEmpty) 'college': college,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAdminUsersMeta() async {
    final res = await _dio.get('/admin/users/meta');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> blockUser(String userId) async {
    final res = await _dio.put('/admin/users/$userId/block');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unblockUser(String userId) async {
    final res = await _dio.put('/admin/users/$userId/unblock');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> freezeUser(String userId) async {
    final res = await _dio.post('/admin/users/$userId/freeze');
    return res.data as Map<String, dynamic>;
  }

  // ── Admin Pulse ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getPulseStats() async {
    final res = await _dio.get('/admin/pulse/stats');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPulseLiveFeed({int limit = 20}) async {
    final res = await _dio.get('/admin/pulse/live-feed', queryParameters: {'limit': limit});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPulseSuspicious() async {
    final res = await _dio.get('/admin/pulse/suspicious');
    return res.data as Map<String, dynamic>;
  }

  Future<void> dismissSuspicious(String userId) async {
    await _dio.post('/admin/pulse/suspicious/$userId/dismiss');
  }

  Future<void> restrictUser(String userId) async {
    await _dio.post('/admin/users/$userId/restrict');
  }

  // ── Flatmates ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFlatmates() async {
    final res = await _dio.get('/flatmates');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAdminFlatmates() async {
    final res = await _dio.get('/admin/flatmates');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createFlatmate(
    Map<String, dynamic> data, {
    List<String>? photoPaths,
  }) async {
    if (photoPaths != null && photoPaths.isNotEmpty) {
      final formData = FormData.fromMap({
        ...data,
        'photos': [
          for (final p in photoPaths) await MultipartFile.fromFile(p),
        ],
      });
      final res = await _dio.post('/flatmates', data: formData);
      return res.data as Map<String, dynamic>;
    }
    final res = await _dio.post('/flatmates', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteFlatmate(String id) async {
    await _dio.delete('/flatmates/$id');
  }

  Future<void> deleteAdminFlatmate(String id) async {
    await _dio.delete('/admin/flatmates/$id');
  }

  Future<void> deleteDeal(String id) async {
    await _dio.delete('/deals/$id');
  }

  Future<void> deleteEvent(String id) async {
    await _dio.delete('/events/$id');
  }
}

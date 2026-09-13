import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/helping_task_model.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';

Future<void> _ensureToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not authenticated');
  final token = await user.getIdToken();
  if (token != null) ApiService().setToken(token);
}

final currentUserProvider = FutureProvider<UserModel>((ref) async {
  await _ensureToken();
  final json = await ApiService().getMe();
  final data = json.containsKey('data') ? json['data'] : json;
  return UserModel.fromJson(Map<String, dynamic>.from(data as Map));
});

final feedProvider = FutureProvider<List<PostModel>>((ref) async {
  await _ensureToken();
  final res = await ApiService().getFeed(page: 1, limit: 20);
  final List list = (res['data'] as List?) ?? [];
  return list.map((e) {
    final m = Map<String, dynamic>.from(e as Map);
    final authorJson = m['author'] is Map ? Map<String, dynamic>.from(m['author'] as Map) : <String, dynamic>{};
    if (authorJson.isEmpty && m['author_id'] != null) authorJson['id'] = m['author_id'];
    m['author'] = authorJson;
    m['likes_count'] = m['likes_count'] ?? m['likesCount'] ?? 0;
    m['comments_count'] = m['comments_count'] ?? m['commentsCount'] ?? 0;
    m['is_liked'] = m['is_liked'] ?? m['isLiked'] ?? false;
    m['image_url'] = m['image_url'] ?? m['imageUrl'];
    return PostModel.fromJson(m);
  }).toList();
});

class DiscoverParams {
  final String search;
  final String? state;
  final String? branch;
  final int? year;
  const DiscoverParams({this.search = '', this.state, this.branch, this.year});
  @override
  bool operator ==(Object other) => other is DiscoverParams && other.search == search && other.state == state && other.branch == branch && other.year == year;
  @override
  int get hashCode => Object.hash(search, state, branch, year);
}

final discoverProvider = FutureProvider.family<List<UserModel>, DiscoverParams>((ref, params) async {
  await _ensureToken();
  final res = await ApiService().discoverStudents(
    state: params.state,
    branch: params.branch,
    year: params.year,
    q: params.search.isNotEmpty ? params.search : null,
  );
  List list;
  if (res.containsKey('data')) {
    list = res['data'] as List;
  } else {
    list = [];
  }
  String q = params.search.toLowerCase();
  var users = list.map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  if (q.isNotEmpty) {
    users = users.where((u) => u.name.toLowerCase().contains(q) || (u.college?.toLowerCase().contains(q) ?? false) || u.skills.any((s) => s.toLowerCase().contains(q))).toList();
  }
  return users;
});

final jobsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, key) async {
  await _ensureToken();
  final parts = key.split('|');
  final type = parts.isNotEmpty ? parts[0] : 'All';
  final remoteOnly = parts.length > 1 && parts[1] == 'true';
  final res = await ApiService().getJobs(
    type: type == 'All' ? null : type,
    isRemote: remoteOnly ? true : null,
  );
  final List list = (res['data'] as List?) ?? [];
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final productsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, key) async {
  await _ensureToken();
  final parts = key.split('|');
  final category = parts.isNotEmpty ? parts[0] : 'All';
  final q = (parts.length > 1 ? parts.sublist(1).join('|') : '').toLowerCase();
  final res = await ApiService().getProducts(category: category == 'All' ? null : category);
  final List list = (res['data'] as List?) ?? [];
  var products = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (q.isNotEmpty) {
    products = products.where((p) => (p['title'] as String? ?? '').toLowerCase().contains(q)).toList();
  }
  return products;
});

final chatThreadsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    await _ensureToken();
    final list = await ApiService().getChats();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return [];
  }
});

final chatUnreadCountProvider = FutureProvider<int>((ref) async {
  try {
    final threads = await ref.watch(chatThreadsProvider.future);
    int total = 0;
    for (final t in threads) {
      final u = t['unread'] ?? t['unread_count'] ?? 0;
      if (u is int) { total += u; } else if (u is String) { total += int.tryParse(u) ?? 0; }
    }
    return total;
  } catch (_) { return 0; }
});

final jobsNewCountProvider = FutureProvider<int>((ref) async {
  try {
    await _ensureToken();
    final res = await ApiService().getJobs();
    final List list = (res['data'] as List?) ?? [];
    return list.length;
  } catch (_) { return 0; }
});

final updateAvailableProvider = FutureProvider<UpdateInfo?>((ref) async {
  try { return await UpdateService.checkForUpdate(); } catch (_) { return null; }
});

final helpingTasksProvider = FutureProvider.family<List<HelpingTask>, String>((ref, key) async {
  await _ensureToken();
  final parts = key.split('|');
  final tab = parts.isNotEmpty ? parts[0] : 'All';
  final mine = parts.length > 1 && parts[1] == 'true';
  final status = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : 'open';
  final q = parts.length > 3 ? parts.sublist(3).join('|') : '';
  final type = tab == 'All' ? null : tab.toLowerCase();
  final res = await ApiService().getHelpingTasks(
    type: type == 'paid' || type == 'points' ? type : null,
    mine: mine,
    status: status,
    q: q.isEmpty ? null : q,
  );
  final List list = (res['data'] as List?) ?? [];
  return list.map((e) => HelpingTask.fromJson(Map<String, dynamic>.from(e as Map))).toList();
});

final helpingTaskDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  await _ensureToken();
  final res = await ApiService().getHelpingTask(id);
  return Map<String, dynamic>.from(res);
});

final profileProvider = FutureProvider.family<UserModel, String?>((ref, userId) async {
  await _ensureToken();
  if (userId == null) {
    final json = await ApiService().getMe();
    final data = json.containsKey('data') ? json['data'] : json;
    return UserModel.fromJson(Map<String, dynamic>.from(data as Map));
  } else {
    final json = await ApiService().getProfile(userId);
    final data = json.containsKey('data') ? json['data'] : json;
    return UserModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
});

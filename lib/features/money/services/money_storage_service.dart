import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/money_models.dart';

class MoneyStorageService {
  static const String _legacyKey = 'campussetu_money_db_v1';
  static const String _prodKeyPrefix = 'campussetu_money_prod_v2';
  static MoneyStorageService? _instance;

  MoneyStorageService._();

  static MoneyStorageService get instance => _instance ??= MoneyStorageService._();

  List<MoneyTransaction> _transactions = [];
  List<UdhaarLoan> _loans = [];
  List<SplitGroup> _groups = [];
  List<SplitBill> _splits = [];
  double _budget = 8000.0;
  bool _initialized = false;
  String? _activeUserId;
  Future<void>? _initFuture;

  List<MoneyTransaction> get transactions => List.unmodifiable(_transactions);
  List<UdhaarLoan> get loans => List.unmodifiable(_loans);
  List<SplitGroup> get groups => List.unmodifiable(_groups);
  List<SplitBill> get splits => List.unmodifiable(_splits);
  double get budget => _budget;
  String? get activeUserId => _activeUserId;

  static String _getStorageKey(String? userId) {
    final safeId = (userId == null || userId.trim().isEmpty) ? 'default' : userId.trim();
    return '${_prodKeyPrefix}_$safeId';
  }

  Future<void> init([String? userId]) {
    if (_initialized && _activeUserId == userId) {
      return Future.value();
    }
    if (_initFuture != null) {
      return _initFuture!;
    }
    _initFuture = _doInit(userId).whenComplete(() {
      _initFuture = null;
    });
    return _initFuture!;
  }

  Future<void> _doInit(String? userId) async {
    _activeUserId = userId;
    final prefs = await SharedPreferences.getInstance();

    // 1. Purge legacy dummy data stored under v1 key if present
    if (prefs.containsKey(_legacyKey)) {
      try {
        final legacyRaw = prefs.getString(_legacyKey);
        if (legacyRaw != null &&
            (legacyRaw.contains('Canteen Lunch') ||
             legacyRaw.contains('Python Book Xerox') ||
             legacyRaw.contains('Rahul Sharma'))) {
          await prefs.remove(_legacyKey);
        }
      } catch (_) {
        await prefs.remove(_legacyKey);
      }
    }

    // 2. Load from production user-scoped key
    final key = _getStorageKey(userId);
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _transactions = (data['transactions'] as List<dynamic>?)
            ?.map((e) => MoneyTransaction.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        _loans = (data['loans'] as List<dynamic>?)
            ?.map((e) => UdhaarLoan.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        _groups = (data['groups'] as List<dynamic>?)
            ?.map((e) => SplitGroup.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        _splits = (data['splits'] as List<dynamic>?)
            ?.map((e) => SplitBill.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        _budget = (data['budget'] as num?)?.toDouble() ?? 8000.0;
      } catch (_) {
        // Fallback to clean state on corrupted data
        _transactions = [];
        _loans = [];
        _groups = [];
        _splits = [];
        _budget = 8000.0;
      }
    } else {
      // Clean production start - zero dummy/static data
      _transactions = [];
      _loans = [];
      _groups = [];
      _splits = [];
      _budget = 8000.0;
    }
    _initialized = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(_activeUserId);
      final data = {
        'transactions': _transactions.map((t) => t.toJson()).toList(),
        'loans': _loans.map((l) => l.toJson()).toList(),
        'groups': _groups.map((g) => g.toJson()).toList(),
        'splits': _splits.map((s) => s.toJson()).toList(),
        'budget': _budget,
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      // Prevent crash if local storage fails temporarily
    }
  }

  // Transactions
  Future<void> addTransaction(MoneyTransaction tx) async {
    _transactions.insert(0, tx);
    await _persist();
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _persist();
  }

  // Loans (Udhaar)
  Future<void> addLoan(UdhaarLoan loan) async {
    _loans.insert(0, loan);
    await _persist();
  }

  Future<void> settleLoan(String id, double amount) async {
    final index = _loans.indexWhere((l) => l.id == id);
    if (index != -1) {
      final current = _loans[index];
      final newRemaining = (current.remaining - amount).clamp(0.0, current.amount);
      _loans[index] = current.copyWith(remaining: newRemaining);
      await _persist();
    }
  }

  Future<void> deleteLoan(String id) async {
    _loans.removeWhere((l) => l.id == id);
    await _persist();
  }

  // Groups
  Future<void> addGroup(SplitGroup group) async {
    _groups.insert(0, group);
    await _persist();
  }

  Future<void> deleteGroup(String id) async {
    _groups.removeWhere((g) => g.id == id);
    _splits.removeWhere((s) => s.groupId == id);
    await _persist();
  }

  // Splits
  Future<void> addSplit(SplitBill bill) async {
    _splits.insert(0, bill);
    await _persist();
  }

  // Budget
  Future<void> setBudget(double newBudget) async {
    _budget = newBudget;
    await _persist();
  }

  // Export
  String exportJson() {
    final data = {
      'transactions': _transactions.map((t) => t.toJson()).toList(),
      'loans': _loans.map((l) => l.toJson()).toList(),
      'groups': _groups.map((g) => g.toJson()).toList(),
      'splits': _splits.map((s) => s.toJson()).toList(),
      'budget': _budget,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String exportCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Title,Category,Amount,Payment Method,Note');
    for (final t in _transactions) {
      buffer.writeln('${t.date},${t.type},"${t.title.replaceAll('"', '""')}",${t.category},${t.amount},${t.method},"${t.note.replaceAll('"', '""')}"');
    }
    return buffer.toString();
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/money_models.dart';

class MoneyStorageService {
  static const String _key = 'campussetu_money_db_v1';
  static MoneyStorageService? _instance;

  MoneyStorageService._();

  static MoneyStorageService get instance => _instance ??= MoneyStorageService._();

  List<MoneyTransaction> _transactions = [];
  List<UdhaarLoan> _loans = [];
  List<SplitGroup> _groups = [];
  List<SplitBill> _splits = [];
  double _budget = 8000.0;
  bool _initialized = false;

  List<MoneyTransaction> get transactions => List.unmodifiable(_transactions);
  List<UdhaarLoan> get loans => List.unmodifiable(_loans);
  List<SplitGroup> get groups => List.unmodifiable(_groups);
  List<SplitBill> get splits => List.unmodifiable(_splits);
  double get budget => _budget;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
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
        _seedDefaults();
      }
    } else {
      _seedDefaults();
      await _persist();
    }
    _initialized = true;
  }

  void _seedDefaults() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _transactions = [
      MoneyTransaction(
        id: '1',
        type: 'expense',
        amount: 180.0,
        title: 'Canteen Lunch',
        category: 'Food',
        date: today,
        method: 'UPI',
        note: 'With friends',
      ),
      MoneyTransaction(
        id: '2',
        type: 'expense',
        amount: 60.0,
        title: 'Campus Auto',
        category: 'Travel',
        date: today,
        method: 'UPI',
        note: 'To metro',
      ),
      MoneyTransaction(
        id: '3',
        type: 'expense',
        amount: 450.0,
        title: 'Python Book Xerox',
        category: 'Study',
        date: today,
        method: 'Cash',
        note: 'Semester 5 notes',
      ),
      MoneyTransaction(
        id: '4',
        type: 'income',
        amount: 6000.0,
        title: 'Monthly Pocket Money',
        category: 'Bills',
        date: today,
        method: 'Bank transfer',
        note: 'From home',
      ),
    ];

    _loans = [
      UdhaarLoan(
        id: 'l1',
        friend: 'Rahul Sharma',
        direction: 'lent',
        amount: 500.0,
        remaining: 500.0,
        date: today,
        note: 'Zomato order',
      ),
      UdhaarLoan(
        id: 'l2',
        friend: 'Ananya Verma',
        direction: 'borrowed',
        amount: 200.0,
        remaining: 200.0,
        date: today,
        note: 'Printout cash',
      ),
    ];

    _groups = [
      SplitGroup(
        id: 'g1',
        name: 'Room 204 (Hostel)',
        members: ['You', 'Rahul', 'Aditi', 'Rohan'],
      ),
    ];

    _splits = [
      SplitBill(
        id: 's1',
        groupId: 'g1',
        title: 'Wifi Bill Oct',
        amount: 800.0,
        payer: 'You',
        mode: 'Equal',
        date: today,
      ),
    ];

    _budget = 8000.0;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'transactions': _transactions.map((t) => t.toJson()).toList(),
      'loans': _loans.map((l) => l.toJson()).toList(),
      'groups': _groups.map((g) => g.toJson()).toList(),
      'splits': _splits.map((s) => s.toJson()).toList(),
      'budget': _budget,
    };
    await prefs.setString(_key, jsonEncode(data));
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

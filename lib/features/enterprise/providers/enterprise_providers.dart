// lib/features/enterprise/providers/enterprise_providers.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enterprise_models.dart';
import '../services/enterprise_storage_service.dart';

// ── NETWORK & SYNC PROVIDERS ─────────────────────────────
final enterpriseNetworkModeProvider = StateNotifierProvider<EnterpriseNetworkNotifier, DemoNetworkMode>((ref) {
  return EnterpriseNetworkNotifier(ref);
});

class EnterpriseNetworkNotifier extends StateNotifier<DemoNetworkMode> {
  final Ref ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicSyncTimer;
  bool _isRealNetworkConnected = true;

  EnterpriseNetworkNotifier(this.ref) : super(DemoNetworkMode.achha) {
    _init();
  }

  Future<void> _init() async {
    final mode = await EnterpriseStorageService.loadNetworkMode();
    state = mode;
    _updateSyncStatus();

    // 1. Initial connectivity check
    try {
      final initialResults = await Connectivity().checkConnectivity();
      _handleConnectivityResults(initialResults);
    } catch (_) {}

    // 2. Real-time network transitions listener
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        _handleConnectivityResults(results);
      });
    } catch (_) {}

    // 3. Periodic background sync heartbeat (every 40s) for pending offline outbox
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 40), (_) async {
      if (state != DemoNetworkMode.offline && _isRealNetworkConnected) {
        final outbox = await EnterpriseStorageService.loadOutbox();
        if (outbox.isNotEmpty) {
          await triggerSync();
        }
      }
    });

    // 4. Initial sync upon entering POS
    if (state != DemoNetworkMode.offline) {
      Future.delayed(const Duration(milliseconds: 500), () => triggerSync());
    }
  }

  void _handleConnectivityResults(List<ConnectivityResult> results) {
    final hasInternet = results.any((r) => r != ConnectivityResult.none);
    _isRealNetworkConnected = hasInternet;

    if (!hasInternet) {
      ref.read(enterpriseSyncStatusProvider.notifier).state = 'Offline - Local saved';
    } else {
      if (state != DemoNetworkMode.offline) {
        // Automatically flush pending local data as soon as internet reconnects!
        triggerSync();
      }
    }
  }

  Future<void> setMode(DemoNetworkMode mode) async {
    state = mode;
    await EnterpriseStorageService.saveNetworkMode(mode);
    _updateSyncStatus();
    if (mode != DemoNetworkMode.offline && _isRealNetworkConnected) {
      await triggerSync();
    }
  }

  void _updateSyncStatus() {
    if (state == DemoNetworkMode.offline || !_isRealNetworkConnected) {
      ref.read(enterpriseSyncStatusProvider.notifier).state = 'Offline - Local saved';
    } else {
      ref.read(enterpriseSyncStatusProvider.notifier).state = 'Database me synced';
    }
  }

  Future<void> triggerSync() async {
    if (state == DemoNetworkMode.offline || !_isRealNetworkConnected) {
      ref.read(enterpriseSyncStatusProvider.notifier).state = 'Offline - Local saved';
      return;
    }

    ref.read(enterpriseSyncStatusProvider.notifier).state = 'Syncing...';
    final ok = await EnterpriseStorageService.syncWithServer(state);
    if (ok) {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      ref.read(enterpriseSyncStatusProvider.notifier).state = 'Database me synced ($timeStr)';

      // Refresh providers with newly reconciled cloud data
      ref.read(enterpriseFoodMenuProvider.notifier).load();
      ref.read(enterpriseBillsProvider.notifier).load();
      ref.read(enterpriseInventoryProvider.notifier).load();
      ref.read(enterpriseUdhaarProvider.notifier).load();
      ref.read(enterpriseStaffProvider.notifier).load();
      ref.read(enterpriseProfileProvider.notifier).load();
    } else {
      ref.read(enterpriseSyncStatusProvider.notifier).state = 'Offline - Local saved';
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}

final enterpriseSyncStatusProvider = StateProvider<String>((ref) => 'Database me synced');

// ── PROFILE & SETTINGS PROVIDER ──────────────────────────
final enterpriseProfileProvider = StateNotifierProvider<EnterpriseProfileNotifier, EnterpriseStoreProfile>((ref) {
  return EnterpriseProfileNotifier(ref);
});

class EnterpriseProfileNotifier extends StateNotifier<EnterpriseStoreProfile> {
  final Ref ref;
  EnterpriseProfileNotifier(this.ref) : super(const EnterpriseStoreProfile()) {
    load();
  }

  Future<void> load() async {
    final p = await EnterpriseStorageService.loadProfile();
    state = p;
  }

  Future<void> updateProfile(EnterpriseStoreProfile newProfile) async {
    state = newProfile;
    await EnterpriseStorageService.saveProfile(newProfile);
    await EnterpriseStorageService.queueMutation('save_profile', newProfile.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> toggleModule(String moduleKey, bool isEnabled) async {
    final currentModules = Map<String, bool>.from(state.enabledModules);
    currentModules[moduleKey] = isEnabled;
    final updated = state.copyWith(enabledModules: currentModules);
    await updateProfile(updated);

    // If disabled, purge memory immediately so no data is loaded for this feature
    if (!isEnabled) {
      switch (moduleKey) {
        case 'inventory':
          ref.read(enterpriseInventoryProvider.notifier).clearData();
          break;
        case 'udhaar':
          ref.read(enterpriseUdhaarProvider.notifier).clearData();
          break;
        case 'staff':
          ref.read(enterpriseStaffProvider.notifier).clearData();
          break;
        case 'redeem':
          ref.read(enterpriseRedeemProvider.notifier).clearData();
          break;
        case 'reports':
          ref.read(enterpriseBillsProvider.notifier).clearData();
          break;
      }
    } else {
      // If enabled, load fresh data on demand
      switch (moduleKey) {
        case 'inventory':
          ref.read(enterpriseInventoryProvider.notifier).load();
          break;
        case 'udhaar':
          ref.read(enterpriseUdhaarProvider.notifier).load();
          break;
        case 'staff':
          ref.read(enterpriseStaffProvider.notifier).load();
          break;
        case 'redeem':
          ref.read(enterpriseRedeemProvider.notifier).load();
          break;
        case 'reports':
          ref.read(enterpriseBillsProvider.notifier).load();
          break;
      }
    }
  }
}

// ── FOOD MENU PROVIDER ───────────────────────────────────
final enterpriseFoodMenuProvider = StateNotifierProvider<EnterpriseFoodMenuNotifier, List<FoodItem>>((ref) {
  return EnterpriseFoodMenuNotifier(ref);
});

class EnterpriseFoodMenuNotifier extends StateNotifier<List<FoodItem>> {
  final Ref ref;
  EnterpriseFoodMenuNotifier(this.ref) : super([]) {
    load();
  }

  Future<void> load() async {
    final items = await EnterpriseStorageService.loadFoodItems();
    state = items;
  }

  Future<void> addItem(String name, String category, double price) async {
    final newItem = FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      category: category.trim().isEmpty ? 'Main' : category.trim(),
      price: price,
    );
    state = [...state, newItem];
    await EnterpriseStorageService.saveFoodItems(state);
    await EnterpriseStorageService.queueMutation('add_food_item', newItem.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> bulkImport(List<FoodItem> newItems) async {
    state = [...state, ...newItems];
    await EnterpriseStorageService.saveFoodItems(state);
    await EnterpriseStorageService.queueMutation('bulk_import_food_items', {
      'items': newItems.map((e) => e.toJson()).toList(),
    });
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> updateItem(FoodItem updated) async {
    state = state.map((item) => item.id == updated.id ? updated : item).toList();
    await EnterpriseStorageService.saveFoodItems(state);
    await EnterpriseStorageService.queueMutation('update_food_item', updated.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> deleteItem(String id) async {
    state = state.where((item) => item.id != id).toList();
    await EnterpriseStorageService.saveFoodItems(state);
    await EnterpriseStorageService.queueMutation('delete_food_item', {'id': id});
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }
}

// ── BILLING & TABLE CARTS STATE ──────────────────────────
class EnterpriseBillingState {
  final String selectedTable;
  final String selectedCategory;
  final Map<String, List<BillItem>> tableCarts;

  const EnterpriseBillingState({
    this.selectedTable = 'Table 1',
    this.selectedCategory = 'All',
    this.tableCarts = const {},
  });

  List<BillItem> get currentCart => tableCarts[selectedTable] ?? [];

  double get subtotal =>
      currentCart.fold(0.0, (acc, item) => acc + item.total);

  double getGstAmount(double gstPercent) =>
      (subtotal * gstPercent) / 100.0;

  double getTotal(double gstPercent) =>
      subtotal + getGstAmount(gstPercent);

  EnterpriseBillingState copyWith({
    String? selectedTable,
    String? selectedCategory,
    Map<String, List<BillItem>>? tableCarts,
  }) {
    return EnterpriseBillingState(
      selectedTable: selectedTable ?? this.selectedTable,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      tableCarts: tableCarts ?? this.tableCarts,
    );
  }
}

final enterpriseBillingProvider = StateNotifierProvider<EnterpriseBillingNotifier, EnterpriseBillingState>((ref) {
  return EnterpriseBillingNotifier(ref);
});

class EnterpriseBillingNotifier extends StateNotifier<EnterpriseBillingState> {
  final Ref ref;
  EnterpriseBillingNotifier(this.ref) : super(const EnterpriseBillingState()) {
    _init();
  }

  Future<void> _init() async {
    final carts = await EnterpriseStorageService.loadTableCarts();
    state = state.copyWith(tableCarts: carts);
  }

  void selectTable(String table) {
    state = state.copyWith(selectedTable: table);
  }

  void selectCategory(String cat) {
    state = state.copyWith(selectedCategory: cat);
  }

  Future<void> addItem(FoodItem food) async {
    final carts = Map<String, List<BillItem>>.from(state.tableCarts);
    final currentList = List<BillItem>.from(carts[state.selectedTable] ?? []);

    final existingIndex = currentList.indexWhere((i) => i.name == food.name);
    if (existingIndex >= 0) {
      currentList[existingIndex].quantity += 1;
    } else {
      currentList.add(BillItem(name: food.name, price: food.price, quantity: 1));
    }

    carts[state.selectedTable] = currentList;
    state = state.copyWith(tableCarts: carts);
    await EnterpriseStorageService.saveTableCarts(carts);
  }

  Future<void> incrementItem(BillItem item) async {
    final carts = Map<String, List<BillItem>>.from(state.tableCarts);
    final currentList = List<BillItem>.from(carts[state.selectedTable] ?? []);

    final idx = currentList.indexWhere((i) => i.name == item.name);
    if (idx >= 0) {
      currentList[idx].quantity += 1;
      carts[state.selectedTable] = currentList;
      state = state.copyWith(tableCarts: carts);
      await EnterpriseStorageService.saveTableCarts(carts);
    }
  }

  Future<void> decrementItem(BillItem item) async {
    final carts = Map<String, List<BillItem>>.from(state.tableCarts);
    final currentList = List<BillItem>.from(carts[state.selectedTable] ?? []);

    final idx = currentList.indexWhere((i) => i.name == item.name);
    if (idx >= 0) {
      if (currentList[idx].quantity > 1) {
        currentList[idx].quantity -= 1;
      } else {
        currentList.removeAt(idx);
      }
      carts[state.selectedTable] = currentList;
      state = state.copyWith(tableCarts: carts);
      await EnterpriseStorageService.saveTableCarts(carts);
    }
  }

  Future<void> removeItem(BillItem item) async {
    final carts = Map<String, List<BillItem>>.from(state.tableCarts);
    final currentList = List<BillItem>.from(carts[state.selectedTable] ?? []);

    currentList.removeWhere((i) => i.name == item.name);
    carts[state.selectedTable] = currentList;
    state = state.copyWith(tableCarts: carts);
    await EnterpriseStorageService.saveTableCarts(carts);
  }

  Future<void> clearCurrentTableCart() async {
    final carts = Map<String, List<BillItem>>.from(state.tableCarts);
    carts.remove(state.selectedTable);
    state = state.copyWith(tableCarts: carts);
    await EnterpriseStorageService.saveTableCarts(carts);
  }

  Future<EnterpriseBill> checkoutBill(String paymentMode, double gstPercent, String prefix) async {
    final cart = state.currentCart;
    final sub = state.subtotal;
    final gstAmt = state.getGstAmount(gstPercent);
    final total = state.getTotal(gstPercent);
    final table = state.selectedTable;

    final bill = EnterpriseBill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      billNumber: '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      tableNumber: table,
      items: List.from(cart),
      subtotal: sub,
      gstPercent: gstPercent,
      gstAmount: gstAmt,
      totalAmount: total,
      paymentMode: paymentMode,
      createdAt: DateTime.now(),
    );

    // Add to bills list
    await ref.read(enterpriseBillsProvider.notifier).addBill(bill);

    // Clear cart for this table
    await clearCurrentTableCart();

    return bill;
  }
}

// ── COMPLETED BILLS PROVIDER ─────────────────────────────
final enterpriseBillsProvider = StateNotifierProvider<EnterpriseBillsNotifier, List<EnterpriseBill>>((ref) {
  return EnterpriseBillsNotifier(ref);
});

class EnterpriseBillsNotifier extends StateNotifier<List<EnterpriseBill>> {
  final Ref ref;
  EnterpriseBillsNotifier(this.ref) : super([]) {
    load();
  }

  Future<void> load() async {
    final isEnabled = ref.read(enterpriseProfileProvider).enabledModules['reports'] ?? true;
    if (!isEnabled) {
      state = [];
      return;
    }
    final bills = await EnterpriseStorageService.loadBills();
    state = bills;
  }

  void clearData() {
    state = [];
  }

  Future<void> addBill(EnterpriseBill bill) async {
    state = [bill, ...state];
    await EnterpriseStorageService.saveBills(state);
    await EnterpriseStorageService.queueMutation('create_bill', bill.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }
}

// ── INVENTORY PROVIDER ───────────────────────────────────
final enterpriseInventoryProvider = StateNotifierProvider<EnterpriseInventoryNotifier, List<InventoryItem>>((ref) {
  return EnterpriseInventoryNotifier(ref);
});

class EnterpriseInventoryNotifier extends StateNotifier<List<InventoryItem>> {
  final Ref ref;
  EnterpriseInventoryNotifier(this.ref) : super([]) {
    load();
  }

  Future<void> load() async {
    final isEnabled = ref.read(enterpriseProfileProvider).enabledModules['inventory'] ?? true;
    if (!isEnabled) {
      state = [];
      return;
    }
    final items = await EnterpriseStorageService.loadInventory();
    state = items;
  }

  void clearData() {
    state = [];
  }

  Future<void> addItem(String name, double quantity, double amount, String vendor, String purchaseDate) async {
    final item = InventoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      itemName: name.trim(),
      quantity: quantity,
      amount: amount,
      vendor: vendor.trim(),
      purchaseDate: purchaseDate,
    );
    state = [item, ...state];
    await EnterpriseStorageService.saveInventory(state);
    await EnterpriseStorageService.queueMutation('add_inventory', item.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> updateItem(InventoryItem updated) async {
    state = state.map((e) => e.id == updated.id ? updated : e).toList();
    await EnterpriseStorageService.saveInventory(state);
    await EnterpriseStorageService.queueMutation('update_inventory', updated.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> bulkImport(List<InventoryItem> newItems) async {
    state = [...newItems, ...state];
    await EnterpriseStorageService.saveInventory(state);
    await EnterpriseStorageService.queueMutation('bulk_import_inventory', {
      'items': newItems.map((e) => e.toJson()).toList(),
    });
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> deleteItem(String id) async {
    state = state.where((e) => e.id != id).toList();
    await EnterpriseStorageService.saveInventory(state);
    await EnterpriseStorageService.queueMutation('delete_inventory', {'id': id});
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }
}

// ── UDHAAR / CRM PROVIDER ────────────────────────────────
final enterpriseUdhaarProvider = StateNotifierProvider<EnterpriseUdhaarNotifier, List<UdhaarRecord>>((ref) {
  return EnterpriseUdhaarNotifier(ref);
});

class EnterpriseUdhaarNotifier extends StateNotifier<List<UdhaarRecord>> {
  final Ref ref;
  EnterpriseUdhaarNotifier(this.ref) : super([]) {
    load();
  }

  Future<void> load() async {
    final isEnabled = ref.read(enterpriseProfileProvider).enabledModules['udhaar'] ?? true;
    if (!isEnabled) {
      state = [];
      return;
    }
    final records = await EnterpriseStorageService.loadUdhaar();
    state = records;
  }

  void clearData() {
    state = [];
  }

  Future<void> addRecord(String customerName, double amount, String type, String date, String notes) async {
    final rec = UdhaarRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: customerName.trim(),
      amount: amount,
      type: type,
      transactionDate: date,
      notes: notes.trim(),
    );
    state = [rec, ...state];
    await EnterpriseStorageService.saveUdhaar(state);
    await EnterpriseStorageService.queueMutation('add_udhaar', rec.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> updateRecord(UdhaarRecord updated) async {
    state = state.map((r) => r.id == updated.id ? updated : r).toList();
    await EnterpriseStorageService.saveUdhaar(state);
    await EnterpriseStorageService.queueMutation('update_udhaar', updated.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> deleteRecord(String id) async {
    state = state.where((r) => r.id != id).toList();
    await EnterpriseStorageService.saveUdhaar(state);
    await EnterpriseStorageService.queueMutation('delete_udhaar', {'id': id});
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }
}

// ── STAFF & ADVANCES PROVIDER ────────────────────────────
final enterpriseStaffProvider = StateNotifierProvider<EnterpriseStaffNotifier, List<StaffMember>>((ref) {
  return EnterpriseStaffNotifier(ref);
});

class EnterpriseStaffNotifier extends StateNotifier<List<StaffMember>> {
  final Ref ref;
  EnterpriseStaffNotifier(this.ref) : super([]) {
    load();
  }

  Future<void> load() async {
    final isEnabled = ref.read(enterpriseProfileProvider).enabledModules['staff'] ?? true;
    if (!isEnabled) {
      state = [];
      return;
    }
    final list = await EnterpriseStorageService.loadStaff();
    state = list;
  }

  void clearData() {
    state = [];
  }

  Future<void> addStaff(String name, String post, double salary, String joiningDate) async {
    final s = StaffMember(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      post: post.trim(),
      salary: salary,
      joiningDate: joiningDate,
      advances: [],
    );
    state = [...state, s];
    await EnterpriseStorageService.saveStaff(state);
    await EnterpriseStorageService.queueMutation('add_staff', s.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> updateStaff(StaffMember updated) async {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
    await EnterpriseStorageService.saveStaff(state);
    await EnterpriseStorageService.queueMutation('update_staff', updated.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> deleteStaff(String id) async {
    state = state.where((e) => e.id != id).toList();
    await EnterpriseStorageService.saveStaff(state);
    await EnterpriseStorageService.queueMutation('delete_staff', {'id': id});
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }

  Future<void> addAdvance(String staffId, double amount, String date, String notes) async {
    final adv = StaffAdvance(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      staffId: staffId,
      amount: amount,
      advanceDate: date,
      notes: notes.trim(),
    );
    state = state.map((s) {
      if (s.id == staffId) {
        return StaffMember(
          id: s.id,
          name: s.name,
          post: s.post,
          salary: s.salary,
          joiningDate: s.joiningDate,
          advances: [adv, ...s.advances],
        );
      }
      return s;
    }).toList();
    await EnterpriseStorageService.saveStaff(state);
    await EnterpriseStorageService.queueMutation('add_staff_advance', adv.toJson());
    ref.read(enterpriseNetworkModeProvider.notifier).triggerSync();
  }
}

// ── REDEEM LOGS PROVIDER ─────────────────────────────────
final enterpriseRedeemProvider = StateNotifierProvider<EnterpriseRedeemNotifier, List<RedeemLog>>((ref) {
  return EnterpriseRedeemNotifier(ref);
});

class EnterpriseRedeemNotifier extends StateNotifier<List<RedeemLog>> {
  final Ref ref;
  EnterpriseRedeemNotifier(this.ref) : super([]) {
    load();
  }

  Future<void> load() async {
    final isEnabled = ref.read(enterpriseProfileProvider).enabledModules['redeem'] ?? true;
    if (!isEnabled) {
      state = [];
      return;
    }
    final logs = await EnterpriseStorageService.loadRedeemLogs();
    state = logs;
  }

  void clearData() {
    state = [];
  }

  Future<void> logRedemption(String dealId, String dealTitle, String dealCode, String studentName) async {
    final entry = RedeemLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dealId: dealId,
      dealTitle: dealTitle,
      dealCode: dealCode,
      studentName: studentName,
      timestamp: DateTime.now(),
    );
    state = [entry, ...state];
    await EnterpriseStorageService.saveRedeemLogs(state);
  }
}

// lib/features/enterprise/services/enterprise_storage_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../models/enterprise_models.dart';

enum DemoNetworkMode {
  achha,
  dheema,
  offline;

  String get label {
    switch (this) {
      case DemoNetworkMode.achha:
        return 'Achha';
      case DemoNetworkMode.dheema:
        return 'Dheema';
      case DemoNetworkMode.offline:
        return 'Offline';
    }
  }
}

class EnterpriseStorageService {
  static const _kProfile = 'ent_pos_profile';
  static const _kFoodItems = 'ent_pos_food_items';
  static const _kTableCarts = 'ent_pos_table_carts';
  static const _kBills = 'ent_pos_bills';
  static const _kInventory = 'ent_pos_inventory';
  static const _kUdhaar = 'ent_pos_udhaar';
  static const _kStaff = 'ent_pos_staff';
  static const _kRedeemLogs = 'ent_pos_redeem_logs';
  static const _kOutbox = 'ent_pos_outbox';
  static const _kNetworkMode = 'ent_pos_network_mode';

  // Seed default food items (from screenshot)
  static final List<FoodItem> defaultSeedMenu = [
    const FoodItem(id: '1', name: 'Masala Dosa', category: 'Nashta', price: 90),
    const FoodItem(id: '2', name: 'Poha', category: 'Nashta', price: 45),
    const FoodItem(id: '3', name: 'Paneer Butter Masala', category: 'Main', price: 210),
    const FoodItem(id: '4', name: 'Veg Thali', category: 'Main', price: 160),
    const FoodItem(id: '5', name: 'Masala Chai', category: 'Drinks', price: 20),
    const FoodItem(id: '6', name: 'Gulab Jamun', category: 'Meetha', price: 60),
  ];

  // ── PROFILE ──────────────────────────────────────────────
  static Future<EnterpriseStoreProfile> loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProfile);
    if (raw == null) return const EnterpriseStoreProfile();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return EnterpriseStoreProfile.fromJson(map);
    } catch (_) {
      return const EnterpriseStoreProfile();
    }
  }

  static Future<void> saveProfile(EnterpriseStoreProfile profile) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProfile, jsonEncode(profile.toJson()));
  }

  // ── FOOD ITEMS ───────────────────────────────────────────
  static Future<List<FoodItem>> loadFoodItems() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kFoodItems);
    if (raw == null) {
      // Seed default menu
      await saveFoodItems(defaultSeedMenu);
      return defaultSeedMenu;
    }
    try {
      final list = jsonDecode(raw) as List;
      final items = list.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
      return items.isEmpty ? defaultSeedMenu : items;
    } catch (_) {
      return defaultSeedMenu;
    }
  }

  static Future<void> saveFoodItems(List<FoodItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_kFoodItems, raw);
  }

  // ── ACTIVE TABLE CARTS (HOLD BILLS) ──────────────────────
  static Future<Map<String, List<BillItem>>> loadTableCarts() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kTableCarts);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, List<BillItem>>{};
      map.forEach((table, itemsList) {
        if (itemsList is List) {
          result[table] = itemsList
              .map((i) => BillItem.fromJson(i as Map<String, dynamic>))
              .toList();
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveTableCarts(Map<String, List<BillItem>> carts) async {
    final sp = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    carts.forEach((table, items) {
      map[table] = items.map((i) => i.toJson()).toList();
    });
    await sp.setString(_kTableCarts, jsonEncode(map));
  }

  // ── BILLS ────────────────────────────────────────────────
  static Future<List<EnterpriseBill>> loadBills() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kBills);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => EnterpriseBill.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBills(List<EnterpriseBill> bills) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(bills.map((e) => e.toJson()).toList());
    await sp.setString(_kBills, raw);
  }

  // ── INVENTORY ────────────────────────────────────────────
  static Future<List<InventoryItem>> loadInventory() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kInventory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveInventory(List<InventoryItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_kInventory, raw);
  }

  // ── UDHAAR / CRM ─────────────────────────────────────────
  static Future<List<UdhaarRecord>> loadUdhaar() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kUdhaar);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => UdhaarRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveUdhaar(List<UdhaarRecord> records) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(records.map((e) => e.toJson()).toList());
    await sp.setString(_kUdhaar, raw);
  }

  // ── STAFF & ADVANCES ─────────────────────────────────────
  static Future<List<StaffMember>> loadStaff() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kStaff);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveStaff(List<StaffMember> staff) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(staff.map((e) => e.toJson()).toList());
    await sp.setString(_kStaff, raw);
  }

  // ── REDEEM LOGS ──────────────────────────────────────────
  static Future<List<RedeemLog>> loadRedeemLogs() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kRedeemLogs);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => RedeemLog.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveRedeemLogs(List<RedeemLog> logs) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(logs.map((e) => e.toJson()).toList());
    await sp.setString(_kRedeemLogs, raw);
  }

  // ── DEMO NETWORK & SYNC OUTBOX ───────────────────────────
  static Future<DemoNetworkMode> loadNetworkMode() async {
    final sp = await SharedPreferences.getInstance();
    final val = sp.getString(_kNetworkMode);
    if (val == 'dheema') return DemoNetworkMode.dheema;
    if (val == 'offline') return DemoNetworkMode.offline;
    return DemoNetworkMode.achha;
  }

  static Future<void> saveNetworkMode(DemoNetworkMode mode) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kNetworkMode, mode.name);
  }

  static Future<List<Map<String, dynamic>>> loadOutbox() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kOutbox);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> queueMutation(String type, Map<String, dynamic> payload) async {
    final sp = await SharedPreferences.getInstance();
    final outbox = await loadOutbox();
    outbox.add({
      'type': type,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await sp.setString(_kOutbox, jsonEncode(outbox));
  }

  static Future<void> clearOutbox() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kOutbox);
  }

  // Perform sync with Cloud backend
  static Future<bool> syncWithServer(DemoNetworkMode networkMode) async {
    if (networkMode == DemoNetworkMode.offline) {
      return false; // Offline mode deliberately skips network
    }

    if (networkMode == DemoNetworkMode.dheema) {
      // Simulate slow network latency
      await Future.delayed(const Duration(milliseconds: 2000));
    }

    try {
      final outbox = await loadOutbox();
      final res = await ApiService().post('/enterprise/sync', data: {
        'mutations': outbox,
      });

      if (res != null) {
        await clearOutbox();
        return true;
      }
    } catch (e) {
      debugPrint('[EnterpriseSync] Local fallback retained: $e');
    }
    return false;
  }
}

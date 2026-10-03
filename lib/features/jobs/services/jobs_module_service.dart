// lib/features/jobs/services/jobs_module_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';

class JobsModuleService {
  JobsModuleService._();
  static final JobsModuleService instance = JobsModuleService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('app_config').doc('jobs_module');

  /// Stream real-time status of the Jobs module.
  /// If jobs are disabled by admin, students only see the Task Board.
  Stream<bool> watchJobsStatus() {
    return _configRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return true;
      final data = snapshot.data()!;
      return (data['is_enabled'] ?? data['isEnabled'] ?? true) == true;
    }).handleError((err) {
      debugPrint('[JobsModuleService] stream error: $err');
      return true;
    });
  }

  /// Get current status once (with API fallback)
  Future<bool> getJobsStatus() async {
    try {
      final doc = await _configRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return (data['is_enabled'] ?? data['isEnabled'] ?? true) == true;
      }
    } catch (_) {}
    return await ApiService().getJobsStatus();
  }

  /// Admin toggle to enable/disable the Jobs section
  Future<void> setJobsStatus(bool isEnabled) async {
    try {
      await _configRef.set({
        'is_enabled': isEnabled,
        'isEnabled': isEnabled,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[JobsModuleService] firestore set error: $e');
    }
    // Also update via backend API to ensure consistency
    try {
      await ApiService().setJobsStatus(isEnabled);
    } catch (e) {
      debugPrint('[JobsModuleService] api set error: $e');
    }
  }
}

final jobsModuleStatusProvider = StreamProvider.autoDispose<bool>((ref) {
  return JobsModuleService.instance.watchJobsStatus();
});

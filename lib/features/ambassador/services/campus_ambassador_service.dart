// lib/features/ambassador/services/campus_ambassador_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../models/campus_ambassador_model.dart';

class CampusAmbassadorService {
  CampusAmbassadorService._();
  static final CampusAmbassadorService instance = CampusAmbassadorService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ambassadorsRef =>
      _firestore.collection('campus_ambassadors');

  /// Poll the server-owned status. Fail closed if the status cannot be verified.
  Stream<bool> watchProgramStatus() async* {
    while (true) {
      try {
        yield await ApiService().getAmbassadorProgramStatus();
      } catch (e) {
        debugPrint('[CampusAmbassadorService] status check failed: $e');
        yield false;
      }
      await Future<void>.delayed(const Duration(seconds: 15));
    }
  }

  /// Get current program status once
  Future<bool> getProgramStatus() async {
    try {
      return await ApiService().getAmbassadorProgramStatus();
    } catch (e) {
      debugPrint('[CampusAmbassadorService] getProgramStatus error: $e');
      return false;
    }
  }

  /// Admin toggle: turn program ON or OFF
  Future<void> setProgramStatus(bool isOpen) async {
    await ApiService().setAmbassadorProgramStatus(isOpen);
  }

  /// Submit or update student ambassador application
  Future<void> submitApplication(CampusAmbassadorModel application) async {
    await ApiService().submitAmbassadorApplication({
      'name': application.name,
      'age': application.age,
      'phone': application.phone,
      'degree': application.degree,
      'current_year': application.currentYear,
      'college_name': application.collegeName,
      'previous_experience': application.previousExperience,
    });
  }

  /// Stream current user's application
  Stream<CampusAmbassadorModel?> watchMyApplication(String userId) async* {
    if (userId.isEmpty) {
      yield null;
      return;
    }

    try {
      await for (final doc in _ambassadorsRef.doc(userId).snapshots()) {
        if (!doc.exists || doc.data() == null) {
          yield null;
        } else {
          try {
            yield CampusAmbassadorModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('[CampusAmbassadorService] Parse error in my application: $e');
            yield null;
          }
        }
      }
    } catch (e) {
      debugPrint('[CampusAmbassadorService] watchMyApplication error: $e');
      yield null;
    }
  }

  /// Stream all applicants for admin review without ever hanging in infinite loading
  Stream<List<CampusAmbassadorModel>> watchAllApplications() async* {
    // 1. Try backend API first (works seamlessly on Admin Web & mobile)
    try {
      final list = await fetchAllApplications();
      if (list.isNotEmpty) yield list;
    } catch (_) {}

    // 2. Listen to real-time snapshots if client Firestore access is available
    try {
      await for (final querySnapshot in _ambassadorsRef.snapshots()) {
        final list = _parseSnapshot(querySnapshot);
        yield list;
      }
    } catch (e) {
      debugPrint('[CampusAmbassadorService] Live snapshots error: $e');
      // 3. Fallback to direct backend API
      try {
        final list = await fetchAllApplications();
        yield list;
      } catch (err) {
        debugPrint('[CampusAmbassadorService] Fallback fetch error: $err');
        yield <CampusAmbassadorModel>[];
      }
    }
  }

  /// One-time fetch for all applications
  Future<List<CampusAmbassadorModel>> fetchAllApplications() async {
    // 1. Primary: REST API (Admin endpoint has full backend root permissions)
    try {
      final rawList = await ApiService().getAdminAmbassadorApplications();
      if (rawList.isNotEmpty) {
        final list = rawList
            .map((item) => CampusAmbassadorModel.fromMap(item, item['id']?.toString() ?? ''))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
    } catch (e) {
      debugPrint('[CampusAmbassadorService] API fetchAllApplications error: $e');
    }

    // 2. Fallback: Direct Firestore
    try {
      final querySnapshot =
          await _ambassadorsRef.get().timeout(const Duration(seconds: 6));
      return _parseSnapshot(querySnapshot);
    } catch (e) {
      debugPrint('[CampusAmbassadorService] Firestore fetchAllApplications error: $e');
      return <CampusAmbassadorModel>[];
    }
  }

  List<CampusAmbassadorModel> _parseSnapshot(
      QuerySnapshot<Map<String, dynamic>> snapshot) {
    final list = <CampusAmbassadorModel>[];
    for (final doc in snapshot.docs) {
      try {
        list.add(CampusAmbassadorModel.fromFirestore(doc));
      } catch (e) {
        debugPrint(
            '[CampusAmbassadorService] Skipping corrupted ambassador doc ${doc.id}: $e');
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Admin action: update status (accepted / rejected / pending)
  Future<void> updateApplicationStatus(
    String id,
    AmbassadorStatus status, {
    String? reviewNote,
  }) async {
    // 1. Update via Backend API
    try {
      await ApiService().updateAdminAmbassadorStatus(
        id,
        status.toDbString(),
        reviewNote: reviewNote,
      );
    } catch (e) {
      debugPrint('[CampusAmbassadorService] Api updateApplicationStatus error: $e');
    }

    // 2. Also sync to Firestore directly if possible
    try {
      final updateData = <String, dynamic>{
        'status': status.toDbString(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (reviewNote != null) {
        updateData['review_note'] = reviewNote;
      }
      await _ambassadorsRef.doc(id).set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[CampusAmbassadorService] Firestore update status error: $e');
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

/// Provides real-time boolean indicating if Ambassador Program is OPEN
final ambassadorProgramStatusProvider = StreamProvider<bool>((ref) {
  return CampusAmbassadorService.instance.watchProgramStatus();
});

/// Streams current user's submitted application (if any)
final myAmbassadorApplicationProvider =
    StreamProvider<CampusAmbassadorModel?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);
  return CampusAmbassadorService.instance.watchMyApplication(user.uid);
});

/// Streams all applications for Admin Console
final adminAmbassadorsStreamProvider =
    StreamProvider<List<CampusAmbassadorModel>>((ref) {
  return CampusAmbassadorService.instance.watchAllApplications();
});

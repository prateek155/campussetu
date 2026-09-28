// lib/features/ambassador/services/campus_ambassador_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campus_ambassador_model.dart';

class CampusAmbassadorService {
  CampusAmbassadorService._();
  static final CampusAmbassadorService instance = CampusAmbassadorService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ambassadorsRef =>
      _firestore.collection('campus_ambassadors');

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('app_config').doc('ambassador_program');

  /// Stream program active state (yields default true immediately so UI never blocks)
  Stream<bool> watchProgramStatus() async* {
    yield true; // Immediate fallback value

    try {
      await for (final snapshot in _configRef.snapshots()) {
        if (!snapshot.exists || snapshot.data() == null) {
          yield true;
        } else {
          final data = snapshot.data()!;
          yield data['isOpen'] as bool? ?? data['is_open'] as bool? ?? true;
        }
      }
    } catch (e) {
      debugPrint('[CampusAmbassadorService] watchProgramStatus error: $e');
      yield true;
    }
  }

  /// Get current program status once
  Future<bool> getProgramStatus() async {
    try {
      final doc = await _configRef.get().timeout(const Duration(seconds: 4));
      if (!doc.exists || doc.data() == null) return true;
      final data = doc.data()!;
      return data['isOpen'] as bool? ?? data['is_open'] as bool? ?? true;
    } catch (e) {
      debugPrint('[CampusAmbassadorService] getProgramStatus error: $e');
      return true;
    }
  }

  /// Admin toggle: turn program ON or OFF
  Future<void> setProgramStatus(bool isOpen) async {
    await _configRef.set({
      'isOpen': isOpen,
      'is_open': isOpen,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Submit or update student ambassador application
  Future<void> submitApplication(CampusAmbassadorModel application) async {
    final docId = application.userId.isNotEmpty
        ? application.userId
        : application.id;
    if (docId.isEmpty) {
      throw Exception('User ID is required to submit an application');
    }

    final data = application.toMap();
    await _ambassadorsRef.doc(docId).set(data, SetOptions(merge: true));
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
    // 1. Try to yield cached or quick fetch first so Riverpod gets data instantly
    try {
      final cachedSnap = await _ambassadorsRef
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(milliseconds: 500));
      if (cachedSnap.docs.isNotEmpty) {
        yield _parseSnapshot(cachedSnap);
      }
    } catch (_) {
      // Cache miss or timeout, proceed to live snapshots
    }

    // 2. Listen to real-time snapshots
    try {
      await for (final querySnapshot in _ambassadorsRef.snapshots()) {
        final list = _parseSnapshot(querySnapshot);
        yield list;
      }
    } catch (e) {
      debugPrint('[CampusAmbassadorService] Live snapshots error: $e');
      // 3. Fallback to direct get() if snapshots fails (e.g. security rules or listener issue)
      try {
        final querySnapshot =
            await _ambassadorsRef.get().timeout(const Duration(seconds: 5));
        yield _parseSnapshot(querySnapshot);
      } catch (err) {
        debugPrint('[CampusAmbassadorService] Fallback get() error: $err');
        // Always yield a valid list so the stream finishes loading state
        yield <CampusAmbassadorModel>[];
      }
    }
  }

  /// One-time fetch for all applications
  Future<List<CampusAmbassadorModel>> fetchAllApplications() async {
    try {
      final querySnapshot =
          await _ambassadorsRef.get().timeout(const Duration(seconds: 6));
      return _parseSnapshot(querySnapshot);
    } catch (e) {
      debugPrint('[CampusAmbassadorService] fetchAllApplications error: $e');
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
    final updateData = <String, dynamic>{
      'status': status.toDbString(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (reviewNote != null) {
      updateData['review_note'] = reviewNote;
    }
    await _ambassadorsRef.doc(id).set(updateData, SetOptions(merge: true));
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

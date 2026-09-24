// lib/features/ambassador/services/campus_ambassador_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Stream program active state (default true if not yet set in DB)
  Stream<bool> watchProgramStatus() {
    return _configRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return true;
      final data = snapshot.data()!;
      return data['isOpen'] as bool? ?? data['is_open'] as bool? ?? true;
    }).handleError((_) => true);
  }

  /// Get current program status once
  Future<bool> getProgramStatus() async {
    try {
      final doc = await _configRef.get();
      if (!doc.exists || doc.data() == null) return true;
      final data = doc.data()!;
      return data['isOpen'] as bool? ?? data['is_open'] as bool? ?? true;
    } catch (_) {
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
  Stream<CampusAmbassadorModel?> watchMyApplication(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return _ambassadorsRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return CampusAmbassadorModel.fromFirestore(doc);
    }).handleError((e) {
      return null;
    });
  }

  /// Stream all applicants for admin review
  Stream<List<CampusAmbassadorModel>> watchAllApplications() {
    return _ambassadorsRef
        .snapshots()
        .map((querySnapshot) {
          final list = querySnapshot.docs
              .map((doc) => CampusAmbassadorModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((e) {
          return <CampusAmbassadorModel>[];
        });
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

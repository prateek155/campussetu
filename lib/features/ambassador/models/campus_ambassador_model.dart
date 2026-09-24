// lib/features/ambassador/models/campus_ambassador_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AmbassadorStatus {
  pending,
  accepted,
  rejected;

  static AmbassadorStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'accepted':
        return AmbassadorStatus.accepted;
      case 'rejected':
        return AmbassadorStatus.rejected;
      default:
        return AmbassadorStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case AmbassadorStatus.accepted:
        return 'accepted';
      case AmbassadorStatus.rejected:
        return 'rejected';
      case AmbassadorStatus.pending:
        return 'pending';
    }
  }

  String get label {
    switch (this) {
      case AmbassadorStatus.accepted:
        return 'Accepted';
      case AmbassadorStatus.rejected:
        return 'Rejected';
      case AmbassadorStatus.pending:
        return 'Under Review';
    }
  }
}

class CampusAmbassadorModel {
  final String id;
  final String userId;
  final String name;
  final String age;
  final String phone;
  final String degree;
  final String currentYear;
  final String collegeName;
  final String previousExperience;
  final AmbassadorStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? reviewNote;

  const CampusAmbassadorModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.age,
    required this.phone,
    required this.degree,
    required this.currentYear,
    required this.collegeName,
    required this.previousExperience,
    this.status = AmbassadorStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.reviewNote,
  });

  factory CampusAmbassadorModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CampusAmbassadorModel.fromMap(data, doc.id);
  }

  factory CampusAmbassadorModel.fromMap(Map<String, dynamic> data, [String id = '']) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return CampusAmbassadorModel(
      id: id.isNotEmpty ? id : (data['id']?.toString() ?? ''),
      userId: data['user_id']?.toString() ?? data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      age: data['age']?.toString() ?? '',
      phone: data['phone']?.toString() ?? data['number']?.toString() ?? '',
      degree: data['degree']?.toString() ?? '',
      currentYear: data['current_year']?.toString() ?? data['currentYear']?.toString() ?? '',
      collegeName: data['college_name']?.toString() ?? data['clg_name']?.toString() ?? data['collegeName']?.toString() ?? '',
      previousExperience: data['previous_experience']?.toString() ?? data['previousExperience']?.toString() ?? '',
      status: AmbassadorStatus.fromString(data['status']?.toString()),
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
      updatedAt: data['updated_at'] != null ? parseDate(data['updated_at']) : null,
      reviewNote: data['review_note']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'age': age,
      'phone': phone,
      'degree': degree,
      'current_year': currentYear,
      'college_name': collegeName,
      'previous_experience': previousExperience,
      'status': status.toDbString(),
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      if (reviewNote != null) 'review_note': reviewNote,
    };
  }

  CampusAmbassadorModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? age,
    String? phone,
    String? degree,
    String? currentYear,
    String? collegeName,
    String? previousExperience,
    AmbassadorStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reviewNote,
  }) {
    return CampusAmbassadorModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      age: age ?? this.age,
      phone: phone ?? this.phone,
      degree: degree ?? this.degree,
      currentYear: currentYear ?? this.currentYear,
      collegeName: collegeName ?? this.collegeName,
      previousExperience: previousExperience ?? this.previousExperience,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}

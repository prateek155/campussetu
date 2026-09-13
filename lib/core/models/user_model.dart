// lib/core/models/user_model.dart

class UserModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? college;
  final String? state;
  final String? city;
  final String? course;
  final String? branch;
  final int? yearOfStudy;
  final String? bio;
  final List<String> skills;
  final bool isVerified;
  final bool isPremium;
  final bool isAdmin;
  final String role; // 'student' | 'admin'
  final String? campusId;
  final bool profileComplete;
  final DateTime createdAt;
  final int connectionsCount;
  final int notesCount;
  final int projectsCount;
  final int points;

  const UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.college,
    this.state,
    this.city,
    this.course,
    this.branch,
    this.yearOfStudy,
    this.bio,
    this.skills = const [],
    this.isVerified = false,
    this.isPremium = false,
    this.isAdmin = false,
    this.role = 'student',
    this.campusId,
    this.profileComplete = false,
    required this.createdAt,
    this.connectionsCount = 0,
    this.notesCount = 0,
    this.projectsCount = 0,
    this.points = 0,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }
  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v == 'true' || v == 't' || v == '1';
    if (v is int) return v == 1;
    return false;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id']?.toString() ?? '',
        firebaseUid: json['firebase_uid'] ?? '',
        email: json['email'] ?? '',
        name: json['name'] ?? '',
        photoUrl: json['photo_url'],
        college: json['college'],
        state: json['state'],
        city: json['city'],
        course: json['course'],
        branch: json['branch'],
        yearOfStudy: json['year_of_study'] is String ? int.tryParse(json['year_of_study']) : json['year_of_study'] as int?,
        bio: json['bio'],
        skills: List<String>.from(json['skills'] ?? []),
        isVerified: _toBool(json['is_verified']),
        isPremium: _toBool(json['is_premium']),
        isAdmin: _toBool(json['is_admin']),
        role: json['role'] ?? 'student',
        campusId: json['campus_id']?.toString(),
        profileComplete: _toBool(json['profile_complete']),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        connectionsCount: _toInt(json['connections_count'] ?? json['connectionsCount']),
        notesCount: _toInt(json['notes_count'] ?? json['notesCount']),
        projectsCount: _toInt(json['projects_count'] ?? json['projectsCount'] ?? json['notes_count'] ?? 0),
        points: _toInt(json['points']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'campus_id': campusId,
        'firebase_uid': firebaseUid,
        'email': email,
        'name': name,
        'photo_url': photoUrl,
        'college': college,
        'state': state,
        'city': city,
        'course': course,
        'branch': branch,
        'year_of_study': yearOfStudy,
        'bio': bio,
        'skills': skills,
        'is_verified': isVerified,
        'is_premium': isPremium,
        'role': role,
        'profile_complete': profileComplete,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? name,
    String? photoUrl,
    String? college,
    String? state,
    String? city,
    String? course,
    String? branch,
    int? yearOfStudy,
    String? bio,
    List<String>? skills,
    bool? isVerified,
    bool? isPremium,
    String? campusId,
    bool? profileComplete,
    int? connectionsCount,
    int? notesCount,
    int? projectsCount,
    int? points,
  }) =>
      UserModel(
        id: id,
        firebaseUid: firebaseUid,
        email: email,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        college: college ?? this.college,
        state: state ?? this.state,
        city: city ?? this.city,
        course: course ?? this.course,
        branch: branch ?? this.branch,
        yearOfStudy: yearOfStudy ?? this.yearOfStudy,
        bio: bio ?? this.bio,
        skills: skills ?? this.skills,
        isVerified: isVerified ?? this.isVerified,
        isPremium: isPremium ?? this.isPremium,
        role: role,
        campusId: campusId ?? this.campusId,
        profileComplete: profileComplete ?? this.profileComplete,
        createdAt: createdAt,
        connectionsCount: connectionsCount ?? this.connectionsCount,
        notesCount: notesCount ?? this.notesCount,
        projectsCount: projectsCount ?? this.projectsCount,
        points: points ?? this.points,
      );

  double get profileCompletionScore {
    int filled = 0;
    const total = 9;
    if (name.isNotEmpty) filled++;
    if (photoUrl != null && photoUrl!.isNotEmpty) filled++;
    if (college != null && college!.isNotEmpty) filled++;
    if (state != null) filled++;
    if (city != null) filled++;
    if (course != null) filled++;
    if (branch != null) filled++;
    if (yearOfStudy != null) filled++;
    if (bio != null && bio!.isNotEmpty) filled++;
    return filled / total;
  }
}

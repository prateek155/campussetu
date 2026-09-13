class HelpingTask {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String type;
  final double? amount;
  final int? points;
  final String? deadline;
  final String posterId;
  final String status;
  final String? assigneeId;
  final String createdAt;
  final String? expiresAt;
  final int applicationsCount;
  final Map<String, dynamic>? poster;

  const HelpingTask({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.type,
    this.amount,
    this.points,
    this.deadline,
    required this.posterId,
    required this.status,
    this.assigneeId,
    required this.createdAt,
    this.expiresAt,
    this.applicationsCount = 0,
    this.poster,
  });

  bool get isPaid => type == 'paid';
  bool get isOnHold => status == 'on_hold';
  String get rewardLabel {
    if (isPaid) {
      final a = amount ?? 0.0;
      return '₹${a % 1 == 0 ? a.toInt() : a.toStringAsFixed(2)}';
    }
    return '${points ?? 0} pts';
  }
  DateTime? get createdDate => DateTime.tryParse(createdAt);
  DateTime? get expiryDate => expiresAt != null ? DateTime.tryParse(expiresAt!) : createdDate?.add(const Duration(days: 7));
  int get daysLeft {
    final e = expiryDate;
    if (e == null || isOnHold) return 0;
    return e.difference(DateTime.now()).inDays;
  }

  factory HelpingTask.fromJson(Map<String, dynamic> j) => HelpingTask(
        id: j['id'].toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        imageUrl: j['image_url'] as String?,
        type: (j['type'] ?? 'paid').toString(),
        amount: j['amount'] == null ? null : double.tryParse(j['amount'].toString()),
        points: j['points'] == null ? null : int.tryParse(j['points'].toString()),
        deadline: j['deadline']?.toString(),
        posterId: (j['poster_id'] ?? '').toString(),
        status: (j['status'] ?? 'open').toString(),
        assigneeId: j['assignee_id']?.toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        expiresAt: j['expires_at']?.toString(),
        applicationsCount: int.tryParse((j['applications_count'] ?? 0).toString()) ?? 0,
        poster: j['poster'] is Map ? Map<String, dynamic>.from(j['poster'] as Map) : null,
      );
}

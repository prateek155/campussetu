class TravelModel {
  final String id;
  final String userId;
  final String? userName;
  final String? college;
  final String? avatar;
  final String vehicleType;
  final String destination;
  final String timeDate;
  final String contactNumber;
  final String status;
  final String createdAt;

  TravelModel({
    required this.id,
    required this.userId,
    this.userName,
    this.college,
    this.avatar,
    required this.vehicleType,
    required this.destination,
    required this.timeDate,
    required this.contactNumber,
    required this.status,
    required this.createdAt,
  });

  factory TravelModel.fromJson(Map<String, dynamic> json) {
    return TravelModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString(),
      college: json['college']?.toString(),
      avatar: json['avatar']?.toString(),
      vehicleType: json['vehicle_type']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      timeDate: json['time_date']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

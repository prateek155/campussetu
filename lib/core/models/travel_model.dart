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
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      college: json['college'] as String?,
      avatar: json['avatar'] as String?,
      vehicleType: json['vehicle_type'] as String,
      destination: json['destination'] as String,
      timeDate: json['time_date'] as String,
      contactNumber: json['contact_number'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}

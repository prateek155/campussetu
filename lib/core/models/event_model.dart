class EventModel {
  final String id;
  final String name;
  final String description;
  final String place;
  final String timeDate;
  final String registrationLink;
  final String registrationMode;
  final bool isRegistered;
  final int registrationCount;
  final String? pictureUrl;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.place,
    required this.timeDate,
    required this.registrationLink,
    this.registrationMode = 'external',
    this.isRegistered = false,
    this.registrationCount = 0,
    this.pictureUrl,
    required this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      place: json['place'] ?? '',
      timeDate: json['time_date'] ?? '',
      registrationLink: json['registration_link']?.toString() ?? '',
      registrationMode: json['registration_mode'] == 'internal' ? 'internal' : 'external',
      isRegistered: json['is_registered'] == true,
      registrationCount: (json['registration_count'] as num?)?.toInt() ?? 0,
      pictureUrl: json['picture_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

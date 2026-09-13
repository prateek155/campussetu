class EventModel {
  final String id;
  final String name;
  final String description;
  final String place;
  final String timeDate;
  final String registrationLink;
  final String? pictureUrl;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.place,
    required this.timeDate,
    required this.registrationLink,
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
      registrationLink: json['registration_link'] ?? '',
      pictureUrl: json['picture_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

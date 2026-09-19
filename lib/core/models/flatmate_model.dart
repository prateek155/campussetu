class FlatmateModel {
  final String id;
  final String posterId;
  final String name;
  final String place;
  final int numPersons;
  final String contactNumber;
  final String? description;
  final String? photoUrl1;
  final String? photoUrl2;
  final String status;
  final DateTime createdAt;
  final String? posterName;
  final String? college;
  final String? avatar;

  FlatmateModel({
    required this.id,
    required this.posterId,
    required this.name,
    required this.place,
    required this.numPersons,
    required this.contactNumber,
    this.description,
    this.photoUrl1,
    this.photoUrl2,
    required this.status,
    required this.createdAt,
    this.posterName,
    this.college,
    this.avatar,
  });

  factory FlatmateModel.fromJson(Map<String, dynamic> json) {
    return FlatmateModel(
      id: json['id']?.toString() ?? '',
      posterId: json['poster_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      place: json['place']?.toString() ?? '',
      numPersons: json['num_persons'] is int ? json['num_persons'] : int.tryParse(json['num_persons']?.toString() ?? '1') ?? 1,
      contactNumber: json['contact_number']?.toString() ?? '',
      description: json['description']?.toString(),
      photoUrl1: json['photo_url_1']?.toString(),
      photoUrl2: json['photo_url_2']?.toString(),
      status: json['status']?.toString() ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      posterName: json['poster_name']?.toString() ?? json['name']?.toString(), // Fallback to flat name if poster_name is null
      college: json['college']?.toString(),
      avatar: json['avatar']?.toString(),
    );
  }
}

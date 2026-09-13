// lib/core/models/deal_model.dart
class DealModel {
  final String id;
  final String title;
  final String description;
  final String? discountCode;
  final String? bannerUrl;
  final DateTime createdAt;

  DealModel({
    required this.id,
    required this.title,
    required this.description,
    this.discountCode,
    this.bannerUrl,
    required this.createdAt,
  });

  factory DealModel.fromJson(Map<String, dynamic> json) {
    return DealModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      discountCode: json['discount_code'] as String?,
      bannerUrl: json['banner_url'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'discount_code': discountCode,
      'banner_url': bannerUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// lib/core/models/post_model.dart
import 'user_model.dart';

class PostModel {
  final String id;
  final UserModel author;
  final String content;
  final String? imageUrl;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSponsored;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.author,
    required this.content,
    this.imageUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSponsored = false,
    required this.createdAt,
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

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
        id: json['id']?.toString() ?? '',
        author: json['author'] is Map
            ? UserModel.fromJson(Map<String, dynamic>.from(json['author'] as Map))
            : UserModel.fromJson({'id': json['author_id']?.toString() ?? '', 'name': 'Unknown', 'email': '', 'created_at': DateTime.now().toIso8601String()}),
        content: json['content'] ?? '',
        imageUrl: json['image_url'],
        likesCount: _toInt(json['likes_count'] ?? json['likesCount']),
        commentsCount: _toInt(json['comments_count'] ?? json['commentsCount']),
        isLiked: _toBool(json['is_liked'] ?? json['isLiked'] ?? false),
        isSponsored: _toBool(json['is_sponsored'] ?? json['isSponsored'] ?? false),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

  PostModel copyWith({bool? isLiked, int? likesCount, int? commentsCount}) => PostModel(
        id: id,
        author: author,
        content: content,
        imageUrl: imageUrl,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        isLiked: isLiked ?? this.isLiked,
        isSponsored: isSponsored,
        createdAt: createdAt,
      );
}

class CommentModel {
  final String id;
  final UserModel author;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
        id: json['id']?.toString() ?? '',
        author: json['author'] is Map
            ? UserModel.fromJson(Map<String, dynamic>.from(json['author'] as Map))
            : UserModel.fromJson({'id': json['author_id']?.toString() ?? '', 'name': 'Unknown', 'email': '', 'created_at': DateTime.now().toIso8601String()}),
        content: json['content'] ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

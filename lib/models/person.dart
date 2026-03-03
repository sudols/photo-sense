import 'photo.dart';

class Person {
  final String id;
  final String name;
  final String faceId;
  final List<String> faceIds;
  final Map<String, dynamic>? boundingBox;
  final String? thumbnailS3Key;
  final String? thumbnailUrl;
  final bool isUnnamed;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Photo>? photos; // Only populated in detail view

  const Person({
    required this.id,
    required this.name,
    this.faceId = '',
    this.faceIds = const [],
    this.boundingBox,
    this.thumbnailS3Key,
    this.thumbnailUrl,
    this.isUnnamed = true,
    required this.createdAt,
    this.updatedAt,
    this.photos,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      name: json['name'] ?? 'Unknown Person',
      faceId: json['face_id'] ?? '',
      faceIds: List<String>.from(json['face_ids'] ?? []),
      boundingBox: json['bounding_box'] != null
          ? Map<String, dynamic>.from(json['bounding_box'])
          : null,
      thumbnailS3Key: json['thumbnail_s3_key'],
      thumbnailUrl: json['thumbnail_url'],
      isUnnamed: json['is_unnamed'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      photos: json['photos'] != null
          ? (json['photos'] as List).map((p) => Photo.fromJson(p)).toList()
          : null,
    );
  }
}

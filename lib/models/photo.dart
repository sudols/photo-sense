class Photo {
  final String id;
  final String s3Key;
  final String? url;
  final List<String> faceIds;
  final List<String> detectedText;
  final List<Map<String, dynamic>> detectedFaces;
  final int facesCount;
  final DateTime? analyzedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Photo({
    required this.id,
    required this.s3Key,
    this.url,
    this.faceIds = const [],
    this.detectedText = const [],
    this.detectedFaces = const [],
    this.facesCount = 0,
    this.analyzedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      s3Key: json['s3_key'] ?? '',
      url: json['url'],
      faceIds: List<String>.from(json['face_ids'] ?? []),
      detectedText: List<String>.from(json['detected_text'] ?? []),
      detectedFaces: List<Map<String, dynamic>>.from(
        (json['detected_faces'] ?? []).map((f) => Map<String, dynamic>.from(f)),
      ),
      facesCount: json['faces_count'] ?? 0,
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}

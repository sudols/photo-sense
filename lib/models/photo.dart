/// Photo model representing an uploaded photo with analysis results
class Photo {
  final String id;
  final String imageUrl;
  final int facesCount;
  final List<String> detectedText;
  final DateTime createdAt;

  Photo({
    required this.id,
    required this.imageUrl,
    required this.facesCount,
    required this.detectedText,
    required this.createdAt,
  });
}

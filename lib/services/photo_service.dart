import 'dart:convert';
import '../models/photo.dart';
import 'api_client.dart';

class PhotoService {
  /// Fetch all photos for the current user.
  /// Backend returns newest first, with presigned URLs.
  static Future<List<Photo>> listPhotos() async {
    final response = await ApiClient.get('/photos/');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => Photo.fromJson(j)).toList();
    }
    throw Exception('Failed to load photos (${response.statusCode})');
  }

  /// Upload a photo file.
  /// Backend handles: S3 upload + Rekognition analysis + Person creation.
  /// Returns the created Photo with presigned URL.
  static Future<Photo> uploadPhoto(String filePath) async {
    final response = await ApiClient.multipart('/photos/upload/', filePath, 'file');
    final body = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return Photo.fromJson(jsonDecode(body));
    }
    throw Exception('Upload failed (${response.statusCode})');
  }

  /// Delete a photo by ID.
  /// Backend handles: S3 deletion + orphan person cleanup.
  static Future<void> deletePhoto(String id) async {
    final response = await ApiClient.delete('/photos/$id/');
    if (response.statusCode == 204) return;
    throw Exception('Delete failed (${response.statusCode})');
  }

  /// Server-side search by detected text or person name.
  static Future<List<Photo>> search(String query) async {
    final response = await ApiClient.get(
      '/photos/search/?q=${Uri.encodeComponent(query)}',
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => Photo.fromJson(j)).toList();
    }
    throw Exception('Search failed (${response.statusCode})');
  }
}

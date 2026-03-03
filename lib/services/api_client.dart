import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();

  // --- Token management ---

  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  // --- Headers ---

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getAccessToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- HTTP methods ---

  static Future<http.Response> get(String path) async {
    return http.get(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
    );
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    return http.post(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    return http.patch(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path) async {
    return http.delete(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: await _headers(),
    );
  }

  /// Multipart file upload.
  /// [fieldName] is the form field name expected by the backend ('file').
  static Future<http.StreamedResponse> multipart(
    String path,
    String filePath,
    String fieldName,
  ) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    final request = http.MultipartRequest('POST', uri);

    final token = await getAccessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    return request.send();
  }
}

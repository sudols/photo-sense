import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_client.dart';

class AuthService {
  /// Login with email and password.
  /// Returns the user's email on success, throws on failure.
  static Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await ApiClient.saveTokens(data['access'], data['refresh']);
      return email;
    }

    final error = _extractError(response);
    throw Exception(error);
  }

  /// Register a new account.
  /// Django's RegisterView expects {email, password}.
  static Future<void> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201) return;

    final error = _extractError(response);
    throw Exception(error);
  }

  /// Clear stored tokens.
  static Future<void> logout() async {
    await ApiClient.clearTokens();
  }

  /// Check if we have a stored access token.
  static Future<bool> isLoggedIn() async {
    final token = await ApiClient.getAccessToken();
    return token != null;
  }

  static String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        // SimpleJWT returns {"detail": "..."} on error
        if (body.containsKey('detail')) return body['detail'];
        // RegisterView returns {"error": "..."}
        if (body.containsKey('error')) return body['error'];
        // Field-level errors: {"username": ["..."]}
        return body.values.first.toString();
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }
}

class AppConfig {
  // Android emulator uses 10.0.2.2 to reach host's localhost.
  // Change to your Render URL for production.
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const String apiUrl = '$baseUrl/api';
}

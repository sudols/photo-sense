class AppConfig {
  // Physical device via USB: run `adb reverse tcp:8000 tcp:8000`
  // so the device's localhost reaches the host machine.
  // Change to your production URL for deployment.
  static const String baseUrl = 'http://192.168.1.98:8000';
  static const String apiUrl = '$baseUrl/api';
}

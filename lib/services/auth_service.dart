import 'package:shared_preferences/shared_preferences.dart';

/// Handles persistent storage of the auth token and device serial
/// returned by the login API.
class AuthService {
  AuthService._();

  static const _tokenKey = 'auth_token';
  static const _serialKey = 'device_serial';

  // ── Token ──────────────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Clears both the token and serial on logout.
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_serialKey);
  }

  // ── Serial ─────────────────────────────────────────────────────────────────

  /// Saves the BLE device serial returned by the login API.
  /// Pass [null] to skip (serial is optional in the login response).
  static Future<void> saveSerial(String? serial) async {
    if (serial == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serialKey, serial);
  }

  static Future<String?> getSerial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serialKey);
  }
}
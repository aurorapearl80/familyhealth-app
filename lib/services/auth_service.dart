import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  // ── Server logout ──────────────────────────────────────────────────────────

  /// Calls `POST /api/auth-monitoring/logout` to invalidate the token
  /// on the server. Safe to ignore failures — local cleanup still proceeds.
  static Future<void> logoutFromServer() async {
    final token = await getToken();
    if (token == null) return;
    try {
      await http
          .post(
            Uri.parse('https://familywatchtoday.com/api/auth-monitoring/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[AuthService] logout API error: $e');
    }
  }

  /// Clears token, serial, and user ID on logout.
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_serialKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
  }

  // ── Role ───────────────────────────────────────────────────────────────────

  static const _roleKey = 'role_type';

  static Future<void> saveRoleType(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> getRoleType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  // ── User ID ────────────────────────────────────────────────────────────────

  static const _userIdKey = 'user_id';

  static Future<void> saveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
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
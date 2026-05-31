import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class LiveKitService {
  static const _baseUrl = 'https://familywatchtoday.com';
  static const _livekitUrl = 'wss://watch-app-3zwop4qf.livekit.cloud';

  static Map<String, dynamic> _flatten(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      // Unwrap common Laravel wrapper keys: { data: {...} } or { result: {...} }
      for (final key in ['data', 'result', 'payload']) {
        if (decoded[key] is Map<String, dynamic>) {
          return decoded[key] as Map<String, dynamic>;
        }
      }
      return decoded;
    }
    throw Exception('Unexpected response format: $decoded');
  }

  static String _extractToken(Map<String, dynamic> data) {
    final token = data['token'] as String? ??
        data['livekit_token'] as String? ??
        data['access_token'] as String? ??
        data['jwt'] as String?;
    if (token == null) throw Exception('Token key not found in: ${data.keys.toList()}');
    return token;
  }

  static String _extractUrl(Map<String, dynamic> data) =>
      data['url'] as String? ??
      data['wss_url'] as String? ??
      data['server_url'] as String? ??
      _livekitUrl;

  static String _extractRoom(Map<String, dynamic> data, String fallback) =>
      data['room'] as String? ??
      data['room_name'] as String? ??
      data['room_id'] as String? ??
      fallback;

  /// Get a token for a patient joining their own room.
  static Future<Map<String, String>> getPatientToken() async {
    final authToken = await AuthService.getToken();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/patient/livekit/token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('[LiveKitService] patient status: ${response.statusCode}');
      debugPrint('[LiveKitService] patient body: ${response.body}');

      if (response.statusCode == 200) {
        final data = _flatten(jsonDecode(response.body));
        return {
          'token': _extractToken(data),
          'url': _extractUrl(data),
          'room': _extractRoom(data, 'family-room'),
        };
      }
      throw Exception('Server returned ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('[LiveKitService] getPatientToken error: $e');
      rethrow;
    }
  }

  /// Get a token for an admin calling a specific patient.
  static Future<Map<String, String>> getAdminToken(int patientId) async {
    final authToken = await AuthService.getToken();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/patients/$patientId/livekit/token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('[LiveKitService] admin status: ${response.statusCode}');
      debugPrint('[LiveKitService] admin body: ${response.body}');

      if (response.statusCode == 200) {
        final data = _flatten(jsonDecode(response.body));
        return {
          'token': _extractToken(data),
          'url': _extractUrl(data),
          'room': _extractRoom(data, 'pm-patient-$patientId'),
        };
      }
      throw Exception('Server returned ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('[LiveKitService] getAdminToken error: $e');
      rethrow;
    }
  }

  /// Resolves the correct token based on the user role.
  static Future<Map<String, String>> getToken({int? patientId}) async {
    final role = await AuthService.getRoleType();
    if (role == 'admin' && patientId != null) {
      return getAdminToken(patientId);
    }
    return getPatientToken();
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Posts a blood pressure reading to the remote health monitoring API.
class BloodPressureApiService {
  BloodPressureApiService._();

  static const _baseUrl = 'https://familywatchtoday.com';
  static const _endpoint = '$_baseUrl/api/auth-monitoring/blood-pressures';

  /// Returns [true] if the reading was accepted by the server (2xx).
  static Future<bool> sendReading({
    required int systolic,
    required int diastolic,
    required int bpm,
    required String measuredAt,
    required String deviceId,
    required String timezone,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'measured_at': measuredAt,
              'systolic': systolic,
              'diastolic': diastolic,
              'device_id': deviceId,
              'bpm': bpm,
              'timezone': timezone,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
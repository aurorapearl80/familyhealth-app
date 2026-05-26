import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Posts a blood glucose reading to the remote health monitoring API.
class BloodGlucoseApiService {
  BloodGlucoseApiService._();

  static const _baseUrl = 'https://familywatchtoday.com';
  static const _endpoint = '$_baseUrl/api/auth-monitoring/glucose';

  /// Returns [true] if the reading was accepted by the server (2xx).
  ///
  /// [glucose] is the reading in mg/dL.
  /// [mailValue] is the reading converted to mmol/L (glucose / 18.02).
  static Future<bool> sendReading({
    required double glucose,
    required double mailValue,
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
              'glucose': glucose,
              'measured_at': measuredAt,
              'timezone': timezone,
              'mail_value': mailValue,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
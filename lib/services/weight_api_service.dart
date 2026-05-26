import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Posts a weight reading to the remote health monitoring API.
class WeightApiService {
  WeightApiService._();

  static const _baseUrl = 'https://familywatchtoday.com';
  static const _endpoint = '$_baseUrl/api/auth-monitoring/weights';

  /// Returns [true] if the reading was accepted by the server (2xx).
  static Future<bool> sendReading({
    required double weight,
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
              'weight': weight,
              'device_id': deviceId,
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
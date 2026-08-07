import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/patient_location.dart';
import 'auth_service.dart';

/// Admin-only lookup of a managed patient's latest reported GPS fix, for the
/// family map. There's no bulk endpoint — one call per patient is required.
class PatientLocationService {
  PatientLocationService._();

  static const _base = 'https://familywatchtoday.com/api';

  static Future<PatientLocation?> fetchLatest(int patientId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_base/admin/patients/$patientId/locations/latest'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];
      return data != null ? PatientLocation.fromJson(data as Map<String, dynamic>) : null;
    } catch (e) {
      debugPrint('[PatientLocationService] fetchLatest($patientId) error: $e');
      return null;
    }
  }
}

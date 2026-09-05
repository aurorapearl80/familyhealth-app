import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/appointment_time_slot.dart';
import '../models/appointment_type.dart';
import '../models/booked_appointment.dart';
import '../models/clinic_summary.dart';
import 'auth_service.dart';

/// Talks to the patient-facing appointment-booking API: get the bookable clinics, get
/// available time slots for a day, and submit a booking.
class AppointmentBookingService {
  AppointmentBookingService._();

  static const _baseUrl = 'https://familywatchtoday.com';
  static const _basePath = '$_baseUrl/api/patient/appointments';

  /// The booking flow only asks the patient to choose online/clinic/salon and a time — it
  /// doesn't expose the clinic's separate "visit type" wizard step, so all patient-portal
  /// bookings use this single default type.
  static const defaultAppointmentType = 'consultation';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Returns the selectable appointment types and bookable clinics.
  static Future<(List<AppointmentType>, List<ClinicSummary>)> fetchBookingInit() async {
    final response = await http
        .get(Uri.parse('$_basePath/booking/init'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to load clinics (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final types = (data['appointment_types'] as List)
        .map((e) => AppointmentType.fromJson(e as Map<String, dynamic>))
        .toList();
    final clinics = (data['clinics'] as List)
        .map((e) => ClinicSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    return (types, clinics);
  }

  /// Returns the bookable time slots for a clinic/location/date.
  static Future<List<AppointmentTimeSlot>> fetchAvailableSlots({
    required int clinicId,
    required String location,
    required DateTime date,
    String type = defaultAppointmentType,
  }) async {
    final uri = Uri.parse('$_basePath/available-slots').replace(queryParameters: {
      'clinic_id': '$clinicId',
      'location': location,
      'type': type,
      'date': _formatDate(date),
    });

    final response = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to load available slots (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['slots'] as List)
        .map((e) => AppointmentTimeSlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Submits the appointment. Throws on failure, including a slot that's no longer available.
  static Future<BookedAppointment> submitAppointment({
    required int clinicId,
    required String location,
    required DateTime startsAt,
    String type = defaultAppointmentType,
  }) async {
    final payload = {
      'clinic_id': clinicId,
      'location': location,
      'type': type,
      'starts_at': startsAt.toIso8601String(),
    };
    debugPrint('[AppointmentBooking] POST $_basePath payload=${jsonEncode(payload)}');

    final response = await http
        .post(
          Uri.parse(_basePath),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    debugPrint('[AppointmentBooking] response ${response.statusCode}: ${response.body}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception(data['message'] as String? ?? 'Failed to book appointment (${response.statusCode})');
    }

    return BookedAppointment.fromJson(data['appointment'] as Map<String, dynamic>);
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

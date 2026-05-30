import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Range values accepted by all vitals history endpoints.
enum VitalsRange { day, week, month, ninetyDays }

extension VitalsRangeExt on VitalsRange {
  String get apiValue {
    switch (this) {
      case VitalsRange.day:
        return 'day';
      case VitalsRange.week:
        return 'week';
      case VitalsRange.month:
        return 'month';
      case VitalsRange.ninetyDays:
        return '90days';
    }
  }

  String get label {
    switch (this) {
      case VitalsRange.day:
        return 'Day';
      case VitalsRange.week:
        return 'Week';
      case VitalsRange.month:
        return 'Month';
      case VitalsRange.ninetyDays:
        return '90 Days';
    }
  }
}

class VitalsHistoryService {
  static const _base =
      'https://familywatchtoday.com/api/auth-monitoring';

  /// Fetches a list of readings for the given [endpoint] and [range].
  /// Returns the raw `data` array from the response.
  static Future<List<Map<String, dynamic>>> fetch(
    String endpoint,
    VitalsRange range,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    try {
      final uri = Uri.parse(
          '$_base/$endpoint?range=${range.apiValue}');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['data'] is List) {
          return (body['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        // Some endpoints return the list directly
        if (body is List) {
          return body
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } else {
        debugPrint(
            '[VitalsHistory] $endpoint ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[VitalsHistory] $endpoint error: $e');
    }
    return [];
  }

  // ── Date helpers ───────────────────────────────────────────────────────────

  static String formatDate(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, $h:$m $period';
  }

  static String timeAgo(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return formatDate(raw);
  }
}

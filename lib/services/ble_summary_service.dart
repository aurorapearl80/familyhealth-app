import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Fetches the latest readings summary for a registered BLE serial from the server.
class BleSummaryService extends ChangeNotifier {
  static const _endpoint =
      'https://familywatchtoday.com/api/ble-devices/summary';

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Per-type values ────────────────────────────────────────────────────────

  double? _temperature;
  DateTime? _temperatureDate;
  int? _bloodOxygen;
  int? _bloodOxygenPulseRate;
  DateTime? _bloodOxygenDate;
  int? _bpSystolic;
  int? _bpDiastolic;
  int? _bpBpm;
  DateTime? _bpDate;
  double? _weight;
  DateTime? _weightDate;
  double? _glucose;
  double? _glucoseMailValue;
  DateTime? _glucoseDate;
  int? _heartRate;
  DateTime? _heartRateDate;

  double? get temperature => _temperature;
  DateTime? get temperatureDate => _temperatureDate;
  int? get bloodOxygen => _bloodOxygen;
  int? get bloodOxygenPulseRate => _bloodOxygenPulseRate;
  DateTime? get bloodOxygenDate => _bloodOxygenDate;
  int? get bpSystolic => _bpSystolic;
  int? get bpDiastolic => _bpDiastolic;
  int? get bpBpm => _bpBpm;
  DateTime? get bpDate => _bpDate;
  double? get weight => _weight;
  DateTime? get weightDate => _weightDate;
  double? get glucose => _glucose;
  double? get glucoseMailValue => _glucoseMailValue;
  DateTime? get glucoseDate => _glucoseDate;
  int? get heartRate => _heartRate;
  DateTime? get heartRateDate => _heartRateDate;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> fetch() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    final serial = await AuthService.getSerial();

    // Serial is required by the API — skip silently if not yet stored
    if (serial == null) {
      debugPrint('[Summary] serial not stored — skipping fetch');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uri =
          Uri.parse('$_endpoint?serial=${Uri.encodeComponent(serial)}');
      final response = await http
          .get(uri, headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          })
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          _parseResponse(body);
        }
      } else {
        _error = 'Server error (${response.statusCode})';
        debugPrint('[Summary] fetch failed ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _error = 'Network error';
      debugPrint('[Summary] fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Parsing ────────────────────────────────────────────────────────────────

  void _parseResponse(Map<String, dynamic> body) {
    final rawList = body['data'];
    if (rawList == null || rawList is! List) return;

    for (final item in rawList) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item);
      final type = entry['type'] as String?;

      final rvRaw = entry['readingValue'];
      if (rvRaw == null) continue;

      final Map<String, dynamic> rv;
      if (rvRaw is Map<String, dynamic>) {
        rv = rvRaw;
      } else if (rvRaw is Map) {
        rv = Map<String, dynamic>.from(rvRaw);
      } else {
        continue;
      }

      final dateStr = entry['deviceReadingDate'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

      switch (type) {
        case 'temperature':
          _temperature = (rv['temperature'] as num?)?.toDouble();
          _temperatureDate = date;

        case 'blood_oxygen':
          _bloodOxygen = (rv['oxygen'] as num?)?.toInt();
          _bloodOxygenPulseRate = (rv['pulseRate'] as num?)?.toInt();
          _bloodOxygenDate = date;

        case 'blood_pressure':
          _bpSystolic = (rv['systolic'] as num?)?.toInt();
          _bpDiastolic = (rv['diastolic'] as num?)?.toInt();
          _bpBpm = (rv['bpm'] as num?)?.toInt();
          _bpDate = date;

        case 'weight':
          _weight = (rv['weight'] as num?)?.toDouble();
          _weightDate = date;

        case 'blood_glucose':
          _glucose = (rv['glucose'] as num?)?.toDouble();
          _glucoseMailValue = (rv['mail_value'] as num?)?.toDouble();
          _glucoseDate = date;

        case 'heart_rate':
          _heartRate = (rv['heartRate'] as num?)?.toInt();
          _heartRateDate = date;
      }
    }

    debugPrint('[Summary] loaded — '
        'temp=$_temperature °C | spo2=$_bloodOxygen% | '
        'bp=$_bpSystolic/$_bpDiastolic | weight=$_weight kg | '
        'glucose=$_glucose | hr=$_heartRate bpm');
  }

  /// Clear all cached values (call on logout).
  void clear() {
    _temperature = null;
    _temperatureDate = null;
    _bloodOxygen = null;
    _bloodOxygenPulseRate = null;
    _bloodOxygenDate = null;
    _bpSystolic = null;
    _bpDiastolic = null;
    _bpBpm = null;
    _bpDate = null;
    _weight = null;
    _weightDate = null;
    _glucose = null;
    _glucoseMailValue = null;
    _glucoseDate = null;
    _heartRate = null;
    _heartRateDate = null;
    _error = null;
    notifyListeners();
  }
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'ble_constants.dart';
import 'health_database.dart';

/// Fetches the latest readings summary for a registered BLE serial from the
/// server and caches the result in SQLite so data is still available offline.
class BleSummaryService extends ChangeNotifier {
  static const _endpoint =
      'https://familywatchtoday.com/api/ble-devices/summary';

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Per-type vitals values ─────────────────────────────────────────────────

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

  // ── types_availability ─────────────────────────────────────────────────────
  // Default to true so everything is shown until the API says otherwise.

  bool _availTemperature = true;
  bool _availBloodOxygen = true;
  bool _availBloodPressure = true;
  bool _availWeight = true;
  bool _availBloodGlucose = true;
  bool _availElectrocardiogram = true;

  // ── Vitals getters ─────────────────────────────────────────────────────────

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

  // ── types_availability getters ─────────────────────────────────────────────

  bool get isTemperatureEnabled => _availTemperature;
  bool get isBloodOxygenEnabled => _availBloodOxygen;
  bool get isBloodPressureEnabled => _availBloodPressure;
  bool get isWeightEnabled => _availWeight;
  bool get isBloodGlucoseEnabled => _availBloodGlucose;
  bool get isElectrocardiogramEnabled => _availElectrocardiogram;

  /// Returns whether a given BLE device type is enabled for this account.
  bool isDeviceTypeEnabled(BleDeviceType type) {
    switch (type) {
      case BleDeviceType.temperature:
        return _availTemperature;
      case BleDeviceType.bloodOxygen:
        return _availBloodOxygen;
      case BleDeviceType.bloodPressure:
        return _availBloodPressure;
      case BleDeviceType.weight:
        return _availWeight;
      case BleDeviceType.bloodGlucose:
        return _availBloodGlucose;
      case BleDeviceType.unknown:
        return true;
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> fetch() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    final serial = await AuthService.getSerial();

    // Pre-populate UI from cache while network request is in flight.
    await _loadFromCache();

    if (serial == null) {
      debugPrint('[Summary] serial not stored — showing cached data');
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners(); // Show cached data + loading indicator

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
          await _saveToCache();
        }
      } else {
        _error = 'Server error (${response.statusCode})';
        debugPrint(
            '[Summary] fetch failed ${response.statusCode}: ${response.body}');
        // Cached values already loaded — keep showing them.
      }
    } catch (e) {
      _error = 'Network error';
      debugPrint('[Summary] fetch error: $e');
      // Cached values already loaded — keep showing them.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Parsing ────────────────────────────────────────────────────────────────

  void _parseResponse(Map<String, dynamic> body) {
    // Parse types_availability first
    final avail = body['types_availability'];
    if (avail is Map) {
      _availBloodGlucose = avail['blood_glucose'] == true;
      _availBloodPressure = avail['blood_pressure'] == true;
      _availWeight = avail['weight'] == true;
      _availBloodOxygen = avail['blood_oxygen'] == true;
      _availElectrocardiogram = avail['electrocardiogram'] == true;
      _availTemperature = avail['temperature'] == true;
    }

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
        'glucose=$_glucose | hr=$_heartRate bpm | '
        'avail: temp=$_availTemperature spo2=$_availBloodOxygen '
        'bp=$_availBloodPressure wt=$_availWeight '
        'glu=$_availBloodGlucose ecg=$_availElectrocardiogram');
  }

  // ── SQLite cache ──────────────────────────────────────────────────────────

  Future<void> _saveToCache() async {
    try {
      await HealthDatabase.saveSummaryCache(
        temperature: _temperature,
        temperatureDate: _temperatureDate?.toIso8601String(),
        bloodOxygen: _bloodOxygen,
        bloodOxygenPulseRate: _bloodOxygenPulseRate,
        bloodOxygenDate: _bloodOxygenDate?.toIso8601String(),
        bpSystolic: _bpSystolic,
        bpDiastolic: _bpDiastolic,
        bpBpm: _bpBpm,
        bpDate: _bpDate?.toIso8601String(),
        weight: _weight,
        weightDate: _weightDate?.toIso8601String(),
        glucose: _glucose,
        glucoseMailValue: _glucoseMailValue,
        glucoseDate: _glucoseDate?.toIso8601String(),
        heartRate: _heartRate,
        heartRateDate: _heartRateDate?.toIso8601String(),
        availTemperature: _availTemperature,
        availBloodOxygen: _availBloodOxygen,
        availBloodPressure: _availBloodPressure,
        availWeight: _availWeight,
        availBloodGlucose: _availBloodGlucose,
        availElectrocardiogram: _availElectrocardiogram,
      );
      debugPrint('[Summary] saved to SQLite cache');
    } catch (e) {
      debugPrint('[Summary] cache save failed: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final row = await HealthDatabase.loadSummaryCache();
      if (row == null) {
        debugPrint('[Summary] no SQLite cache found');
        return;
      }

      _temperature = row['temperature'] as double?;
      _temperatureDate = _parseDate(row['temperature_date']);
      _bloodOxygen = row['blood_oxygen'] as int?;
      _bloodOxygenPulseRate = row['blood_oxygen_pulse_rate'] as int?;
      _bloodOxygenDate = _parseDate(row['blood_oxygen_date']);
      _bpSystolic = row['bp_systolic'] as int?;
      _bpDiastolic = row['bp_diastolic'] as int?;
      _bpBpm = row['bp_bpm'] as int?;
      _bpDate = _parseDate(row['bp_date']);
      _weight = row['weight'] as double?;
      _weightDate = _parseDate(row['weight_date']);
      _glucose = row['glucose'] as double?;
      _glucoseMailValue = row['glucose_mail_value'] as double?;
      _glucoseDate = _parseDate(row['glucose_date']);
      _heartRate = row['heart_rate'] as int?;
      _heartRateDate = _parseDate(row['heart_rate_date']);

      _availTemperature = (row['avail_temperature'] as int? ?? 1) == 1;
      _availBloodOxygen = (row['avail_blood_oxygen'] as int? ?? 1) == 1;
      _availBloodPressure = (row['avail_blood_pressure'] as int? ?? 1) == 1;
      _availWeight = (row['avail_weight'] as int? ?? 1) == 1;
      _availBloodGlucose = (row['avail_blood_glucose'] as int? ?? 1) == 1;
      _availElectrocardiogram =
          (row['avail_electrocardiogram'] as int? ?? 1) == 1;

      debugPrint('[Summary] restored from SQLite cache — '
          'temp=$_temperature | spo2=$_bloodOxygen | bp=$_bpSystolic/$_bpDiastolic');
    } catch (e) {
      debugPrint('[Summary] cache load failed: $e');
    }
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw as String);
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

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
    // Reset availability to true (show all) after logout
    _availTemperature = true;
    _availBloodOxygen = true;
    _availBloodPressure = true;
    _availWeight = true;
    _availBloodGlucose = true;
    _availElectrocardiogram = true;
    notifyListeners();
  }
}
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_constants.dart';
import 'blood_pressure_api_service.dart';
import 'oximeter_api_service.dart';

void _log(String msg) => debugPrint('[BPWatch] $msg');

/// Handles the Urion "Blood Pressure Watch" (advertised name e.g. "U19M_ZX_1653").
///
/// Ported from the Android BloodPressureWatchHandler.java in the sibling
/// SmartHealthBLEAI-team repo, adapted to this app's architecture:
/// - Reuses the existing bloodPressure/bloodOxygen device_id + REST endpoints
///   (BleConstants.deviceBp / deviceOximeter via BloodPressureApiService /
///   OximeterApiService) rather than provisioning new backend catalog entries.
/// - Posts each historical record directly to those endpoints instead of routing
///   through DeviceReadings/BleScanService listeners: those listeners only fire
///   while the matching vitals screen happens to be mounted, which would silently
///   drop a background historical sync whenever the user isn't on that screen.
/// - Only implements BP history (0x14/0x94) and automatic blood-oxygen history
///   (0x2D/0xAD). Automatic heart-rate history (0x15/0x95) is deliberately not
///   implemented yet -- there is no standalone heart-rate endpoint on this backend.
///
/// Protocol: single custom service (Nordic-UART-style write/notify pair). BP history
/// is answered by one 16-byte response frame per stored record, terminated by a
/// sentinel timestamp of 0xFFFFFFFF or a 0x94 failure frame. Blood-oxygen history is
/// a "day history": an index frame (packet count + interval minutes) followed by N
/// data frames (packet 1 embeds a base timestamp + 9 slot values, packets 2..N carry
/// 13 sequential slot values each with no timestamp of their own).
class BpWatchService {
  BpWatchService(this.deviceName, {this.onSyncCompleted});

  final String deviceName;

  /// Called after a history sync concludes (BP end-of-history, or SpO2
  /// finalized/no-data), so the caller can refresh account-level summaries
  /// (e.g. BleSummaryService) without waiting for a manual pull-to-refresh.
  final VoidCallback? onSyncCompleted;

  static const String _timezone = 'Asia/Manila';
  static const int _historyRequestCount = 20;
  static const int _spo2MinValid = 70;
  static const int _spo2MaxValid = 100;
  static const int _bpSysMin = 40, _bpSysMax = 260;
  static const int _bpDiaMin = 30, _bpDiaMax = 180;
  static const int _bpPulseMin = 30, _bpPulseMax = 220;

  // The watch's timestamp fields are the true UTC instant plus 8 hours (its RTC stores
  // Asia/Manila wall-clock time but transmits it as if it were a raw UTC unix epoch).
  // Decoding: naively parsing raw seconds as a UTC epoch directly yields the correct
  // Manila wall-clock date/time fields (no extra math needed for display). Encoding a
  // request for "now": take the true UTC instant and add 8h before sending.
  static const int _tzCorrectionSeconds = 8 * 3600;

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  Timer? _bpRequestTimer;
  Timer? _spo2RequestTimer;
  Timer? _pushRepollTimer;

  // SpO2 multi-packet reassembly state (reset per index packet).
  int _spo2ExpectedDataPackets = -1;
  int _spo2IntervalMinutes = 60;
  int? _spo2BaseRawTimestamp;
  List<int>? _spo2SlotValues;

  // Dedup key = "type|measuredAt". Persisted to SharedPreferences (scoped to the
  // current Manila calendar day) so an app restart doesn't re-walk the watch's
  // history and re-POST the whole day's readings as duplicates -- an in-memory-only
  // set (as used on the Android side, where the host process effectively never
  // restarts) isn't safe here since a phone app gets killed/restarted far more often.
  static final Set<String> _processedKeys = {};
  static const String _prefsKeyProcessed = 'bp_watch_processed_keys';
  static const String _prefsKeyProcessedDate = 'bp_watch_processed_keys_date';
  static bool _persistedLoaded = false;

  static Future<void> _ensurePersistedLoaded() async {
    if (_persistedLoaded) return;
    _persistedLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString(_prefsKeyProcessedDate);
      final todayKey = _todayManilaDateKey();
      if (storedDate == todayKey) {
        _processedKeys.addAll(prefs.getStringList(_prefsKeyProcessed) ?? []);
        _log('Loaded ${_processedKeys.length} persisted dedup key(s) for $todayKey');
      } else {
        // Different day (or first run ever) -- old entries are no longer relevant.
        await prefs.remove(_prefsKeyProcessed);
        await prefs.setString(_prefsKeyProcessedDate, todayKey);
      }
    } catch (e) {
      _log('Failed to load persisted dedup keys: $e');
    }
  }

  static Future<void> _persistProcessedKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKeyProcessed, _processedKeys.toList());
      await prefs.setString(_prefsKeyProcessedDate, _todayManilaDateKey());
    } catch (e) {
      _log('Failed to persist dedup keys: $e');
    }
  }

  static String _todayManilaDateKey() {
    final nowManila = DateTime.now().toUtc().add(const Duration(hours: 8));
    final y = nowManila.year.toString().padLeft(4, '0');
    final m = nowManila.month.toString().padLeft(2, '0');
    final d = nowManila.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool isBpWatchName(String name) => name.toLowerCase().contains('u19m');

  Future<void> onServicesDiscovered(
    BluetoothDevice device,
    List<BluetoothService> services,
  ) async {
    _log('onServicesDiscovered for "$deviceName"');
    await _ensurePersistedLoaded();

    BluetoothService? service;
    for (final s in services) {
      if (s.uuid.str.toLowerCase() == BleConstants.bpWatchServiceUuid) {
        service = s;
        break;
      }
    }
    if (service == null) {
      _log('Expected service ${BleConstants.bpWatchServiceUuid} not found.');
      return;
    }

    for (final c in service.characteristics) {
      final uuid = c.uuid.str.toLowerCase();
      if (uuid == BleConstants.bpWatchWriteCharUuid) _writeChar = c;
      if (uuid == BleConstants.bpWatchNotifyCharUuid) _notifyChar = c;
    }

    if (_notifyChar == null || _writeChar == null) {
      _log('Write or notify characteristic not found (write=$_writeChar notify=$_notifyChar)');
      return;
    }

    try {
      await _notifyChar!.setNotifyValue(true);
    } catch (e) {
      _log('setNotifyValue failed: $e');
    }

    // Staggered so the two protocols' responses (sharing one notify characteristic)
    // don't interleave while we're reassembling either one.
    _bpRequestTimer?.cancel();
    _bpRequestTimer = Timer(const Duration(milliseconds: 500), _requestBpHistory);
    _spo2RequestTimer?.cancel();
    _spo2RequestTimer = Timer(const Duration(milliseconds: 3000), _requestSpo2History);
  }

  void onDisconnected() {
    _bpRequestTimer?.cancel();
    _spo2RequestTimer?.cancel();
    _pushRepollTimer?.cancel();
    _writeChar = null;
    _notifyChar = null;
    _resetSpo2Session();
  }

  void handleData(List<int> data) {
    if (data.length != 16) {
      _log('Unexpected frame length ${data.length}, ignoring. raw=${_hex(data)}');
      return;
    }

    final expected = _checksum8(data, 15);
    final actual = data[15];
    if (expected != actual) {
      _log('Checksum mismatch (expected=${expected.toRadixString(16)} '
          'actual=${actual.toRadixString(16)}) frame=${_hex(data)} -- continuing anyway.');
    }

    final header = data[0] & 0xff;
    switch (header) {
      case 0x14:
        _processBpFrame(data);
        return;
      case 0x94:
        _log('Watch reported BP validation/execution failure (0x94).');
        return;
      case 0x2d:
        _processSpo2Frame(data);
        return;
      case 0xad:
        _log('Watch reported blood-oxygen validation/execution failure (0xAD).');
        _resetSpo2Session();
        return;
      default:
        _log('Unrecognized header 0x${header.toRadixString(16)}, '
            'treating as a possible new-data push and scheduling a re-poll. frame=${_hex(data)}');
        _pushRepollTimer?.cancel();
        _pushRepollTimer = Timer(const Duration(milliseconds: 800), () {
          _requestBpHistory();
          Timer(const Duration(milliseconds: 1500), _requestSpo2History);
        });
    }
  }

  // ── Blood pressure history (0x14/0x94) ──────────────────────────────────────

  void _requestBpHistory() {
    final cmd = List<int>.filled(16, 0);
    cmd[0] = 0x14;
    // timestamp=0, direction=0 (backward from newest), count=_historyRequestCount
    cmd[6] = _historyRequestCount & 0xff;
    cmd[15] = _checksum8(cmd, 15);
    _log('requestBpHistory: sending ${_hex(cmd)}');
    _write(cmd);
  }

  void _processBpFrame(List<int> data) {
    final rawTs = _getUint32LE(data, 1);
    if (rawTs == 0xFFFFFFFF) {
      _log('BP end-of-history sentinel received.');
      onSyncCompleted?.call();
      return;
    }

    final diastolic = data[5] & 0xff;
    final systolic = data[6] & 0xff;
    final pulse = data[7] & 0xff;

    if (!(systolic >= _bpSysMin &&
        systolic <= _bpSysMax &&
        diastolic >= _bpDiaMin &&
        diastolic <= _bpDiaMax &&
        pulse >= _bpPulseMin &&
        pulse <= _bpPulseMax &&
        systolic > diastolic)) {
      _log('BP reading out of range, discarding. sys=$systolic dia=$diastolic pulse=$pulse');
      return;
    }

    final manila = _toManilaWallClock(rawTs);
    _log('BP parsed sys=$systolic dia=$diastolic pulse=$pulse -> ${manila.toIso8601String()}');

    if (!_isToday(manila)) {
      _log('BP record ${manila.toIso8601String()} is not from today, stopping walk early.');
      return;
    }

    final measuredAt = _formatMeasuredAt(manila);
    final key = 'bp|$measuredAt';
    if (_processedKeys.contains(key)) {
      _log('Duplicate BP reading for $measuredAt, skipping.');
      return;
    }
    _processedKeys.add(key);
    unawaited(_persistProcessedKeys());

    BloodPressureApiService.sendReading(
      systolic: systolic,
      diastolic: diastolic,
      bpm: pulse,
      measuredAt: measuredAt,
      deviceId: BleConstants.deviceBp,
      timezone: _timezone,
    ).then((ok) => _log('BP sync $measuredAt -> ${ok ? "success" : "failed"}'));
  }

  // ── Automatic blood-oxygen history (0x2D/0xAD) ──────────────────────────────

  void _requestSpo2History() {
    final deviceTs = _buildDeviceTimestamp();
    final cmd = List<int>.filled(16, 0);
    cmd[0] = 0x2d;
    cmd[1] = deviceTs & 0xff;
    cmd[2] = (deviceTs >> 8) & 0xff;
    cmd[3] = (deviceTs >> 16) & 0xff;
    cmd[4] = (deviceTs >> 24) & 0xff;
    cmd[15] = _checksum8(cmd, 15);
    _log('requestSpo2History: sending ${_hex(cmd)}');
    _write(cmd);
  }

  void _processSpo2Frame(List<int> data) {
    final seq = data[1] & 0xff;

    if (seq == 0xff) {
      _log('No blood-oxygen data available for the requested day.');
      _resetSpo2Session();
      onSyncCompleted?.call();
      return;
    }

    if (seq == 0x00) {
      final totalPackets = data[2] & 0xff;
      final interval = data[3] & 0xff;
      final dataPackets = totalPackets - 1;
      if (dataPackets <= 0 || interval <= 0) {
        _log('Invalid index packet (totalPackets=$totalPackets interval=$interval), ignoring.');
        _resetSpo2Session();
        return;
      }
      _spo2ExpectedDataPackets = dataPackets;
      _spo2IntervalMinutes = interval;
      _spo2BaseRawTimestamp = null;
      final totalSlots = 9 + (dataPackets - 1) * 13;
      _spo2SlotValues = List<int>.filled(totalSlots, -1);
      _log('Index packet -> dataPackets=$dataPackets intervalMin=$interval totalSlots=$totalSlots');
      return;
    }

    final slots = _spo2SlotValues;
    if (slots == null) {
      _log('Data packet seq=$seq received before an index packet, ignoring.');
      return;
    }

    if (seq == 1) {
      _spo2BaseRawTimestamp = _getUint32LE(data, 2);
      for (var i = 0; i < 9; i++) {
        slots[i] = data[6 + i] & 0xff;
      }
      _log('Packet 1/$_spo2ExpectedDataPackets baseRawTs=$_spo2BaseRawTimestamp');
    } else {
      final baseSlotIndex = 9 + (seq - 2) * 13;
      for (var i = 0; i < 13; i++) {
        final slotIndex = baseSlotIndex + i;
        if (slotIndex >= slots.length) break;
        slots[slotIndex] = data[2 + i] & 0xff;
      }
      _log('Packet $seq/$_spo2ExpectedDataPackets slots[$baseSlotIndex..${baseSlotIndex + 12}]');
    }

    if (seq == _spo2ExpectedDataPackets) {
      _log('Last data packet received, finalizing blood-oxygen readings.');
      _finalizeSpo2Data();
    }
  }

  void _finalizeSpo2Data() {
    final slots = _spo2SlotValues;
    final baseRawTs = _spo2BaseRawTimestamp;
    if (slots == null || baseRawTs == null) {
      _log('Incomplete blood-oxygen session (missing packet 1?), discarding.');
      _resetSpo2Session();
      return;
    }

    var added = 0;
    for (var slot = 0; slot < slots.length; slot++) {
      final spo2 = slots[slot];
      if (spo2 <= 0) continue; // -1 = never received, 0 = vendor's "missing value" sentinel
      if (spo2 < _spo2MinValid || spo2 > _spo2MaxValid) {
        _log('Slot $slot value $spo2 out of range, discarding.');
        continue;
      }

      final slotRawTs = baseRawTs + slot * _spo2IntervalMinutes * 60;
      final manila = _toManilaWallClock(slotRawTs);
      if (!_isToday(manila)) continue;

      final measuredAt = _formatMeasuredAt(manila);
      final key = 'spo2|$measuredAt';
      if (_processedKeys.contains(key)) continue;
      _processedKeys.add(key);
      unawaited(_persistProcessedKeys());

      OximeterApiService.sendReading(
        oxygen: spo2,
        pulseRate: 0,
        measuredAt: measuredAt,
        deviceId: BleConstants.deviceOximeter,
        timezone: _timezone,
      ).then((ok) => _log('SpO2 sync $measuredAt -> ${ok ? "success" : "failed"}'));
      added++;
    }

    _log('Added $added new blood-oxygen reading(s) out of ${slots.length} slot(s).');
    _resetSpo2Session();
    onSyncCompleted?.call();
  }

  void _resetSpo2Session() {
    _spo2ExpectedDataPackets = -1;
    _spo2IntervalMinutes = 60;
    _spo2BaseRawTimestamp = null;
    _spo2SlotValues = null;
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────

  Future<void> _write(List<int> cmd) async {
    final char = _writeChar;
    if (char == null) {
      _log('No write characteristic available, dropping command ${_hex(cmd)}');
      return;
    }
    try {
      await char.write(cmd, withoutResponse: false);
    } catch (e) {
      _log('Write failed: $e');
    }
  }

  /// Encodes "now" the same way the watch does: true UTC seconds + 8h (see class doc).
  int _buildDeviceTimestamp() {
    final trueUtcNowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return trueUtcNowSeconds + _tzCorrectionSeconds;
  }

  /// Naively parsing the raw seconds as a UTC epoch directly yields the correct
  /// Asia/Manila wall-clock date/time fields (see class doc for why).
  DateTime _toManilaWallClock(int rawUnsignedEpochSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(rawUnsignedEpochSeconds * 1000, isUtc: true);

  bool _isToday(DateTime manilaWallClock) {
    final nowManila = DateTime.now().toUtc().add(const Duration(hours: 8));
    return manilaWallClock.year == nowManila.year &&
        manilaWallClock.month == nowManila.month &&
        manilaWallClock.day == nowManila.day;
  }

  String _formatMeasuredAt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  int _getUint32LE(List<int> data, int offset) {
    return (data[offset] & 0xff) |
        ((data[offset + 1] & 0xff) << 8) |
        ((data[offset + 2] & 0xff) << 16) |
        ((data[offset + 3] & 0xff) << 24);
  }

  int _checksum8(List<int> data, int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += data[i] & 0xff;
    }
    return sum & 0xff;
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}

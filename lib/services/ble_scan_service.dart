import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/ble_device_info.dart';
import '../models/device_readings.dart';
import 'ble_constants.dart';
import 'ble_parsers.dart';
import 'body_composition_calc.dart';
import 'stable_value_detector.dart';

void _log(String msg) => debugPrint('[BLE] $msg');

/// Flutter port of Android BleScanService — scans, connects, and parses BLE health devices.
class BleScanService extends ChangeNotifier {
  BleScanService();

  DeviceReadings _readings = const DeviceReadings();
  final Map<String, BleDeviceInfo> _devices = {};
  final Map<String, BleDeviceInfo> _registeredByDeviceId = {};
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _wasEverConnected = false;
  String? _connectingName;
  String? _connectingAddress;
  int _connectRetry = 0;
  String _status = 'Initializing BLE...';
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  Timer? _scanWindowTimer;
  Timer? _connectTimeoutTimer;
  BluetoothDevice? _connectedDevice;

  final IntPairStableDetector _oximeterDetector = IntPairStableDetector(
    stableDelayMs: BleConstants.stableDelayMs,
  );
  final DoubleStableDetector _weightDetector = DoubleStableDetector(
    stableDelayMs: BleConstants.stableDelayMs,
    tolerance: BleConstants.weightTolerance,
  );

  double _lastSentWeight = double.nan;
  int _lastSentWeightAtMs = 0;
  int? _lastImpedance; // last valid impedance reading from scale advertisement

  // Track devices already printed this scan cycle to reduce log noise
  final Set<String> _loggedThisCycle = {};

  DeviceReadings get readings => _readings;
  List<BleDeviceInfo> get devices => _devices.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  List<BleDeviceInfo> get registeredDevices =>
      BleConstants.registeredDevices.map((registered) {
        final live = _registeredByDeviceId[registered.deviceId];
        return live ?? BleDeviceInfo.fromRegistered(registered);
      }).toList();
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  String get status => _status;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _log('initialize() called');
    _seedRegisteredDevices();
    _oximeterDetector.onStable = _onOximeterStable;
    _weightDetector.onStable = _onWeightStable;

    final granted = await _ensurePermissions();
    _log('Permissions granted: $granted');
    if (!granted) {
      _status = 'Bluetooth permissions required';
      notifyListeners();
      return;
    }

    final supported = await FlutterBluePlus.isSupported;
    _log('BLE supported: $supported');
    if (!supported) {
      _status = 'Bluetooth LE not supported';
      notifyListeners();
      return;
    }

    _scanSub ??= FlutterBluePlus.onScanResults.listen(_onScanResults);

    FlutterBluePlus.adapterState.listen((state) {
      _log('Adapter state changed: $state');
      if (state == BluetoothAdapterState.on) {
        _startScanCycle();
      } else {
        _status = 'Bluetooth is off';
        _stopScan();
        notifyListeners();
      }
    });

    final adapterState = await FlutterBluePlus.adapterState.first;
    _log('Initial adapter state: $adapterState');
    if (adapterState == BluetoothAdapterState.on) {
      _startScanCycle();
    } else {
      _status = 'Turn on Bluetooth to scan devices';
      notifyListeners();
    }
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;

    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    final statuses = await permissions.request();
    for (final entry in statuses.entries) {
      _log('Permission ${entry.key}: ${entry.value}');
    }
    return statuses.values.every((s) => s.isGranted);
  }

  void _startScanCycle() {
    if (_isScanning || _isConnecting) {
      _log('_startScanCycle skipped — isScanning=$_isScanning isConnecting=$_isConnecting');
      return;
    }
    _loggedThisCycle.clear();
    _log('Starting new scan cycle');
    _startScan();
    _scanWindowTimer?.cancel();
    _scanWindowTimer = Timer(
      const Duration(milliseconds: BleConstants.scanWindowMs),
      () {
        _stopScan();
        Future.delayed(
          const Duration(milliseconds: BleConstants.scanPauseMs),
          _startScanCycle,
        );
      },
    );
  }

  Future<void> _startScan() async {
    if (_isConnecting) return;
    _isScanning = true;
    _status = 'Scanning for health devices...';
    notifyListeners();
    _log('startScan() called (window=${BleConstants.scanWindowMs}ms)');
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(milliseconds: BleConstants.scanWindowMs),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      _log('startScan error: $e');
      _isScanning = false;
      _status = 'Scan failed: $e';
      notifyListeners();
    }
  }

  Future<void> _stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
    _isScanning = false;
  }

  void _onScanResults(List<ScanResult> results) {
    // Log ALL devices seen (once per cycle) so we can spot the real name
    for (final result in results) {
      final name = result.device.platformName;
      final addr = result.device.remoteId.str;
      final rssi = result.rssi;
      if (name.isNotEmpty && !_loggedThisCycle.contains(addr)) {
        _loggedThisCycle.add(addr);
        _log('SCAN FOUND  name="$name"  addr=$addr  rssi=$rssi');
      }
    }

    for (final result in results) {
      final name = result.device.platformName;
      if (name.isEmpty) continue;
      if (!_isKnownDevice(name)) continue;

      final address = result.device.remoteId.str;
      _upsertDevice(name, address, connected: _connectingAddress == address);

      if (name.contains('JPD Scale')) {
        _markRegisteredSeen(BleDeviceType.weight, connected: true);
        final scanBytes = _extractAdvertisementBytes(result);
        _log('JPD Scale advert bytes: $scanBytes');
        if (scanBytes != null) {
          final weight = BleParsers.parseWeightFromAdvertisement(scanBytes);
          _log('JPD Scale weight parse: $weight kg');
          if (weight != null) {
            _weightDetector.update(weight);
          }
          final imp = BleParsers.parseImpedanceFromAdvertisement(scanBytes);
          if (imp != null) {
            _lastImpedance = imp;
            _log('JPD Scale impedance: $imp ohms');
          }
        }
        continue;
      }

      if (_isConnecting && _connectingName?.toLowerCase() == name.toLowerCase()) {
        continue;
      }
      if (_isConnecting) continue;

      _log('Known device selected for connect: "$name" @ $address');
      _isConnecting = true;
      _connectingName = name;
      _connectingAddress = address;
      _stopScan();
      _connectToDevice(result.device, name);
      break;
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device, String name) async {
    _log('Connecting to "$name" @ ${device.remoteId.str}');
    _status = 'Connecting to $name...';
    notifyListeners();

    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = Timer(
      const Duration(milliseconds: BleConstants.connectTimeoutMs),
      () {
        _log('Connect timeout for "$name"');
        _handleConnectFailure(retry: false);
      },
    );

    try {
      await _connectionSub?.cancel();
      _wasEverConnected = false;
      _connectionSub = device.connectionState.listen((state) async {
        _log('Connection state for "$name": $state');
        if (state == BluetoothConnectionState.connected) {
          _wasEverConnected = true;
          _connectTimeoutTimer?.cancel();
          _connectRetry = 0;
          _connectedDevice = device;
          _upsertDevice(name, device.remoteId.str, connected: true);
          _markRegisteredSeen(BleDeviceInfo.typeFromName(name), connected: true);
          _status = 'Connected to $name';
          notifyListeners();
          await _setupNotifications(device, name);
        } else if (state == BluetoothConnectionState.disconnected) {
          _log('Disconnected from "$name" (wasConnected=$_wasEverConnected)');
          // Only treat as a clean disconnect if we had reached connected state.
          // If connect() hasn't returned yet, let _handleConnectFailure handle it.
          if (_wasEverConnected) {
            _handleDisconnect(name, device.remoteId.str);
          }
        }
      });

      await device.connect(autoConnect: false, mtu: null);
    } catch (e) {
      _log('device.connect() threw: $e');
      _handleConnectFailure(retry: true);
    }
  }

  Future<void> _setupNotifications(BluetoothDevice device, String name) async {
    _log('Discovering services for "$name"...');
    try {
      final services = await device.discoverServices();
      _log('"$name" has ${services.length} services');
      for (final service in services) {
        _log('  Service: ${service.uuid}');
        for (final characteristic in service.characteristics) {
          final props = characteristic.properties;
          _log('    Char: ${characteristic.uuid}  '
              'notify=${props.notify} indicate=${props.indicate} '
              'read=${props.read} write=${props.write}');
          if (props.notify || props.indicate) {
            try {
              await characteristic.setNotifyValue(true);
              _log('    -> Subscribed to ${characteristic.uuid}');
              characteristic.onValueReceived.listen((value) {
                _log('RAW DATA from "$name" char=${characteristic.uuid} '
                    'len=${value.length} bytes=${value.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');
                _handleCharacteristicData(name, value);
              });
            } catch (e) {
              _log('    -> setNotifyValue failed: $e');
            }
          } else if (props.read && !name.contains('My Oximeter')) {
            try {
              final val = await characteristic.read();
              _log('    -> Read: ${val.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');
              _handleCharacteristicData(name, characteristic.lastValue);
            } catch (e) {
              _log('    -> Read failed: $e');
            }
          }
        }
      }
      _status = 'Listening to $name';
      notifyListeners();
    } catch (e) {
      _log('discoverServices failed for "$name": $e');
      _handleConnectFailure(retry: true);
    }
  }

  void _handleCharacteristicData(String deviceName, List<int> data) {
    if (data.isEmpty) return;

    if (deviceName.contains('EMPECS')) {
      _log('GLUCOSE raw len=${data.length}: ${_hex(data)}');
      if (data.length == 15) {
        final reading = BleParsers.parseGlucose(data);
        if (reading != null) {
          _log('GLUCOSE parsed: ${reading.glucose} ${reading.unit}');
          _applyReading(
            kind: BleReadingKind.bloodGlucose,
            deviceName: deviceName,
            status: 'Glucose: ${reading.glucose} ${reading.unit}',
            update: (r) => r.copyWith(
              bloodGlucose: reading.glucose,
              glucoseUnit: reading.unit,
            ),
          );
        } else {
          _log('GLUCOSE parse returned null (flags/data issue)');
        }
      } else {
        _log('GLUCOSE skipped — expected 15 bytes, got ${data.length}');
      }
      return;
    }

    if (deviceName.contains('Thermometer') || deviceName.contains('thermometer')) {
      _log('TEMP raw len=${data.length}: ${_hex(data)}');
      if (data.length == 5) {
        final typeCode = data[1] & 0xff;
        _log('TEMP typeCode=$typeCode (0x${typeCode.toRadixString(16)})');
        final reading = BleParsers.parseThermometer(data);
        if (reading != null) {
          _log('TEMP parsed: ${reading.celsius.toStringAsFixed(2)}°C');
          _applyReading(
            kind: BleReadingKind.temperature,
            deviceName: deviceName,
            status: 'Temperature: ${reading.celsius.toStringAsFixed(1)}°C',
            update: (r) => r.copyWith(temperature: reading.celsius),
          );
        } else {
          _log('TEMP parse returned null — typeCode $typeCode not in [22,33,55]');
        }
      } else {
        _log('TEMP skipped — expected 5 bytes, got ${data.length}');
      }
      return;
    }

    if (deviceName.contains('JPD') && !deviceName.contains('Scale')) {
      if (data.length == 7) {
        // Progress packet during cuff inflation: fd fd fb 00 PP 0d 0a — skip silently
        if (data[0] == 0xfd && data[1] == 0xfd && data[2] == 0xfb) return;
        // Any other 7-byte packet is the final result: fd fd f4 SYS DIA PUL 0d 0a
        final sys = data[3] & 0xff;
        final dia = data[4] & 0xff;
        final pul = data[5] & 0xff;
        _log('BP 7-byte result: ${_hex(data)} → sys=$sys dia=$dia pulse=$pul');
        if (sys > 0 && dia > 0 && pul > 0) {
          _log('BP parsed: $sys/$dia pulse=$pul');
          _applyReading(
            kind: BleReadingKind.bloodPressure,
            deviceName: deviceName,
            status: 'BP: $sys/$dia ($pul bpm)',
            update: (r) => r.copyWith(
              systolic: sys,
              diastolic: dia,
              pulseRate: pul,
              heartRate: pul,
            ),
          );
        } else {
          _log('BP 7-byte result: invalid values, ignoring');
        }
        return;
      }
      if (data.length == 8) {
        _log('BP raw len=8: ${_hex(data)}');
        final reading = BleParsers.parseBloodPressure(data);
        if (reading != null && !reading.isPartial && reading.systolic > 0) {
          _log('BP parsed: ${reading.systolic}/${reading.diastolic} pulse=${reading.pulseRate}');
          _applyReading(
            kind: BleReadingKind.bloodPressure,
            deviceName: deviceName,
            status:
                'BP: ${reading.systolic}/${reading.diastolic} (${reading.pulseRate} bpm)',
            update: (r) => r.copyWith(
              systolic: reading.systolic,
              diastolic: reading.diastolic,
              pulseRate: reading.pulseRate,
              heartRate: reading.pulseRate,
            ),
          );
        } else {
          _log('BP parse: partial=${reading?.isPartial} systolic=${reading?.systolic}');
        }
        return;
      }
      _log('BP unexpected len=${data.length}: ${_hex(data)}');
      return;
    }

    if (deviceName.contains('Oximeter') || deviceName.contains('oximeter')) {
      _log('OXIMETER raw len=${data.length}: ${_hex(data)}');
      final reading = BleParsers.parseOximeter(data);
      if (reading != null) {
        _log('OXIMETER parsed: spo2=${reading.spo2}% pulse=${reading.pulseRate}');
        _oximeterDetector.update(reading.pulseRate, reading.spo2);
      } else {
        _log('OXIMETER parse returned null');
      }
      return;
    }

    _log('UNHANDLED data from "$deviceName" len=${data.length}: ${_hex(data)}');
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  void _onOximeterStable(int pulseRate, int spo2) {
    _log('OXIMETER stable: spo2=$spo2% pulse=$pulseRate');
    _applyReading(
      kind: BleReadingKind.bloodOxygen,
      deviceName: 'My Oximeter',
      status: 'SpO2: $spo2% · Pulse: $pulseRate bpm',
      update: (r) => r.copyWith(
        bloodOxygen: spo2,
        pulseRate: pulseRate,
        heartRate: pulseRate,
      ),
    );
  }

  // Default user profile for body composition — update with real user data when available.
  static const _profileHeightCm = 170.0;
  static const _profileGender = 'M';
  static const _profileAge = 35;

  void _onWeightStable(double weight) {
    _log('WEIGHT stable: ${weight.toStringAsFixed(1)} kg');
    final now = DateTime.now().millisecondsSinceEpoch;
    final sameAsLast = !_lastSentWeight.isNaN &&
        (weight - _lastSentWeight).abs() < BleConstants.weightTolerance;

    if (sameAsLast &&
        (now - _lastSentWeightAtMs) < BleConstants.weightResendCooldownMs) {
      return;
    }

    if (weight <= BleConstants.resetWeight) {
      return;
    }

    // Use measured impedance or fall back to 600 Ω (average adult, per Java reference code).
    final imp = _lastImpedance ?? 600;
    _log('Computing body composition: weight=${weight}kg imp=${imp}Ω '
        'height=${_profileHeightCm}cm gender=$_profileGender age=$_profileAge');
    final comp = BodyCompositionCalc.compute(
      weightKg: weight,
      rOhms: imp.toDouble(),
      heightCm: _profileHeightCm,
      gender: _profileGender,
      age: _profileAge,
    );
    _log('Body comp: FFM=${comp.fatFreeMass} LM=${comp.leanMass} '
        'FM=${comp.fatMass} BF%=${comp.bodyFatPercent} '
        'TBW=${comp.totalBodyWater} BMI=${comp.bmi} (${comp.bmiCategory})');

    _applyReading(
      kind: BleReadingKind.weight,
      deviceName: 'JPD Scale',
      status: 'Weight: ${weight.toStringAsFixed(1)} kg',
      update: (r) => r.copyWith(
        weight: weight,
        impedance: _lastImpedance,
        bodyWater: comp.totalBodyWater,
        leanMass: comp.leanMass,
        fatMass: comp.fatMass,
        bodyFatPercent: comp.bodyFatPercent,
        bmi: comp.bmi,
        bmiCategory: comp.bmiCategory,
      ),
    );
    _lastSentWeight = weight;
    _lastSentWeightAtMs = now;
  }

  void _applyReading({
    required BleReadingKind kind,
    required String deviceName,
    required String status,
    required DeviceReadings Function(DeviceReadings current) update,
  }) {
    final type = BleConstants.typeForReadingKind(kind);
    final deviceId =
        type == null ? '' : BleConstants.deviceIdForType(type);

    _readings = update(_readings).copyWith(
      lastUpdated: DateTime.now(),
      lastReadingKind: kind,
      lastDeviceName: deviceName,
      lastDeviceId: deviceId.isEmpty ? null : deviceId,
    );
    _status = status;
    notifyListeners();
  }

  void _seedRegisteredDevices() {
    for (final registered in BleConstants.registeredDevices) {
      _registeredByDeviceId[registered.deviceId] =
          BleDeviceInfo.fromRegistered(registered);
    }
  }

  void _handleConnectFailure({required bool retry}) {
    _connectTimeoutTimer?.cancel();
    if (retry &&
        _connectRetry < BleConstants.maxConnectRetry &&
        _connectingAddress != null) {
      _connectRetry++;
      final delayMs = 700 * _connectRetry;
      _log('Retry $_connectRetry for "$_connectingName" in ${delayMs}ms');
      _status = 'Retrying connection ($_connectRetry)...';
      notifyListeners();
      Future.delayed(Duration(milliseconds: delayMs), () async {
        if (_connectingAddress == null) return;
        try {
          final device = BluetoothDevice.fromId(_connectingAddress!);
          await _connectToDevice(device, _connectingName ?? 'Device');
        } catch (_) {
          _resetConnectionState();
          _startScanCycle();
        }
      });
      return;
    }
    _log('Connect failed permanently for "$_connectingName", back to scan');
    _resetConnectionState();
    _startScanCycle();
  }

  void _handleDisconnect(String name, String address) {
    _upsertDevice(name, address, connected: false);
    final type = BleDeviceInfo.typeFromName(name);
    _markRegisteredSeen(type, connected: false);
    _resetConnectionState();
    _startScanCycle();
  }

  void _resetConnectionState() {
    _connectTimeoutTimer?.cancel();
    _isConnecting = false;
    _wasEverConnected = false;
    _connectingName = null;
    _connectingAddress = null;
    _connectRetry = 0;
    _connectedDevice = null;
  }

  void _upsertDevice(String name, String address, {required bool connected}) {
    final type = BleDeviceInfo.typeFromName(name);
    final deviceId = BleConstants.deviceIdForType(type);
    final info = BleDeviceInfo(
      name: name,
      address: address,
      type: type,
      deviceId: deviceId,
      connected: connected,
      lastSeen: DateTime.now(),
    );
    if (address.isNotEmpty) {
      _devices[address] = info;
    }
    if (deviceId.isNotEmpty) {
      _registeredByDeviceId[deviceId] = info;
    }
    notifyListeners();
  }

  void _markRegisteredSeen(BleDeviceType type, {required bool connected}) {
    final deviceId = BleConstants.deviceIdForType(type);
    if (deviceId.isEmpty) return;
    final existing = _registeredByDeviceId[deviceId];
    if (existing != null) {
      _registeredByDeviceId[deviceId] = existing.copyWith(
        connected: connected,
        lastSeen: DateTime.now(),
      );
    }
  }

  bool _isKnownDevice(String deviceName) {
    final lower = deviceName.toLowerCase();
    return lower.contains('empecs') ||
        lower.contains('thermometer') ||
        lower.contains('jpd') ||
        lower.contains('my oximeter');
  }

  List<int>? _extractAdvertisementBytes(ScanResult result) {
    final mfg = result.advertisementData.manufacturerData;
    if (mfg.isNotEmpty) {
      return mfg.values.expand((e) => e).toList();
    }
    final serviceData = result.advertisementData.serviceData;
    if (serviceData.isNotEmpty) {
      return serviceData.values.expand((e) => e).toList();
    }
    return null;
  }

  /// Restart a fresh scan cycle from the UI (e.g., "New Reading" button).
  void triggerScan() {
    if (_isConnecting) return;
    _scanWindowTimer?.cancel();
    _loggedThisCycle.clear();
    _stopScan().then((_) => _startScanCycle());
  }

  Future<void> disposeService() async {
    _scanWindowTimer?.cancel();
    _connectTimeoutTimer?.cancel();
    await _scanSub?.cancel();
    await _connectionSub?.cancel();
    _oximeterDetector.dispose();
    _weightDetector.dispose();
    await _stopScan();
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    disposeService();
    super.dispose();
  }
}

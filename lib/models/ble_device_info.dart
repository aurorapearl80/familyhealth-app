import '../services/ble_constants.dart';

class BleDeviceInfo {
  final String name;
  final String address;
  final BleDeviceType type;
  final String deviceId;
  final bool connected;
  final DateTime? lastSeen;

  const BleDeviceInfo({
    required this.name,
    required this.address,
    required this.type,
    required this.deviceId,
    this.connected = false,
    this.lastSeen,
  });

  BleDeviceInfo copyWith({
    String? name,
    String? address,
    BleDeviceType? type,
    String? deviceId,
    bool? connected,
    DateTime? lastSeen,
  }) {
    return BleDeviceInfo(
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      deviceId: deviceId ?? this.deviceId,
      connected: connected ?? this.connected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  factory BleDeviceInfo.fromRegistered(RegisteredHealthDevice registered) {
    return BleDeviceInfo(
      name: registered.bleNameHint,
      address: '',
      type: registered.type,
      deviceId: registered.deviceId,
    );
  }

  static BleDeviceType typeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('jpd scale')) return BleDeviceType.weight;
    if (lower.contains('jpd')) return BleDeviceType.bloodPressure;
    if (lower.contains('thermometer')) return BleDeviceType.temperature;
    if (lower.contains('oximeter')) return BleDeviceType.bloodOxygen;
    if (lower.contains('empecs')) return BleDeviceType.bloodGlucose;
    return BleDeviceType.unknown;
  }

  static String labelForType(BleDeviceType type) {
    switch (type) {
      case BleDeviceType.bloodPressure:
        return 'Blood Pressure Monitor';
      case BleDeviceType.bloodOxygen:
        return 'Pulse Oximeter';
      case BleDeviceType.temperature:
        return 'Thermometer';
      case BleDeviceType.weight:
        return 'Smart Scale';
      case BleDeviceType.bloodGlucose:
        return 'Blood Glucose Meter';
      case BleDeviceType.unknown:
        return 'BLE Device';
    }
  }
}

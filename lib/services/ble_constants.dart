/// BLE UUIDs and device name patterns ported from the Android BleScanService.
class BleConstants {
  BleConstants._();

  static const cccdUuid = '00002902-0000-1000-8000-00805f9b34fb';

  static const thermometerServiceUuid = '00001809-0000-1000-8000-00805f9b34fb';
  static const thermometerCharUuid = '00002a1c-0000-1000-8000-00805f9b34fb';

  static const jpdBpmServiceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const jpdBpmCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';

  static const pulseOximeterServiceUuid = '00001822-0000-1000-8000-00805f9b34fb';
  static const pulseOximeterCharUuid = '00002a5f-0000-1000-8000-00805f9b34fb';

  static const glucoseServiceUuid = '00001808-0000-1000-8000-00805f9b34fb';

  static const customServiceUuid = '2f2dfff4-2e85-649d-3545-3586428f5da3';

  // Urion "Blood Pressure Watch" (U19M) — Nordic-UART-style custom service.
  // See SmartHealthBLEAI-team's BloodPressureWatchHandler.java for the protocol this ports.
  static const bpWatchServiceUuid = '6e40fff0-b5a3-f393-e0a9-e50e24dcca9e';
  static const bpWatchWriteCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const bpWatchNotifyCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  static const knownDeviceNames = [
    'JPD Scale',
    'JPD BPM',
    'My Thermometer',
    'My Oximeter',
    'EMPECS-BBXK010027',
  ];

  static const scanWindowMs = 12000;
  static const scanPauseMs = 2000;
  static const connectTimeoutMs = 10000;
  static const maxConnectRetry = 3;
  static const stableDelayMs = 500;
  static const weightTolerance = 0.05;
  static const weightResendCooldownMs = 15000;
  static const resetWeight = 0.5;

  /// Backend device IDs (from Android Constant.java).
  static const deviceTemperature = '5bc3cb14cba82b066cae7bc1';
  static const deviceOximeter = '5bc3cb14cba82b066cae7bc2';
  static const deviceBp = '66437be266c8833a1c42d7aa';
  static const deviceWeight = '5d2cac72ed5d7122d4044f0f';
  static const deviceGlucose = '5e4c0db6bc20236a64ca3467';

  static const registeredDevices = <RegisteredHealthDevice>[
    RegisteredHealthDevice(
      type: BleDeviceType.temperature,
      deviceId: deviceTemperature,
      bleNameHint: 'My Thermometer',
    ),
    RegisteredHealthDevice(
      type: BleDeviceType.bloodOxygen,
      deviceId: deviceOximeter,
      bleNameHint: 'My Oximeter',
    ),
    RegisteredHealthDevice(
      type: BleDeviceType.bloodPressure,
      deviceId: deviceBp,
      bleNameHint: 'JPD BPM',
    ),
    RegisteredHealthDevice(
      type: BleDeviceType.weight,
      deviceId: deviceWeight,
      bleNameHint: 'JPD Scale',
    ),
    RegisteredHealthDevice(
      type: BleDeviceType.bloodGlucose,
      deviceId: deviceGlucose,
      bleNameHint: 'EMPECS',
    ),
  ];

  static String deviceIdForType(BleDeviceType type) {
    switch (type) {
      case BleDeviceType.temperature:
        return deviceTemperature;
      case BleDeviceType.bloodOxygen:
        return deviceOximeter;
      case BleDeviceType.bloodPressure:
        return deviceBp;
      case BleDeviceType.weight:
        return deviceWeight;
      case BleDeviceType.bloodGlucose:
        return deviceGlucose;
      case BleDeviceType.unknown:
        return '';
    }
  }

  static BleDeviceType? typeForDeviceId(String deviceId) {
    switch (deviceId) {
      case deviceTemperature:
        return BleDeviceType.temperature;
      case deviceOximeter:
        return BleDeviceType.bloodOxygen;
      case deviceBp:
        return BleDeviceType.bloodPressure;
      case deviceWeight:
        return BleDeviceType.weight;
      case deviceGlucose:
        return BleDeviceType.bloodGlucose;
      default:
        return null;
    }
  }

  static BleDeviceType? typeForReadingKind(BleReadingKind kind) {
    switch (kind) {
      case BleReadingKind.temperature:
        return BleDeviceType.temperature;
      case BleReadingKind.bloodOxygen:
        return BleDeviceType.bloodOxygen;
      case BleReadingKind.bloodPressure:
        return BleDeviceType.bloodPressure;
      case BleReadingKind.weight:
        return BleDeviceType.weight;
      case BleReadingKind.bloodGlucose:
        return BleDeviceType.bloodGlucose;
    }
  }
}

class RegisteredHealthDevice {
  final BleDeviceType type;
  final String deviceId;
  final String bleNameHint;

  const RegisteredHealthDevice({
    required this.type,
    required this.deviceId,
    required this.bleNameHint,
  });
}

enum BleDeviceType {
  bloodPressure,
  bloodOxygen,
  temperature,
  weight,
  bloodGlucose,
  unknown,
}

enum BleReadingKind {
  bloodPressure,
  bloodOxygen,
  temperature,
  weight,
  bloodGlucose,
}

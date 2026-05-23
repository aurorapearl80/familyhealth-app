import '../services/ble_constants.dart';

class DeviceReadings {
  final int? heartRate;
  final int? bloodOxygen;
  final int? systolic;
  final int? diastolic;
  final int? pulseRate;
  final double? temperature;
  final double? weight;
  final int? impedance;
  final double? bodyWater;
  final double? leanMass;
  final double? fatMass;
  final double? bodyFatPercent;
  final double? bmi;
  final String? bmiCategory;
  final int? bloodGlucose;
  final String? glucoseUnit;
  final DateTime? lastUpdated;
  final BleReadingKind? lastReadingKind;
  final String? lastDeviceName;
  final String? lastDeviceId;

  const DeviceReadings({
    this.heartRate,
    this.bloodOxygen,
    this.systolic,
    this.diastolic,
    this.pulseRate,
    this.temperature,
    this.weight,
    this.impedance,
    this.bodyWater,
    this.leanMass,
    this.fatMass,
    this.bodyFatPercent,
    this.bmi,
    this.bmiCategory,
    this.bloodGlucose,
    this.glucoseUnit,
    this.lastUpdated,
    this.lastReadingKind,
    this.lastDeviceName,
    this.lastDeviceId,
  });

  DeviceReadings copyWith({
    int? heartRate,
    int? bloodOxygen,
    int? systolic,
    int? diastolic,
    int? pulseRate,
    double? temperature,
    double? weight,
    int? impedance,
    double? bodyWater,
    double? leanMass,
    double? fatMass,
    double? bodyFatPercent,
    double? bmi,
    String? bmiCategory,
    int? bloodGlucose,
    String? glucoseUnit,
    DateTime? lastUpdated,
    BleReadingKind? lastReadingKind,
    String? lastDeviceName,
    String? lastDeviceId,
  }) {
    return DeviceReadings(
      heartRate: heartRate ?? this.heartRate,
      bloodOxygen: bloodOxygen ?? this.bloodOxygen,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulseRate: pulseRate ?? this.pulseRate,
      temperature: temperature ?? this.temperature,
      weight: weight ?? this.weight,
      impedance: impedance ?? this.impedance,
      bodyWater: bodyWater ?? this.bodyWater,
      leanMass: leanMass ?? this.leanMass,
      fatMass: fatMass ?? this.fatMass,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      bmi: bmi ?? this.bmi,
      bmiCategory: bmiCategory ?? this.bmiCategory,
      bloodGlucose: bloodGlucose ?? this.bloodGlucose,
      glucoseUnit: glucoseUnit ?? this.glucoseUnit,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastReadingKind: lastReadingKind ?? this.lastReadingKind,
      lastDeviceName: lastDeviceName ?? this.lastDeviceName,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
    );
  }

  String get bloodPressureDisplay {
    if (systolic == null || diastolic == null) return '--/--';
    return '$systolic/$diastolic';
  }

  String get heartRateDisplay => heartRate?.toString() ?? pulseRate?.toString() ?? '--';

  String get bloodOxygenDisplay => bloodOxygen?.toString() ?? '--';

  String get temperatureDisplay =>
      temperature == null ? '--' : temperature!.toStringAsFixed(1);

  String get weightDisplay =>
      weight == null ? '--' : weight!.toStringAsFixed(1);

  String get bloodGlucoseDisplay => bloodGlucose?.toString() ?? '--';
}

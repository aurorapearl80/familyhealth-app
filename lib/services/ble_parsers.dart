/// Parses raw BLE bytes from health devices (ported from Android BleScanService).
class BleParsers {
  BleParsers._();

  static BloodPressureReading? parseBloodPressure(List<int> data) {
    if (data.length == 7) {
      final d3 = data[3] & 0xff;
      final d4 = data[4] & 0xff;
      return BloodPressureReading(
        systolic: 0,
        diastolic: d3 * 256 + d4,
        pulseRate: 0,
        isPartial: true,
      );
    }
    if (data.length == 8) {
      return BloodPressureReading(
        systolic: data[3] & 0xff,
        diastolic: data[4] & 0xff,
        pulseRate: data[5] & 0xff,
      );
    }
    return null;
  }

  static TemperatureReading? parseThermometer(List<int> data) {
    if (data.length != 5) return null;

    final typeCode = data[1] & 0xff;
    // Device sends 0x22 (34), 0x33 (51), or 0x37 (55) — accept all
    if (typeCode != 0x22 && typeCode != 0x33 && typeCode != 0x37) return null;

    final dataCode = ((data[2] << 8) & 0xff00) | (data[3] & 0x00ff);
    final tempValue = dataCode & 0x7fff;
    var celsius = tempValue / 100.0;

    final unit = (data[2] >> 8) & 0x01;
    if (unit == 1) {
      celsius = (tempValue / 100.0 - 32) / 1.8;
    }

    return TemperatureReading(celsius: celsius);
  }

  static OximeterReading? parseOximeter(List<int> data) {
    if (data.length < 3) return null;

    final packet = data[0] & 0xff;
    final pulseRate = data[1] & 0xff;
    final spo2 = data[2] & 0xff;

    // Accept 0x81 (standard packet) or 0x01 (some firmware variants)
    if (packet != 0x81 && packet != 0x01) return null;
    if (pulseRate <= 0 || pulseRate > 250 || spo2 <= 0 || spo2 > 100) {
      return null;
    }

    return OximeterReading(pulseRate: pulseRate, spo2: spo2);
  }

  // Advertisement layout: [weight_h, weight_l, imp_h, imp_l, 0xFF, 0xF0, 0x00, mac×6]
  static double? parseWeightFromAdvertisement(List<int> scanRecord) {
    if (scanRecord.length < 2) return null;
    final weightRaw = ((scanRecord[0] & 0xff) << 8) | (scanRecord[1] & 0xff);
    if (weightRaw == 0) return null;
    return weightRaw / 10.0;
  }

  // Returns resistance in ohms; null if not measured (0) or out of plausible range.
  static int? parseImpedanceFromAdvertisement(List<int> scanRecord) {
    if (scanRecord.length < 4) return null;
    final r = ((scanRecord[2] & 0xff) << 8) | (scanRecord[3] & 0xff);
    if (r < 100 || r > 1500) return null;
    return r;
  }

  static GlucoseReading? parseGlucose(List<int> data) {
    if (data.length != 15) return null;

    final flags = data[0];
    final glLow = data[12];
    final glHigh = data[13];
    final typeLocation = data[14];

    final glPresent = ((flags >> 1) & 0x01) == 1;
    if (!glPresent) return null;

    final isUnitMol = ((flags >> 2) & 0x01) == 1;
    final isBeforeMeal = ((flags >> 6) & 0x01) == 1;
    final hasNoMealSelection = ((flags >> 6) & 0x03) == 0;
    final isControlSolution = (typeLocation & 0xff) == 164;

    int mealValue;
    if (isControlSolution) {
      mealValue = 5;
    } else if (hasNoMealSelection) {
      mealValue = 0;
    } else if (isBeforeMeal) {
      mealValue = 4;
    } else {
      mealValue = 3;
    }

    final mantissa = ((glHigh & 0x0f) << 8) | (glLow & 0xff);
    final exponent = (glHigh & 0xf0) >> 4;

    int glucoseMgDl;
    if (isUnitMol) {
      final mmol = mantissa * _pow10(exponent - 13);
      glucoseMgDl = (18 * mmol).round();
    } else {
      glucoseMgDl = (mantissa * _pow10(exponent - 11)).round();
    }

    return GlucoseReading(
      glucose: glucoseMgDl,
      mealValue: mealValue,
      unit: 'mg/dL',
    );
  }

  static double _pow10(int exp) {
    if (exp >= 0) {
      var result = 1.0;
      for (var i = 0; i < exp; i++) {
        result *= 10;
      }
      return result;
    }
    var result = 1.0;
    for (var i = 0; i < -exp; i++) {
      result /= 10;
    }
    return result;
  }
}

class BloodPressureReading {
  final int systolic;
  final int diastolic;
  final int pulseRate;
  final bool isPartial;

  const BloodPressureReading({
    required this.systolic,
    required this.diastolic,
    required this.pulseRate,
    this.isPartial = false,
  });
}

class TemperatureReading {
  final double celsius;
  const TemperatureReading({required this.celsius});
}

class OximeterReading {
  final int pulseRate;
  final int spo2;
  const OximeterReading({required this.pulseRate, required this.spo2});
}

class GlucoseReading {
  final int glucose;
  final int mealValue;
  final String unit;
  const GlucoseReading({
    required this.glucose,
    required this.mealValue,
    required this.unit,
  });
}

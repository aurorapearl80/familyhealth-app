/// Dart port of Android BodyComposition.java.
/// Formula: Deurenberg et al. BIA model for foot-to-foot resistance.
class BodyCompositionResult {
  final double fatFreeMass;
  final double leanMass;
  final double fatMass;
  final double bodyFatPercent;
  final double totalBodyWater;
  final double bmi;
  final String bmiCategory;

  const BodyCompositionResult({
    required this.fatFreeMass,
    required this.leanMass,
    required this.fatMass,
    required this.bodyFatPercent,
    required this.totalBodyWater,
    required this.bmi,
    required this.bmiCategory,
  });
}

class BodyCompositionCalc {
  BodyCompositionCalc._();

  static BodyCompositionResult compute({
    required double weightKg,
    required double rOhms,
    required double heightCm,
    required String gender, // "M" or "F"
    required int age,
  }) {
    final g = gender.toUpperCase() == 'M' ? 1 : 0;

    // Fat-free mass (FFM)
    double ffm = 13.055
        + 0.204 * weightKg
        + 0.394 * (heightCm * heightCm) / rOhms
        - 0.136 * age
        + 8.125 * g;

    // Total body water
    double tbw = ffm * 0.732;

    // Fat mass
    double fm = weightKg - ffm;

    // Minimum and essential fat floors
    final minFat = gender.toUpperCase() == 'M' ? weightKg * 0.06 : weightKg * 0.13;
    final essentialFat = gender.toUpperCase() == 'M' ? weightKg * 0.04 : weightKg * 0.10;

    if (fm < minFat) {
      fm = minFat;
      ffm = weightKg - fm;
      tbw = ffm * 0.732;
    }

    final lm = ffm + essentialFat;
    final bfp = (fm / weightKg) * 100;

    // BMI
    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);
    final category = _bmiCategory(bmi);

    return BodyCompositionResult(
      fatFreeMass: _round(ffm),
      leanMass: _round(lm),
      fatMass: _round(fm),
      bodyFatPercent: _round(bfp),
      totalBodyWater: _round(tbw),
      bmi: _round(bmi),
      bmiCategory: category,
    );
  }

  static String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  static double _round(double v) =>
      (v * 10).roundToDouble() / 10;
}

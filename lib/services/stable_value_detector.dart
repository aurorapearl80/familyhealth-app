import 'dart:async';

/// Debounces integer pairs until stable, matching Android IntChangeDetector.
class IntPairStableDetector {
  IntPairStableDetector({this.stableDelayMs = 500});

  final int stableDelayMs;
  int? _lastPrimary;
  int? _lastSecondary;
  Timer? _timer;
  void Function(int primary, int secondary)? onStable;

  void update(int primary, int secondary) {
    if (_lastPrimary == primary && _lastSecondary == secondary) return;
    _lastPrimary = primary;
    _lastSecondary = secondary;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: stableDelayMs), () {
      onStable?.call(primary, secondary);
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Debounces doubles until stable, matching Android DoubleChangeDetector.
class DoubleStableDetector {
  DoubleStableDetector({
    this.stableDelayMs = 500,
    this.tolerance = 0.05,
  });

  final int stableDelayMs;
  final double tolerance;
  double? _lastValue;
  Timer? _timer;
  void Function(double value)? onStable;
  void Function(double value)? onChange;

  void update(double value) {
    final changed =
        _lastValue == null || (value - _lastValue!).abs() >= tolerance;
    if (changed) {
      onChange?.call(value);
    }
    _lastValue = value;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: stableDelayMs), () {
      onStable?.call(value);
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

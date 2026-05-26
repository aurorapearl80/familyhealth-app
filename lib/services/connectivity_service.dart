import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectionQuality { none, mobile, wifi }

/// Global connectivity tracker. Add to the provider tree in main.dart.
class ConnectivityService extends ChangeNotifier {
  ConnectionQuality _quality = ConnectionQuality.wifi;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectionQuality get quality => _quality;
  bool get isOnline => _quality != ConnectionQuality.none;

  /// Human-readable label for the current state.
  String get label {
    switch (_quality) {
      case ConnectionQuality.wifi:
        return 'Wi-Fi';
      case ConnectionQuality.mobile:
        return 'Mobile';
      case ConnectionQuality.none:
        return 'Offline';
    }
  }

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    // Seed from current state before subscribing
    final current = await Connectivity().checkConnectivity();
    _updateFromResult(current);
    _sub = Connectivity().onConnectivityChanged.listen(_updateFromResult);
  }

  void _updateFromResult(List<ConnectivityResult> results) {
    final prev = _quality;
    if (results.any((r) => r == ConnectivityResult.wifi)) {
      _quality = ConnectionQuality.wifi;
    } else if (results.any((r) => r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet)) {
      _quality = ConnectionQuality.mobile;
    } else {
      _quality = ConnectionQuality.none;
    }
    if (_quality != prev) notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
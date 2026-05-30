import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'auth_service.dart';

/// Unique WorkManager task name
const _kBgTask = 'com.familywatchtoday.location_bg';

/// Top-level WorkManager callback (must be a free function annotated vm:entry-point).
@pragma('vm:entry-point')
void locationCallbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName == _kBgTask) {
      return LocationService.runBackgroundTask();
    }
    return true;
  });
}

/// ChangeNotifier that owns GPS tracking, the offline queue, and the
/// WorkManager periodic background task.
class LocationService extends ChangeNotifier {
  static const _apiBase =
      'https://familywatchtoday.com/api/auth-monitoring';
  static const _queueKey = 'location_offline_queue';
  static const _maxQueue = 100;

  // ── State ─────────────────────────────────────────────────────────────────

  bool _tracking = false;
  bool get isTracking => _tracking;

  Position? _lastSent;
  DateTime? _lastSentAt;

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;

  // ── Permissions ──────────────────────────────────────────────────────────

  static Future<bool> requestPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    // Background location (Android only — graceful if denied)
    if (Platform.isAndroid) {
      await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  static Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  // ── Start / Stop ──────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_tracking) return;
    final ok = await hasPermission();
    if (!ok) {
      debugPrint('[LocationService] no permission — not starting');
      return;
    }
    _tracking = true;
    notifyListeners();

    // Build platform-specific settings
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              'Tracking your location for safety monitoring.',
          notificationTitle: 'Family Watch Today',
          enableWakeLock: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      );
    }

    // Stream: fires on 25 m movement
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) => _onPosition(pos, 'foreground'),
      onError: (e) => debugPrint('[LocationService] stream error: $e'),
    );

    // Heartbeat: fires every 60 s even without movement
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium),
        ).timeout(const Duration(seconds: 15));
        _onPosition(pos, 'foreground');
      } catch (e) {
        debugPrint('[LocationService] heartbeat error: $e');
      }
    });

    // Register WorkManager periodic task for background (min 15 min)
    await Workmanager().registerPeriodicTask(
      _kBgTask,
      _kBgTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    // Flush any offline-queued locations
    unawaited(_flushQueue());

    debugPrint('[LocationService] started');
  }

  Future<void> stop() async {
    _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _tracking = false;
    notifyListeners();
    await Workmanager().cancelByUniqueName(_kBgTask);
    debugPrint('[LocationService] stopped');
  }

  // ── Position handler ──────────────────────────────────────────────────────

  void _onPosition(Position pos, String source) {
    if (!_shouldSend(pos)) return;
    _lastSent = pos;
    _lastSentAt = DateTime.now();
    unawaited(_sendLocation(pos, source));
  }

  bool _shouldSend(Position pos) {
    if (_lastSentAt == null) return true;
    if (DateTime.now().difference(_lastSentAt!) >=
        const Duration(seconds: 60)) {
      return true;
    }
    if (_lastSent != null) {
      final dist = Geolocator.distanceBetween(
        _lastSent!.latitude,
        _lastSent!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist >= 25) return true;
    }
    return false;
  }

  // ── Send a single location ────────────────────────────────────────────────

  Future<void> _sendLocation(Position pos, String source) async {
    final token = await AuthService.getToken();
    if (token == null) return;

    final payload = {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy_meters': pos.accuracy,
      'source': source,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final resp = await http
          .post(
            Uri.parse('$_apiBase/locations'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        debugPrint(
            '[LocationService] sent ${pos.latitude},${pos.longitude}');
        unawaited(_flushQueue()); // try to drain queue on success
      } else {
        debugPrint(
            '[LocationService] ${resp.statusCode} → queuing');
        await _enqueue(payload);
      }
    } catch (e) {
      debugPrint('[LocationService] send error: $e → queuing');
      await _enqueue(payload);
    }
  }

  // ── Offline queue ─────────────────────────────────────────────────────────

  Future<void> _enqueue(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    final queue = raw != null
        ? List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];
    if (queue.length >= _maxQueue) queue.removeAt(0);
    queue.add(data);
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<void> _flushQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return;

    final queue = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)));
    if (queue.isEmpty) return;

    final token = await AuthService.getToken();
    if (token == null) return;

    // Send in batches of max 100
    bool allOk = true;
    for (int i = 0; i < queue.length; i += 100) {
      final batch = queue.sublist(i, (i + 100).clamp(0, queue.length));
      try {
        final resp = await http
            .post(
              Uri.parse('$_apiBase/locations/bulk'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'data': batch}),
            )
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200 && resp.statusCode != 201) {
          allOk = false;
        }
      } catch (_) {
        allOk = false;
      }
    }

    if (allOk) {
      await prefs.remove(_queueKey);
      debugPrint('[LocationService] flushed ${queue.length} queued points');
    }
  }

  // ── WorkManager static background task ───────────────────────────────────

  /// Called by [locationCallbackDispatcher] when the periodic BG task fires.
  static Future<bool> runBackgroundTask() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return true; // not logged in

      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return true;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));

      final body = jsonEncode({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy_meters': pos.accuracy,
        'source': 'background',
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });

      final resp = await http.post(
        Uri.parse('$_apiBase/locations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      debugPrint('[LocationService BG] $e');
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _heartbeat?.cancel();
    super.dispose();
  }
}

// Silence unawaited-future lint for fire-and-forget calls
void unawaited(Future<void> f) {}

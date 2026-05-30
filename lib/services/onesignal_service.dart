import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Thin wrapper around onesignal_flutter v5.
///
/// App ID: 0ce649bf-09e9-4c3c-9985-651a34983b0b
///
/// Rules:
///  - The app NEVER calls the OneSignal REST API.
///  - Geofence alerts are sent by the Laravel server, not Flutter.
///  - Flutter only: initialize, requestPermission, login(user_$id), logout.
class OneSignalService {
  OneSignalService._();

  static const _appId = '0ce649bf-09e9-4c3c-9985-651a34983b0b';

  // ── Initialize (call once in main before runApp) ───────────────────────

  static void initialize() {
    OneSignal.initialize(_appId);
    debugPrint('[OneSignal] initialized');
  }

  // ── Request notification permission ──────────────────────────────────────

  static Future<void> requestPermission() async {
    final granted = await OneSignal.Notifications.requestPermission(true);
    debugPrint('[OneSignal] notification permission granted: $granted');
  }

  // ── Link to a patient user ────────────────────────────────────────────────

  /// Call after login: associates this device with user_$userId so the server
  /// can target push notifications via OneSignal.login('user_$id').
  static Future<void> loginUser(String userId) async {
    try {
      await OneSignal.login('user_$userId');
      debugPrint('[OneSignal] logged in as user_$userId');
    } catch (e) {
      debugPrint('[OneSignal] loginUser error: $e');
    }
  }

  // ── Unlink (call on logout) ───────────────────────────────────────────────

  static Future<void> logout() async {
    try {
      await OneSignal.logout();
      debugPrint('[OneSignal] logged out');
    } catch (e) {
      debugPrint('[OneSignal] logout error: $e');
    }
  }
}

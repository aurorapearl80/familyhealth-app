import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../navigation.dart';
import '../screens/share/incoming_call_screen.dart';

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

  // ── Incoming video calls ────────────────────────────────────────────────

  /// Call once in main (after `initialize`) — catches the backend's
  /// `type: incoming_call` push both while the app is foregrounded and when
  /// the user taps it from the notification tray, and pushes
  /// [IncomingCallScreen] via the global [navigatorKey].
  static void registerCallListeners() {
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      debugPrint('[OneSignal] foregroundWillDisplay additionalData: $data');
      if (data != null && data['type'] == 'incoming_call') {
        event.preventDefault();
        _showIncomingCall(data);
      }
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      debugPrint('[OneSignal] click additionalData: $data');
      if (data != null && data['type'] == 'incoming_call') {
        _showIncomingCall(data);
      }
    });
  }

  static void _showIncomingCall(Map<String, dynamic> data) {
    final callInvitationId = data['call_invitation_id'] is int
        ? data['call_invitation_id'] as int
        : int.tryParse('${data['call_invitation_id']}') ?? 0;
    final callerName = data['caller_name']?.toString() ?? 'Care team';
    final callerAvatarUrl = data['caller_avatar_url']?.toString();

    debugPrint('[OneSignal] _showIncomingCall id=$callInvitationId caller=$callerName navigatorState=${navigatorKey.currentState}');

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(
          callInvitationId: callInvitationId,
          callerName: callerName,
          callerAvatarUrl: (callerAvatarUrl != null && callerAvatarUrl.isNotEmpty) ? callerAvatarUrl : null,
        ),
      ),
    );
  }
}

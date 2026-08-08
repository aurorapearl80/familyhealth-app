import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../navigation.dart';
import '../screens/share/video_call_screen.dart';
import '../theme/app_colors.dart';

/// Bridges to MainActivity.kt — after IncomingCallActivity (native, shown via
/// a full-screen-intent push) accepts a call, this tells Dart to jump
/// straight into VideoCallScreen instead of the normal dashboard.
///
/// Two paths, matching MainActivity's onCreate vs onNewIntent split:
///  - Cold start: [getPendingCallLaunch] is pulled once at splash.
///  - App already running: native pushes "openVideoCall" directly, caught
///    by [registerOpenVideoCallHandler] regardless of the current screen.
class NativeCallBridge {
  static const _channel = MethodChannel('com.familywatchtoday.familyhealth/call');

  static Future<String?> getPendingCallLaunch() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getPendingCallLaunch');
      return result?['callerName'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Call once at app startup (main.dart).
  static void registerOpenVideoCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openVideoCall') {
        final callerName = (call.arguments as Map?)?['callerName']?.toString();
        if (callerName != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => VideoCallScreen(contactName: callerName, contactColor: AppColors.primary),
            ),
          );
        }
      }
      return null;
    });
  }
}

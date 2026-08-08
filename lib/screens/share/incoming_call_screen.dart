import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/call_invitation_service.dart';
import '../../theme/app_colors.dart';
import 'video_call_screen.dart';

/// Full-screen ringing prompt shown when the admin/clinic side starts a
/// video call — pushed via the global navigator key from an OneSignal
/// notification listener (see onesignal_service.dart).
class IncomingCallScreen extends StatefulWidget {
  final int callInvitationId;
  final String callerName;
  final String? callerAvatarUrl;

  const IncomingCallScreen({
    super.key,
    required this.callInvitationId,
    required this.callerName,
    this.callerAvatarUrl,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _vibrateTimer;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _vibrateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      HapticFeedback.vibrate();
    });
  }

  @override
  void dispose() {
    _vibrateTimer?.cancel();
    super.dispose();
  }

  Future<void> _respond(String status) async {
    if (_responding) return;
    setState(() => _responding = true);
    _vibrateTimer?.cancel();

    await CallInvitationService.respond(widget.callInvitationId, status);
    if (!mounted) return;

    if (status == 'accepted') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            contactName: widget.callerName,
            contactColor: AppColors.primary,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primary,
                backgroundImage: widget.callerAvatarUrl != null
                    ? NetworkImage(widget.callerAvatarUrl!)
                    : null,
                child: widget.callerAvatarUrl == null
                    ? Text(
                        widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                widget.callerName,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Incoming video call…',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(
                    icon: Icons.call_end_rounded,
                    color: AppColors.danger,
                    label: 'Decline',
                    onTap: () => _respond('declined'),
                  ),
                  _actionButton(
                    icon: Icons.videocam_rounded,
                    color: AppColors.success,
                    label: 'Accept',
                    onTap: () => _respond('accepted'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _responding ? null : onTap,
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

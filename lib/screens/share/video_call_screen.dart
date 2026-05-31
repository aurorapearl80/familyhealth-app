import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../services/livekit_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String contactName;
  final Color contactColor;
  final int? patientId;

  const VideoCallScreen({
    super.key,
    required this.contactName,
    required this.contactColor,
    this.patientId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Room? _room;
  LocalVideoTrack? _localVideoTrack;
  VideoTrack? _remoteVideoTrack;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isConnecting = true;
  String? _errorMessage;
  String _callDuration = '00:00';
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _connect();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _stopwatch.stop();
    _room?.removeListener(_onRoomChanged);
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (!mounted) return;

    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.microphone] != PermissionStatus.granted) {
      setState(() {
        _isConnecting = false;
        _errorMessage = 'Camera and microphone permissions are required for video calls.';
      });
      return;
    }

    try {
      final tokenData = await LiveKitService.getToken(patientId: widget.patientId);
      if (!mounted) return;

      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      _room!.addListener(_onRoomChanged);

      await _room!.connect(tokenData['url']!, tokenData['token']!);
      if (!mounted) return;

      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      _refreshLocalTrack();

      _stopwatch.start();
      _tickDuration();

      setState(() => _isConnecting = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = 'Could not connect to the call.\n\n$e';
        });
      }
    }
  }

  void _refreshLocalTrack() {
    final pubs = _room?.localParticipant?.videoTrackPublications ?? [];
    for (final pub in pubs) {
      if (pub.track != null) {
        _localVideoTrack = pub.track;
        break;
      }
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;
    setState(() {
      _remoteVideoTrack = null;
      final participants = _room?.remoteParticipants.values.toList() ?? [];
      for (final participant in participants) {
        final pubs = participant.videoTrackPublications;
        for (final pub in pubs) {
          if (pub.subscribed && pub.track != null) {
            _remoteVideoTrack = pub.track;
            return;
          }
        }
      }
      if (_localVideoTrack == null) _refreshLocalTrack();
    });
  }

  void _tickDuration() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_stopwatch.isRunning) return;
      final e = _stopwatch.elapsed;
      final m = e.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = e.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _callDuration = '$m:$s');
      _tickDuration();
    });
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    await _room?.localParticipant?.setMicrophoneEnabled(!next);
    setState(() => _isMuted = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_isCameraOff;
    await _room?.localParticipant?.setCameraEnabled(!next);
    if (next) {
      setState(() {
        _isCameraOff = true;
        _localVideoTrack = null;
      });
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _refreshLocalTrack();
      setState(() => _isCameraOff = false);
    }
  }

  Future<void> _hangUp() async {
    await _room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildRemoteVideo(),
            _buildTopBar(),
            if (_localVideoTrack != null && !_isCameraOff) _buildLocalPreview(),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),
            if (_isConnecting) _buildConnectingOverlay(),
            if (!_isConnecting && _errorMessage != null) _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_remoteVideoTrack != null) {
      return Positioned.fill(
        child: VideoTrackRenderer(
          _remoteVideoTrack!,
          fit: VideoViewFit.contain,
        ),
      );
    }
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1030), Color(0xFF0D0820)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: widget.contactColor,
                child: Text(
                  widget.contactName[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.contactName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConnecting ? 'Calling...' : 'Waiting for ${widget.contactName} to join',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: _hangUp,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            ),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.contactName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (!_isConnecting && _errorMessage == null)
                  Text(
                    _callDuration,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
            const Spacer(),
            const SizedBox(width: 42),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPreview() {
    return Positioned(
      top: 80,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 100,
          height: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoTrackRenderer(
                _localVideoTrack!,
                fit: VideoViewFit.cover,
                mirrorMode: VideoViewMirrorMode.auto,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black45],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('You', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.only(bottom: 16, top: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _controlBtn(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Unmute' : 'Mute',
            onTap: _toggleMute,
            active: !_isMuted,
          ),
          const SizedBox(width: 24),
          _controlBtn(
            icon: Icons.call_end_rounded,
            label: 'End',
            onTap: _hangUp,
            active: false,
            bgColor: Colors.red,
            size: 66,
          ),
          const SizedBox(width: 24),
          _controlBtn(
            icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: _isCameraOff ? 'Start cam' : 'Stop cam',
            onTap: _toggleCamera,
            active: !_isCameraOff,
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool active,
    Color? bgColor,
    double size = 54,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor ?? (active ? Colors.white24 : Colors.white12),
              shape: BoxShape.circle,
              border: Border.all(
                color: bgColor != null ? Colors.transparent : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.44),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildConnectingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              SizedBox(height: 18),
              Text(
                'Connecting to call...',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Call Failed',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Go Back'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isConnecting = true;
                        _errorMessage = null;
                      });
                      _connect();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

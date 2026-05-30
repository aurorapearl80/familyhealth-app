import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/ble_summary_service.dart';
import '../../services/location_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/patient_service.dart';
import '../main_nav_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onLottieLoaded(LottieComposition composition) {
    _ctrl
      ..duration = composition.duration
      ..forward().whenComplete(_navigateAfterSplash);
  }

  Future<void> _navigateAfterSplash() async {
    if (!mounted) return;
    final token = await AuthService.getToken();
    final serial = await AuthService.getSerial();
    debugPrint('[Splash] token=${token != null ? 'present' : 'null'} serial=$serial');
    if (!mounted) return;

    // If token exists → go straight to dashboard
    // If no token → route to login
    final goHome = token != null;

    if (goHome) {
      context.read<BleSummaryService>().fetch();
      context.read<PatientService>().fetch();

      // Re-register OneSignal identity and resume GPS tracking
      final userId = await AuthService.getUserId();
      if (userId != null) {
        await OneSignalService.requestPermission();
        await OneSignalService.loginUser(userId);
      }
      if (mounted) {
        final hasPerms = await LocationService.hasPermission();
        if (hasPerms && mounted) {
          context.read<LocationService>().start();
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            goHome ? const MainNavScreen() : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // ── Centered Lottie ─────────────────────────────────────────────
          Center(
            child: Lottie.asset(
              'assets/animations/login_icon.json',
              controller: _ctrl,
              width: 260,
              height: 260,
              fit: BoxFit.contain,
              onLoaded: _onLottieLoaded,
            ),
          ),
          const SizedBox(height: 32),
          // ── App name ────────────────────────────────────────────────────
          Text(
            'Family Watch Today',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your health, decoded with precision.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black45,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

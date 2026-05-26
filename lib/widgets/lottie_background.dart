import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Wraps any widget with a looping Lottie animation rendered in the background.
/// The animation plays at low opacity behind all screen content, creating a
/// subtle animated health-themed backdrop.
class LottieBackground extends StatelessWidget {
  final Widget child;

  /// Opacity of the background animation. Defaults to 0.08 for a subtle effect.
  final double opacity;

  const LottieBackground({
    super.key,
    required this.child,
    this.opacity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Lottie background ──────────────────────────────────────────────
        Center(
          child: Opacity(
            opacity: opacity,
            child: Lottie.asset(
              'assets/animations/login_icon.json',
              width: 340,
              height: 340,
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),
        ),
        // ── Screen content ─────────────────────────────────────────────────
        child,
      ],
    );
  }
}

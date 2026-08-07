import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/patient_service.dart';
import '../screens/profile/profile_screen.dart';

/// Reusable circular avatar that shows the patient's profile image or initials.
/// When [tappable] is true, tapping navigates to ProfileScreen.
class ProfileAvatar extends StatelessWidget {
  final double radius;
  final bool tappable;

  const ProfileAvatar({super.key, this.radius = 18, this.tappable = true});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientService>();
    final avatar = buildAvatar(
      imageUrl: patient.profileImageUrl,
      initials: patient.initials,
      radius: radius,
    );

    if (!tappable) return avatar;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: avatar,
    );
  }

  /// Static helper so ProfileScreen (and the chat screens) can call this
  /// without importing this widget. [backgroundColor]/[icon] let callers with
  /// their own per-item color scheme (e.g. chat contact colors, group icon)
  /// override the default purple-gradient initials circle.
  static Widget buildAvatar({
    required String? imageUrl,
    required String initials,
    required double radius,
    Color? backgroundColor,
    IconData? icon,
  }) {
    final size = radius * 2;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackCircle(initials, size, backgroundColor, icon),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _fallbackCircle(initials, size, backgroundColor, icon),
        ),
      );
    }

    return _fallbackCircle(initials, size, backgroundColor, icon);
  }

  static Widget _fallbackCircle(String initials, double size, Color? backgroundColor, IconData? icon) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        gradient: backgroundColor == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6C63FF), Color(0xFF3D35B5)],
              )
            : null,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * 0.45)
            : Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: size * 0.33,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
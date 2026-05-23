import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF7B5CF0);
  static const Color primaryLight = Color(0xFF9B7FF5);

  // Card backgrounds
  static const Color cardPurple = Color(0xFF7B5CF0);
  static const Color cardPink = Color(0xFFE88FA8);
  static const Color cardOrange = Color(0xFFFF6B4A);
  static const Color cardGreen = Color(0xFF4CAF50);
  static const Color cardBlue = Color(0xFF4A9EFF);

  // Dark theme
  static const Color darkBg = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252540);

  // Light theme
  static const Color lightBg = Color(0xFFF5F5F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF0F0F8);

  // Alerts
  static const Color alertBlue = Color(0xFFE8F0FF);
  static const Color alertOrange = Color(0xFFFFF0E8);
  static const Color alertGreen = Color(0xFFE8F8E8);

  // Text
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMedium = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B7FF5), Color(0xFF6B4CE0)],
  );

  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8A0B4), Color(0xFFD47090)],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A65), Color(0xFFFF5722)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF64B5F6), Color(0xFF1565C0)],
  );
}

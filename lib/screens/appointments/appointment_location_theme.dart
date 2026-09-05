import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Maps an appointment location ('online'/'clinic'/'salon') to a distinct accent color, so the
/// user can visually tell which flow they're in as they move through the calendar/confirm
/// screens. Online keeps the app's original single accent color; clinic and salon get their own.
Color appointmentLocationColor(String location) {
  switch (location) {
    case 'clinic':
      return AppColors.cardBlue;
    case 'salon':
      return AppColors.cardPink;
    case 'online':
    default:
      return AppColors.primary;
  }
}

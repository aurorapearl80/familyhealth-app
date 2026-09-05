import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/appointment_time_slot.dart';
import '../../models/clinic_summary.dart';
import '../../services/appointment_booking_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/lottie_background.dart';
import 'appointment_location_theme.dart';

enum _SubmitState { idle, sending, error }

/// Step 4: review the selection and submit the booking.
class ConfirmAppointmentScreen extends StatefulWidget {
  final String location;
  final String title;
  final ClinicSummary clinic;
  final AppointmentTimeSlot slot;

  const ConfirmAppointmentScreen({
    super.key,
    required this.location,
    required this.title,
    required this.clinic,
    required this.slot,
  });

  @override
  State<ConfirmAppointmentScreen> createState() => _ConfirmAppointmentScreenState();
}

class _ConfirmAppointmentScreenState extends State<ConfirmAppointmentScreen> {
  _SubmitState _state = _SubmitState.idle;
  String? _errorMessage;
  late final Color _accentColor;

  @override
  void initState() {
    super.initState();
    _accentColor = appointmentLocationColor(widget.location);
  }

  Future<void> _submit() async {
    setState(() {
      _state = _SubmitState.sending;
      _errorMessage = null;
    });

    try {
      await AppointmentBookingService.submitAppointment(
        clinicId: widget.clinic.id,
        location: widget.location,
        startsAt: widget.slot.startsAt,
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment booked for ${_formatFullDate(widget.slot.startsAt)}.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _SubmitState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: LottieBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      if (_state == _SubmitState.error) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(),
                      ],
                    ],
                  ),
                ),
              ),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            'Confirm Appointment',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(Icons.event_available_rounded, 'Type', widget.title),
          const Divider(height: 28),
          _buildSummaryRow(_locationIcon(), 'Clinic', widget.clinic.name),
          const Divider(height: 28),
          _buildSummaryRow(
            Icons.calendar_today_rounded,
            'Date & Time',
            _formatFullDate(widget.slot.startsAt),
          ),
        ],
      ),
    );
  }

  IconData _locationIcon() {
    switch (widget.location) {
      case 'online':
        return Icons.videocam_rounded;
      case 'salon':
        return Icons.spa_rounded;
      case 'clinic':
      default:
        return Icons.local_hospital_outlined;
    }
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _accentColor),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Something went wrong. Please try again.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final sending = _state == _SubmitState.sending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: sending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Confirm Booking',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  String _formatFullDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour:$minute $period';
  }
}

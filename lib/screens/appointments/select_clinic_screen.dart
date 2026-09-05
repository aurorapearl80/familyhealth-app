import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/clinic_summary.dart';
import '../../services/appointment_booking_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/lottie_background.dart';
import 'appointment_calendar_screen.dart';
import 'appointment_location_theme.dart';

/// Step 2: pick a clinic branch for the chosen appointment type.
class SelectClinicScreen extends StatefulWidget {
  final String location;
  final String title;

  const SelectClinicScreen({super.key, required this.location, required this.title});

  @override
  State<SelectClinicScreen> createState() => _SelectClinicScreenState();
}

class _SelectClinicScreenState extends State<SelectClinicScreen> {
  List<ClinicSummary>? _clinics;
  String? _error;
  late final Color _accentColor;

  @override
  void initState() {
    super.initState();
    _accentColor = appointmentLocationColor(widget.location);
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final (_, clinics) = await AppointmentBookingService.fetchBookingInit();
      if (!mounted) return;
      setState(() => _clinics = clinics);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load clinics. Pull down to retry.');
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
              Expanded(child: _buildBody()),
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
            widget.title,
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

  Widget _buildBody() {
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium),
              ),
            ),
          ],
        ),
      );
    }

    final clinics = _clinics;
    if (clinics == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (clinics.isEmpty) {
      return Center(
        child: Text(
          'No clinics are available for booking right now.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: clinics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildClinicCard(clinics[index]),
      ),
    );
  }

  Widget _buildClinicCard(ClinicSummary clinic) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AppointmentCalendarScreen(
            location: widget.location,
            title: widget.title,
            clinic: clinic,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.local_hospital_outlined, color: _accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (clinic.city != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      clinic.city!,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

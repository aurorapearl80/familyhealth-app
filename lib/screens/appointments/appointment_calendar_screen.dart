import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/appointment_time_slot.dart';
import '../../models/clinic_summary.dart';
import '../../services/appointment_booking_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/lottie_background.dart';
import 'appointment_location_theme.dart';
import 'confirm_appointment_screen.dart';
import 'widget/time_slot_picker.dart';

/// Step 3: pick a date on the calendar, then an available hour.
class AppointmentCalendarScreen extends StatefulWidget {
  final String location;
  final String title;
  final ClinicSummary clinic;

  const AppointmentCalendarScreen({
    super.key,
    required this.location,
    required this.title,
    required this.clinic,
  });

  @override
  State<AppointmentCalendarScreen> createState() => _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState extends State<AppointmentCalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late final Color _accentColor;
  List<AppointmentTimeSlot>? _slots;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _focusedDay = DateTime(today.year, today.month, today.day);
    _selectedDay = _focusedDay;
    _accentColor = appointmentLocationColor(widget.location);
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _slots = null;
      _error = null;
    });
    try {
      final slots = await AppointmentBookingService.fetchAvailableSlots(
        clinicId: widget.clinic.id,
        location: widget.location,
        date: _selectedDay,
      );
      if (!mounted) return;
      setState(() => _slots = slots);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load available times. Pull down to retry.');
    }
  }

  void _onSlotTap(AppointmentTimeSlot slot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmAppointmentScreen(
          location: widget.location,
          title: widget.title,
          clinic: widget.clinic,
          slot: slot,
        ),
      ),
    );
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildCalendarCard(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildSlotsArea(),
                ),
              ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: _accentColor, shape: BoxShape.circle),
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
                Text(
                  widget.clinic.name,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
      child: TableCalendar(
        firstDay: DateTime(today.year, today.month, today.day),
        lastDay: DateTime(today.year, today.month, today.day).add(const Duration(days: 90)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        calendarFormat: CalendarFormat.month,
        availableGestures: AvailableGestures.horizontalSwipe,
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
          weekendStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        calendarStyle: CalendarStyle(
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark),
          weekendTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark),
          outsideTextStyle: GoogleFonts.inter(color: AppColors.textLight),
          disabledTextStyle: GoogleFonts.inter(color: AppColors.textLight),
          todayDecoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          todayTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _accentColor),
          selectedDecoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.circular(8),
          ),
          selectedTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _loadSlots();
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  Widget _buildSlotsArea() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium)),
      );
    }

    final slots = _slots;
    if (slots == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (slots.isEmpty) {
      return Center(
        child: Text(
          'No available times on this day — try another date.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium),
        ),
      );
    }

    return TimeSlotPicker(
      slots: slots,
      onSlotTap: _onSlotTap,
      formatTime: _formatTime,
      accentColor: _accentColor,
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

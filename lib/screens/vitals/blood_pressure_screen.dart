import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/ble_scan_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vitals_app_bar.dart';

class BloodPressureScreen extends StatelessWidget {
  const BloodPressureScreen({super.key});

  // ── Classification helpers ──────────────────────────────────────────────

  static String _systolicStatus(int? s) {
    if (s == null) return '--';
    if (s < 90) return 'Low';
    if (s < 120) return 'Optimal';
    if (s < 130) return 'Elevated';
    if (s < 140) return 'High Normal';
    if (s < 180) return 'High';
    return 'Crisis';
  }

  static String _diastolicStatus(int? d) {
    if (d == null) return '--';
    if (d < 60) return 'Low';
    if (d < 80) return 'Optimal';
    if (d < 90) return 'High Normal';
    if (d < 120) return 'High';
    return 'Crisis';
  }

  static String _outcome(int? s, int? d) {
    if (s == null || d == null) return '--';
    if (s >= 180 || d >= 120) return 'Crisis';
    if (s >= 140 || d >= 90) return 'High';
    if (s >= 130 || d >= 80) return 'Caution';
    if (s >= 120) return 'Elevated';
    return 'Good';
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Optimal':
        return AppColors.success;
      case 'Elevated':
      case 'High Normal':
        return AppColors.warning;
      case 'High':
      case 'Crisis':
        return AppColors.danger;
      default:
        return AppColors.textMedium;
    }
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  static String _wellnessText(int? s, int? d) {
    if (s == null || d == null) {
      return 'Turn on the blood pressure monitor to start a reading.';
    }
    if (s >= 180 || d >= 120) {
      return 'Blood pressure is at a dangerous level. Seek medical attention immediately.';
    }
    if (s >= 140 || d >= 90) {
      return 'Blood pressure is high. Consider consulting a doctor and reducing salt and stress.';
    }
    if (s >= 130 || d >= 80) {
      return 'Your systolic pressure is slightly elevated. Try reducing sodium intake and maintaining hydration for the next few days.';
    }
    if (s >= 120) {
      return 'Blood pressure is slightly elevated. Regular monitoring and a healthy lifestyle are recommended.';
    }
    return 'Blood pressure is within the healthy range. Keep up your healthy habits!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Consumer<BleScanService>(
          builder: (context, ble, _) {
            final systolic = ble.readings.systolic;
            final diastolic = ble.readings.diastolic;
            final bpm = ble.readings.pulseRate;
            final lastUpdated = ble.readings.lastUpdated;
            final timeStr =
                lastUpdated != null ? _formatTime(lastUpdated) : '--:--';
            final isConnected = ble.registeredDevices
                .any((d) => d.type.name == 'bloodPressure' && d.connected);

            final systolicDisplay = systolic?.toString() ?? '--';
            final diastolicDisplay = diastolic?.toString() ?? '--';
            final bpmDisplay = bpm?.toString() ?? '--';
            final outcome = _outcome(systolic, diastolic);
            final systolicStatus = _systolicStatus(systolic);
            final diastolicStatus = _diastolicStatus(diastolic);

            return Stack(
              children: [
                Column(
                  children: [
                    const VitalsAppBar(title: 'Blood Pressure'),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildHeroCard(
                              isConnected: isConnected,
                              systolicDisplay: systolicDisplay,
                              diastolicDisplay: diastolicDisplay,
                              bpmDisplay: bpmDisplay,
                              timeStr: timeStr,
                              outcome: outcome,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  _buildStatusRow(
                                    systolicStatus: systolicStatus,
                                    diastolicStatus: diastolicStatus,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildWellnessInsight(
                                      _wellnessText(systolic, diastolic)),
                                  const SizedBox(height: 80),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildNewReadingFab()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required bool isConnected,
    required String systolicDisplay,
    required String diastolicDisplay,
    required String bpmDisplay,
    required String timeStr,
    required String outcome,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.orangeGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh, color: Colors.white, size: 18),
              ),
              // Connection status
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          isConnected ? Colors.greenAccent : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'Live' : 'No device',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color:
                          isConnected ? Colors.greenAccent : Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.show_chart,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: systolicDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: '/',
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    color: Colors.white70,
                  ),
                ),
                TextSpan(
                  text: diastolicDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'MMHG',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Container(
                width: i == 0 ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == 0 ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCardStat(bpmDisplay, 'BPM'),
              Container(width: 1, height: 30, color: Colors.white30),
              const Icon(Icons.favorite, color: Colors.white, size: 28),
              Container(width: 1, height: 30, color: Colors.white30),
              _buildCardStat(outcome, 'OUTCOME'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required String systolicStatus,
    required String diastolicStatus,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            label: 'SYSTOLIC',
            status: systolicStatus,
            icon: Icons.show_chart,
            color: _statusColor(systolicStatus),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            label: 'DIASTOLIC',
            status: diastolicStatus,
            icon: Icons.radio_button_unchecked,
            color: _statusColor(diastolicStatus),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String label,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessInsight(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.alertBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on_outlined,
                color: AppColors.info, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wellness Insight',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewReadingFab() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            'New Reading',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

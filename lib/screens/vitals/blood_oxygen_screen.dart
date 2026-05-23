import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/ble_scan_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vitals_app_bar.dart';

class BloodOxygenScreen extends StatelessWidget {
  const BloodOxygenScreen({super.key});

  static String _getOutcome(int? spo2) {
    if (spo2 == null) return '--';
    if (spo2 >= 95) return 'Good';
    if (spo2 >= 90) return 'Low';
    return 'Critical';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Consumer<BleScanService>(
          builder: (context, ble, _) {
            final spo2 = ble.readings.bloodOxygen;
            final spo2Display = ble.readings.bloodOxygenDisplay;
            final bpmDisplay = ble.readings.pulseRate?.toString() ?? '--';
            final lastUpdated = ble.readings.lastUpdated;
            final outcome = _getOutcome(spo2);
            final timeStr = lastUpdated != null ? _formatTime(lastUpdated) : '--:--';
            final isConnected = ble.registeredDevices
                .any((d) => d.type.name == 'bloodOxygen' && d.connected);

            return Column(
              children: [
                const VitalsAppBar(title: 'Blood Oxygen'),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHeroCard(
                          isConnected: isConnected,
                          spo2Display: spo2Display,
                          bpmDisplay: bpmDisplay,
                          timeStr: timeStr,
                          outcome: outcome,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildWeeklyTrend(spo2),
                              const SizedBox(height: 12),
                              _buildTipAndAlert(outcome, spo2Display),
                              const SizedBox(height: 16),
                              _buildHistory(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
    required String spo2Display,
    required String bpmDisplay,
    required String timeStr,
    required String outcome,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.pinkGradient,
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
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.greenAccent : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'Live' : 'No device',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isConnected ? Colors.greenAccent : Colors.white54,
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
                    child: const Icon(Icons.show_chart, color: Colors.white, size: 18),
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
                  text: spo2Display,
                  style: GoogleFonts.inter(
                    fontSize: 80,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: '\n%',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
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
              4,
              (i) => Container(
                width: i == 1 ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == 1 ? Colors.white : Colors.white38,
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
              _buildCardStat('O₂', ''),
              Container(width: 1, height: 30, color: Colors.white30),
              _buildCardStat(outcome == '--' ? '--' : outcome, 'OUTCOME'),
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
            fontSize: label.isEmpty ? 22 : 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
          ),
      ],
    );
  }

  Widget _buildWeeklyTrend(int? latestSpo2) {
    final todayIndex = DateTime.now().weekday - 1;
    final readings = [97, 98, 96, 97, 95, 98, 97];
    if (latestSpo2 != null) readings[todayIndex] = latestSpo2;
    final maxVal = readings.reduce((a, b) => a > b ? a : b);
    final minVal = 90;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WEEKLY TREND',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Relatively Stable',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final isLive = i == todayIndex && latestSpo2 != null;
              final h = ((readings[i] - minVal) / (maxVal - minVal + 1)).clamp(0.2, 1.0);
              return Container(
                width: 8,
                height: 40 * h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isLive ? AppColors.primary : const Color(0xFFE0E0F5),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTipAndAlert(String outcome, String spo2Display) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.alertBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.info, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Pro Tip',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Check oxygen levels after light exercise for more accurate endurance data.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildAlertCard(outcome, spo2Display)),
      ],
    );
  }

  Widget _buildAlertCard(String outcome, String spo2Display) {
    if (outcome == '--') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 18),
                const SizedBox(width: 6),
                Text(
                  'No Reading',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Turn on the oximeter to start a reading.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (outcome == 'Good') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 18),
                const SizedBox(width: 6),
                Text(
                  'Good',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Oxygen level ($spo2Display%) is in the healthy range.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (outcome == 'Low') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.alertOrange,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Alert',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reading ($spo2Display%) is lower than usual. Consider re-testing.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // Critical (<90%)
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.priority_high_rounded, color: AppColors.danger, size: 18),
              const SizedBox(width: 6),
              Text(
                'Critical',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'SpO₂ ($spo2Display%) is critically low. Seek medical attention.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF374151),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'History',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'SEE ALL',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildHistoryItem(
          icon: Icons.calendar_today_outlined,
          iconColor: const Color(0xFFE88FA8),
          title: 'Yesterday, 10:24 PM',
          subtitle: 'Handheld Reading',
          value: '98%',
        ),
        const SizedBox(height: 8),
        _buildHistoryItem(
          icon: Icons.bedtime_outlined,
          iconColor: AppColors.primary,
          title: 'May 21, 03:15 AM',
          subtitle: 'Sleep Monitoring',
          value: '96%',
        ),
      ],
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
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
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/ble_scan_service.dart';
import '../../theme/app_colors.dart';

class BodyTemperatureScreen extends StatelessWidget {
  const BodyTemperatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Consumer<BleScanService>(
          builder: (context, ble, _) {
            final temp = ble.readings.temperature;
            final tempDisplay = ble.readings.temperatureDisplay;
            final lastUpdated = ble.readings.lastUpdated;
            final outcome = _getOutcome(temp);
            final timeStr = lastUpdated != null ? _formatTime(lastUpdated) : '--:--';

            return Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      children: [
                        _buildHeroCard(ble, tempDisplay, timeStr, outcome),
                        const SizedBox(height: 16),
                        _buildAlert(outcome, temp),
                        const SizedBox(height: 16),
                        _buildWeeklyInsights(temp),
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

  static String _getOutcome(double? temp) {
    if (temp == null) return '--';
    if (temp < 35.0) return 'Very Low';
    if (temp < 36.1) return 'Low';
    if (temp <= 37.2) return 'Normal';
    if (temp <= 38.0) return 'Slight Fever';
    if (temp <= 39.0) return 'Fever';
    return 'High Fever';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Body Temperature',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            'FAMILY WATCH TODAY',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BleScanService ble, String tempDisplay, String timeStr, String outcome) {
    final isConnected = ble.registeredDevices
        .any((d) => d.type.name == 'temperature' && d.connected);

    return Container(
      width: double.infinity,
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
              _buildCircleButton(Icons.refresh_rounded),
              // Connection status indicator
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
                  _buildCircleButton(Icons.trending_up_rounded),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Temperature value
          Text(
            tempDisplay,
            style: GoogleFonts.inter(
              fontSize: 80,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '°C',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.3), thickness: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'No Event',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'EVENT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.thermostat_rounded,
                  color: Color(0xFFFF8A65),
                  size: 28,
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      if (outcome == 'High Fever' || outcome == 'Fever')
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.white),
                      if (outcome == 'High Fever' || outcome == 'Fever')
                        const SizedBox(width: 4),
                      Text(
                        outcome == '--' ? '--' : _shortOutcome(outcome),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'OUTCOME',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Container(
                width: i == 3 ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == 3 ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortOutcome(String outcome) {
    if (outcome == 'High Fever') return 'High';
    if (outcome == 'Slight Fever') return 'Slight';
    return outcome;
  }

  Widget _buildCircleButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildAlert(String outcome, double? temp) {
    if (outcome == '--' || outcome == 'Normal') {
      // Show a calm green "Normal" card when no reading or normal temp
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outcome == '--' ? 'No Reading Yet' : 'Normal Temperature',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    outcome == '--'
                        ? 'Turn on the thermometer device to start reading.'
                        : 'Temperature is within the healthy range.',
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

    if (outcome == 'Low' || outcome == 'Very Low') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF90CAF9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF1976D2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.thermostat_outlined,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Low Temperature',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Body temperature is below normal range.',
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

    if (outcome == 'Slight Fever') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFFF9800),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slight Fever',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Temperature is slightly elevated. Rest and stay hydrated.',
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

    // Fever or High Fever
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.priority_high_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outcome,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  outcome == 'High Fever'
                      ? 'Consider checking with a doctor if symptoms persist.'
                      : 'Monitor temperature closely. Rest and stay hydrated.',
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

  Widget _buildWeeklyInsights(double? latestTemp) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    // Static history; today's slot gets the live reading if available
    final readings = [36.8, 37.2, 36.6, 38.1, 36.5, 37.0, 37.4];
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon, 6=Sun
    if (latestTemp != null) {
      readings[todayIndex] = latestTemp;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Insights',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Last 7 Days',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.info,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.info, size: 18),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = i == todayIndex;
                final isLive = isToday && latestTemp != null;
                return _buildBarColumn(days[i], readings[i], isLive: isLive);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarColumn(String day, double value, {bool isLive = false}) {
    const minV = 36.0, maxV = 39.5;
    const barH = 120.0;
    final dotPosition = 1.0 - ((value - minV) / (maxV - minV)).clamp(0.0, 1.0);
    final dotColor = isLive ? const Color(0xFFFF8A65) : const Color(0xFF4A9EFF);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 36,
          height: barH,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 36,
                height: barH,
                decoration: BoxDecoration(
                  color: isLive
                      ? const Color(0xFFFFE0B2)
                      : const Color(0xFFDEEFF8),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              Positioned(
                top: dotPosition * (barH - 12),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isLive ? FontWeight.w700 : FontWeight.w600,
            color: isLive ? AppColors.textDark : AppColors.textMedium,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/ble_scan_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vitals_app_bar.dart';

class BodyCompositionScreen extends StatefulWidget {
  const BodyCompositionScreen({super.key});

  @override
  State<BodyCompositionScreen> createState() => _BodyCompositionScreenState();
}

class _BodyCompositionScreenState extends State<BodyCompositionScreen> {
  int _selectedRange = 0; // 0=W, 1=M, 2=6M

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
            final weight = ble.readings.weight;
            final weightDisplay = ble.readings.weightDisplay;
            final lastUpdated = ble.readings.lastUpdated;
            final timeStr = lastUpdated != null ? _formatTime(lastUpdated) : null;
            final isConnected = ble.registeredDevices
                .any((d) => d.type.name == 'weight' && d.connected);

            final bodyWaterDisplay = ble.readings.bodyWater != null
                ? '${ble.readings.bodyWater!.toStringAsFixed(1)} L'
                : '--';
            final leanMassDisplay = ble.readings.leanMass != null
                ? '${ble.readings.leanMass!.toStringAsFixed(1)} kgs'
                : '--';
            final fatMassDisplay = ble.readings.fatMass != null
                ? '${ble.readings.fatMass!.toStringAsFixed(1)} kgs'
                : '--';
            final bodyFatDisplay = ble.readings.bodyFatPercent != null
                ? '${ble.readings.bodyFatPercent!.toStringAsFixed(1)} %'
                : '--';
            final bmiDisplay = ble.readings.bmi != null
                ? ble.readings.bmi!.toStringAsFixed(1)
                : '--';
            final bmiLabel = ble.readings.bmiCategory != null
                ? 'BMI - ${ble.readings.bmiCategory!.toUpperCase()}'
                : 'BMI';
            final outcomeDisplay = ble.readings.bmiCategory ?? '--';

            return Column(
              children: [
                const VitalsAppBar(title: 'Vitals'),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildHeroCard(
                          weightDisplay: weightDisplay,
                          timeStr: timeStr,
                          isConnected: isConnected,
                          bodyWaterDisplay: bodyWaterDisplay,
                          leanMassDisplay: leanMassDisplay,
                          fatMassDisplay: fatMassDisplay,
                          bodyFatDisplay: bodyFatDisplay,
                          bmiDisplay: bmiDisplay,
                          bmiLabel: bmiLabel,
                          outcomeDisplay: outcomeDisplay,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildWeightProgress(weight),
                              const SizedBox(height: 12),
                              _buildActionButtons(),
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
    required String weightDisplay,
    required String? timeStr,
    required bool isConnected,
    required String bodyWaterDisplay,
    required String leanMassDisplay,
    required String fatMassDisplay,
    required String bodyFatDisplay,
    required String bmiDisplay,
    required String bmiLabel,
    required String outcomeDisplay,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Connection status row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: weightDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: ' kgs',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated Body Composition',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBodyStat(bodyWaterDisplay, 'BODY WATER'),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildBodyStat(leanMassDisplay, 'LEAN MASS'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBodyStat(fatMassDisplay, 'FAT MASS'),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildBodyStat(bodyFatDisplay, 'BODY FAT %'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            timeStr ?? '-- : --',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBmiStat(bmiDisplay, bmiLabel),
                const Icon(Icons.crop_square_outlined, color: Colors.white70, size: 18),
                _buildBmiStat(outcomeDisplay, 'OUTCOME'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white60,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBmiStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildWeightProgress(double? latestWeight) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weight Progress',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: ['W', 'M', '6M'].asMap().entries.map((e) {
                    final isSelected = e.key == _selectedRange;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRange = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          e.value,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textMedium,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: _buildBarChart(latestWeight),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Interactive Trend Data',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(double? latestWeight) {
    final values = [0.6, 0.7, 0.65, 0.8, 0.75, 0.85, 0.9];
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon, 6=Sun

    // Normalize today's live weight into a 0–1 bar height if available
    if (latestWeight != null) {
      const minW = 40.0, maxW = 120.0;
      values[todayIndex] =
          ((latestWeight - minW) / (maxW - minW)).clamp(0.1, 1.0);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.asMap().entries.map((e) {
        final isToday = e.key == todayIndex;
        final isLive = isToday && latestWeight != null;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              height: 100 * e.value,
              decoration: BoxDecoration(
                color: isLive
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : const Color(0xFFBBDEFB),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add,
                        color: AppColors.textDark, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Weight',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Update your daily entry',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMedium,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Coach',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Get diet & exercise tips',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

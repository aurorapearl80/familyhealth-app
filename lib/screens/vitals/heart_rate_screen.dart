import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/ble_summary_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vitals_app_bar.dart';
import 'body_temperature_screen.dart';
import '../../widgets/lottie_background.dart';

class HeartRateScreen extends StatelessWidget {
  const HeartRateScreen({super.key});

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  static String _hrStatus(int? hr) {
    if (hr == null) return 'No Reading';
    if (hr < 60) return 'Low';
    if (hr <= 100) return 'Normal';
    return 'Elevated';
  }

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<BleSummaryService>();
    final hr = summary.heartRate;
    final hrDisplay = hr?.toString() ?? '--';
    final hrTimeStr = summary.heartRateDate != null
        ? _formatTimeAgo(summary.heartRateDate!)
        : 'no data';
    final hrStatus = _hrStatus(hr);

    final temp = summary.temperature;
    final tempDisplay = temp != null ? temp.toStringAsFixed(1) : '--';
    final tempStatus = temp == null
        ? 'No Reading'
        : temp <= 37.2
            ? 'Normal'
            : temp <= 38.0
                ? 'Slight Fever'
                : 'Fever';

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: LottieBackground(child: SafeArea(
        child: Column(
          children: [
            const VitalsAppBar(title: 'Vitals'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeroCard(hrDisplay, hrTimeStr),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildAiInsights(hrDisplay, hrStatus),
                          const SizedBox(height: 12),
                          _buildStatsRow(),
                          const SizedBox(height: 12),
                          _buildBodyTemperatureCard(context, tempDisplay, tempStatus),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildHeroCard(String hrDisplay, String hrTimeStr) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
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
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: hrDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 72,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: '\nbpm',
                  style: GoogleFonts.inter(
                    fontSize: 18,
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
            hrTimeStr,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 16),
          // ECG waveform
          SizedBox(
            height: 50,
            child: CustomPaint(
              painter: _EcgPainter(color: Colors.white70),
              size: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
          // Pagination dots
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardStat('30 sec', 'LENGTH'),
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
            fontSize: 16,
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

  Widget _buildAiInsights(String hrDisplay, String hrStatus) {
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.alertBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: AppColors.info, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Insights',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hrDisplay == '--'
                ? 'No heart rate data available yet. Connect your BLE device to start a reading.'
                : 'Your latest heart rate is $hrDisplay bpm — status: $hrStatus. '
                    'Factors like stress or poor sleep can influence readings.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'AVG WEEKLY',
            value: '74 bpm',
            valueColor: AppColors.primary,
            footer: Container(
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'CONSISTENCY',
            value: 'High',
            valueColor: AppColors.textDark,
            footer: Row(
              children: [
                const Icon(Icons.arrow_downward, size: 12, color: AppColors.danger),
                Text(
                  '2% vs last month',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color valueColor,
    required Widget footer,
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
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          footer,
        ],
      ),
    );
  }

  Widget _buildBodyTemperatureCard(
      BuildContext context, String tempDisplay, String tempStatus) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BodyTemperatureScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1C1B1C).withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF0EEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.thermostat_outlined,
                color: Color(0xFF6B5CF0),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BODY TEMPERATURE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tempDisplay,
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2, left: 3),
                        child: Text(
                          '°C',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7EF),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    tempStatus,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tempStatus == 'Normal'
                          ? const Color(0xFF1A9E5C)
                          : tempStatus == 'No Reading'
                              ? AppColors.textMedium
                              : AppColors.warning,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textLight),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  final Color color;
  _EcgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final midY = size.height / 2;
    final path = Path();
    path.moveTo(0, midY);
    path.lineTo(size.width * 0.08, midY);
    path.lineTo(size.width * 0.13, midY - 10);
    path.lineTo(size.width * 0.17, midY + 25);
    path.lineTo(size.width * 0.21, midY - 40);
    path.lineTo(size.width * 0.25, midY + 8);
    path.lineTo(size.width * 0.30, midY);
    path.lineTo(size.width * 0.48, midY);
    path.lineTo(size.width * 0.53, midY - 10);
    path.lineTo(size.width * 0.57, midY + 25);
    path.lineTo(size.width * 0.61, midY - 40);
    path.lineTo(size.width * 0.65, midY + 8);
    path.lineTo(size.width * 0.70, midY);
    path.lineTo(size.width * 0.88, midY);
    path.lineTo(size.width * 0.93, midY - 10);
    path.lineTo(size.width * 0.97, midY + 25);
    path.lineTo(size.width, midY - 15);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

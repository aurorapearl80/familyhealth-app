import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class BloodGlucoseScreen extends StatelessWidget {
  const BloodGlucoseScreen({super.key});

  // Weekly readings in mg/dL
  static const _readings = [98.0, 112.0, 88.0, 105.0, 76.0, 95.0, 103.0];
  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  static const _blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 20),
                    _buildInsightsHeader(),
                    const SizedBox(height: 12),
                    _buildChartCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              'Blood Glucose',
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

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _blueGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircleButton(Icons.refresh_rounded),
              _buildCircleButton(Icons.show_chart_rounded),
            ],
          ),
          const SizedBox(height: 20),
          // Value
          Text(
            '100',
            style: GoogleFonts.inter(
              fontSize: 88,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'mg/dL',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '4 days ago',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'No Event',
                    style: GoogleFonts.inter(
                      fontSize: 17,
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
              // Center blood drop circle
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF0288D1),
                  size: 28,
                ),
              ),
              Column(
                children: [
                  Text(
                    'Good',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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
          // Pagination dots — 2nd active
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
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
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildInsightsHeader() {
    return Row(
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
    );
  }

  Widget _buildChartCard() {
    const maxV = 120.0;
    const minV = 60.0;
    const chartH = 140.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: chartH + 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final normalized =
                    ((_readings[i] - minV) / (maxV - minV)).clamp(0.0, 1.0);
                final barH = 24.0 + normalized * (chartH - 24.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF29B6F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Variable-height bar with rounded top
                    Container(
                      width: 38,
                      height: barH,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6EEF8),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _days[i],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

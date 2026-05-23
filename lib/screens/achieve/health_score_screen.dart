import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../theme/app_colors.dart';

class HealthScoreScreen extends StatelessWidget {
  const HealthScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildTitle(),
                    const SizedBox(height: 24),
                    _buildScoreCircle(),
                    const SizedBox(height: 32),
                    _buildImproveSection(),
                    const SizedBox(height: 16),
                    _buildActivityCard(),
                    const SizedBox(height: 24),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              'WITHINGS+',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Health Improvement\nScore',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Amazing! Your health improvement score has\nincreased by 3 points since last week.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCircle() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(260, 260),
            painter: _OrbitDotsPainter(),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '23-28 Jan 2025',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '68',
                style: GoogleFonts.inter(
                  fontSize: 72,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'of 100',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart, color: Colors.white60, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImproveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Improve Next Score',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Updated every Monday, your score captures your health data from the last 90 days to assess your global health.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A00),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3A00)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart, color: AppColors.warning, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Activity',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart, color: Colors.white54, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildScoreStat('PREVIOUS', '87', '+3pts'),
              ),
              Container(width: 1, height: 50, color: Colors.white12),
              Expanded(
                child: _buildScoreStat('LATEST', '87', '+3pts'),
              ),
              Container(width: 1, height: 50, color: Colors.white12),
              Expanded(
                child: _buildPredictionStat(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDottedChart(),
        ],
      ),
    );
  }

  Widget _buildScoreStat(String label, String value, String change) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white38,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          change,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionStat() {
    return Column(
      children: [
        Text(
          'PREDICTION',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white38,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Icon(Icons.star, color: AppColors.warning, size: 28),
      ],
    );
  }

  Widget _buildDottedChart() {
    return SizedBox(
      height: 40,
      child: CustomPaint(
        painter: _DottedLinePainter(),
        size: const Size(double.infinity, 40),
      ),
    );
  }
}

class _OrbitDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final colors = [
      Colors.red, Colors.orange, Colors.yellow, Colors.green,
      Colors.blue, Colors.purple, Colors.pink, Colors.teal,
      Colors.amber, Colors.cyan, Colors.indigo, Colors.lime,
    ];

    for (int i = 0; i < colors.length; i++) {
      final angle = (i / colors.length) * 2 * math.pi - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final paint = Paint()
        ..color = colors[i].withOpacity(0.7)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.warning.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;

    final midY = size.height * 0.6;
    final endY = size.height * 0.3;

    while (startX < size.width) {
      final t = startX / size.width;
      final y = midY + (endY - midY) * t;
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // End dot
    canvas.drawCircle(
      Offset(size.width, endY),
      5,
      Paint()..color = AppColors.warning,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

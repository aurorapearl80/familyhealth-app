import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/ble_summary_service.dart';
import '../../services/connectivity_service.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../vitals/heart_rate_screen.dart';
import '../vitals/body_composition_screen.dart';
import '../../widgets/lottie_background.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log Out',
                style: GoogleFonts.inter(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.clearToken();
      if (context.mounted) {
        context.read<BleSummaryService>().clear();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: LottieBackground(child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildQuickStats(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'My Focus',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildWeightCard(context),
                    const SizedBox(height: 12),
                    _buildBodyCompositionCard(context),
                    const SizedBox(height: 12),
                    _buildEcgCard(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.lightCard,
            child: Icon(Icons.person, color: AppColors.textMedium, size: 22),
          ),
          const SizedBox(width: 10),
          // Title
          Text(
            'Home Dashboard',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          // ── Connectivity chip ──────────────────────────────────────────
          Consumer<ConnectivityService>(
            builder: (context, conn, _) {
              final (icon, color, bg) = switch (conn.quality) {
                ConnectionQuality.wifi => (
                    Icons.wifi_rounded,
                    const Color(0xFF2E7D32),
                    const Color(0xFFE8F5E9),
                  ),
                ConnectionQuality.mobile => (
                    Icons.signal_cellular_alt_rounded,
                    const Color(0xFFE65100),
                    const Color(0xFFFFF3E0),
                  ),
                ConnectionQuality.none => (
                    Icons.wifi_off_rounded,
                    AppColors.danger,
                    const Color(0xFFFFECEC),
                  ),
              };
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      conn.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Notifications
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: AppColors.textMedium),
            onPressed: () {},
          ),
          // ── Logout ─────────────────────────────────────────────────────
          IconButton(
            tooltip: 'Log Out',
            icon: Icon(Icons.logout_rounded, color: AppColors.textMedium),
            onPressed: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatChip(
              context,
              icon: Icons.favorite_outline,
              iconColor: const Color(0xFFFF6B8A),
              label: 'Health Score',
              onTap: () {},
            ),
            const SizedBox(width: 10),
            _buildStatChip(
              context,
              icon: Icons.flash_on,
              iconColor: const Color(0xFFFFD700),
              label: 'Activity',
              onTap: () {},
            ),
            const SizedBox(width: 10),
            _buildStatChip(
              context,
              icon: Icons.favorite,
              iconColor: const Color(0xFFFF4466),
              label: 'Heart',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HeartRateScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard(BuildContext context) {
    return _buildFocusCard(
      context,
      onTap: () {},
      icon: Icons.monitor_weight_outlined,
      iconColor: const Color(0xFFFF8A65),
      title: 'Weight',
      time: '07:41 AM',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '158 ',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextSpan(
                      text: 'lbs',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.arrow_downward, size: 14, color: AppColors.success),
                  const SizedBox(width: 2),
                  Text(
                    'Losing Weight',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildMiniLineChart(),
        ],
      ),
    );
  }

  Widget _buildBodyCompositionCard(BuildContext context) {
    return _buildFocusCard(
      context,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BodyCompositionScreen()),
      ),
      icon: Icons.accessibility_new_outlined,
      iconColor: const Color(0xFF64B5F6),
      title: 'Body Composition',
      time: '07:41 AM',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gaining Muscle',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCompStat('Muscle', '76.9%', const Color(0xFF4CAF50)),
              const SizedBox(width: 20),
              _buildCompStat('Fat', '19.1%', const Color(0xFF64B5F6)),
            ],
          ),
          const SizedBox(height: 8),
          _buildProgressBar(0.769, const Color(0xFF4CAF50)),
          const SizedBox(height: 4),
          _buildProgressBar(0.191, const Color(0xFF64B5F6)),
        ],
      ),
    );
  }

  Widget _buildEcgCard(BuildContext context) {
    return _buildFocusCard(
      context,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HeartRateScreen()),
      ),
      icon: Icons.favorite,
      iconColor: const Color(0xFFFF4466),
      title: 'ECG',
      time: '07:41 AM',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sinus Rhythm',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: AppColors.success),
              const SizedBox(width: 4),
              Text(
                'Heart Rate: 87 bpm',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEcgWave(),
        ],
      ),
    );
  }

  Widget _buildFocusCard(
    BuildContext context, {
    required Widget child,
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMedium,
                  ),
                ),
                const Spacer(),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: AppColors.textLight, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCompStat(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double value, Color color) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        widthFactor: value,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniLineChart() {
    return CustomPaint(
      size: const Size(80, 40),
      painter: _MiniLinePainter(
        points: [0.6, 0.5, 0.55, 0.45, 0.4, 0.35],
        color: const Color(0xFF64B5F6),
      ),
    );
  }

  Widget _buildEcgWave() {
    return SizedBox(
      height: 40,
      child: CustomPaint(
        painter: _EcgPainter(color: const Color(0xFF64B5F6)),
        size: const Size(double.infinity, 40),
      ),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _MiniLinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = points[i] * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    path.lineTo(size.width * 0.1, midY);
    path.lineTo(size.width * 0.15, midY - 8);
    path.lineTo(size.width * 0.18, midY + 20);
    path.lineTo(size.width * 0.22, midY - 30);
    path.lineTo(size.width * 0.26, midY + 5);
    path.lineTo(size.width * 0.30, midY);
    path.lineTo(size.width * 0.45, midY);
    path.lineTo(size.width * 0.50, midY - 8);
    path.lineTo(size.width * 0.53, midY + 20);
    path.lineTo(size.width * 0.57, midY - 30);
    path.lineTo(size.width * 0.61, midY + 5);
    path.lineTo(size.width * 0.65, midY);
    path.lineTo(size.width * 0.80, midY);
    path.lineTo(size.width * 0.85, midY - 8);
    path.lineTo(size.width * 0.88, midY + 20);
    path.lineTo(size.width * 0.92, midY - 30);
    path.lineTo(size.width * 0.96, midY + 5);
    path.lineTo(size.width, midY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

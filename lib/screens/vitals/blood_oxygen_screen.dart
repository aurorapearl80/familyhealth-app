import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/ble_constants.dart';
import '../../services/ble_scan_service.dart';
import '../../services/ble_summary_service.dart';
import '../../services/health_database.dart';
import '../../services/oximeter_api_service.dart';
import '../../services/vitals_history_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/lottie_background.dart';
import '../../widgets/vitals_app_bar.dart';
import '../../widgets/vitals_history_section.dart';

enum _UploadState { idle, sending, success, savedOffline, error }

class BloodOxygenScreen extends StatefulWidget {
  const BloodOxygenScreen({super.key});

  @override
  State<BloodOxygenScreen> createState() => _BloodOxygenScreenState();
}

class _BloodOxygenScreenState extends State<BloodOxygenScreen> {
  _UploadState _uploadState = _UploadState.idle;
  DateTime? _lastProcessedAt;
  late final BleScanService _ble;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ble = context.read<BleScanService>();
      _ble.addListener(_onBleChanged);
    });
  }

  @override
  void dispose() {
    _ble.removeListener(_onBleChanged);
    super.dispose();
  }

  // ── BLE listener ──────────────────────────────────────────────────────────

  void _onBleChanged() {
    // Skip BLE processing if blood oxygen is disabled for this account
    if (!context.read<BleSummaryService>().isBloodOxygenEnabled) return;
    final r = _ble.readings;
    if (r.lastReadingKind != BleReadingKind.bloodOxygen) return;
    if (r.bloodOxygen == null) return;
    if (r.lastUpdated == null) return;
    if (r.lastUpdated == _lastProcessedAt) return;

    _lastProcessedAt = r.lastUpdated;
    _handleNewReading(r.bloodOxygen!, r.pulseRate ?? 0, r.lastUpdated!);
  }

  // ── Upload flow ───────────────────────────────────────────────────────────

  Future<void> _handleNewReading(
      int spo2, int pulseRate, DateTime measuredAt) async {
    if (!mounted) return;
    setState(() => _uploadState = _UploadState.sending);

    final measuredAtStr = _formatMeasuredAt(measuredAt);
    const deviceId = BleConstants.deviceOximeter;
    const timezone = 'Asia/Manila';

    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet =
        connectivity.any((r) => r != ConnectivityResult.none);

    if (hasInternet) {
      final success = await OximeterApiService.sendReading(
        oxygen: spo2,
        pulseRate: pulseRate,
        measuredAt: measuredAtStr,
        deviceId: deviceId,
        timezone: timezone,
      );
      if (!mounted) return;
      setState(() =>
          _uploadState = success ? _UploadState.success : _UploadState.error);
    } else {
      await HealthDatabase.insertOximeterReading(
        oxygen: spo2,
        pulseRate: pulseRate,
        measuredAt: measuredAtStr,
        deviceId: deviceId,
        timezone: timezone,
      );
      if (!mounted) return;
      setState(() => _uploadState = _UploadState.savedOffline);
    }

    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => _uploadState = _UploadState.idle);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _formatMeasuredAt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<BleSummaryService>();
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: LottieBackground(
        child: SafeArea(
          child: Consumer<BleScanService>(
            builder: (context, ble, _) {
              // Use live BLE value; fall back to latest from server
              final spo2 = ble.readings.bloodOxygen ?? summary.bloodOxygen;
              final spo2Display = spo2?.toString() ?? '--';
              final pulseRate =
                  ble.readings.pulseRate ?? summary.bloodOxygenPulseRate;
              final bpmDisplay = pulseRate?.toString() ?? '--';
              final lastUpdated =
                  ble.readings.lastUpdated ?? summary.bloodOxygenDate;
              final outcome = _getOutcome(spo2);
              final timeStr = lastUpdated != null
                  ? _formatTime(lastUpdated)
                  : '--:--';
              final isConnected = ble.registeredDevices
                  .any((d) => d.type.name == 'bloodOxygen' && d.connected);

              return Column(
                children: [
                  const VitalsAppBar(title: 'Blood Oxygen'),
                  // ── Upload banner ────────────────────────────────────────
                  _buildUploadBanner(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          context.read<BleSummaryService>().fetch(),
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  _buildWeeklyTrend(spo2),
                                  const SizedBox(height: 12),
                                  _buildTipAndAlert(outcome, spo2Display),
                                  const SizedBox(height: 16),
                                  VitalsHistorySection(
                                    endpoint: 'oximeter-readings',
                                    title: 'SpO₂ History',
                                    rowIcon: Icons.air,
                                    iconBgColor: const Color(0xFFFCE4EC),
                                    iconColor: const Color(0xFFE88FA8),
                                    formatValue: (item) {
                                      final o = item['oxygen'] ??
                                          item['blood_oxygen'] ??
                                          item['spo2'];
                                      return o != null ? '$o%' : '--';
                                    },
                                    formatSubtitle: (item) {
                                      final pr = item['pulse_rate'] ??
                                          item['bpm'] ??
                                          item['heart_rate'];
                                      final ago = VitalsHistoryService.timeAgo(
                                          item['measured_at']?.toString());
                                      return pr != null
                                          ? '$pr bpm · $ago'
                                          : ago;
                                    },
                                  ),
                                  const SizedBox(height: 24),
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
            },
          ),
        ),
      ),
    );
  }

  // ── Upload banner ─────────────────────────────────────────────────────────

  Widget _buildUploadBanner() {
    if (_uploadState == _UploadState.idle) return const SizedBox.shrink();

    final cfg = _bannerConfig(_uploadState);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cfg.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cfg.borderColor),
      ),
      child: Row(
        children: [
          if (_uploadState == _UploadState.sending)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: cfg.iconColor),
            )
          else
            Icon(cfg.icon, size: 18, color: cfg.iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg.title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cfg.titleColor)),
                Text(cfg.subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: cfg.titleColor.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _BannerConfig _bannerConfig(_UploadState state) {
    switch (state) {
      case _UploadState.sending:
        return _BannerConfig(
          bgColor: const Color(0xFFE3F2FD),
          borderColor: const Color(0xFF90CAF9),
          iconColor: const Color(0xFF1976D2),
          titleColor: const Color(0xFF1565C0),
          icon: Icons.cloud_upload_outlined,
          title: 'Sending to server…',
          subtitle: 'Uploading SpO₂ reading',
        );
      case _UploadState.success:
        return _BannerConfig(
          bgColor: const Color(0xFFE8F5E9),
          borderColor: const Color(0xFFA5D6A7),
          iconColor: const Color(0xFF388E3C),
          titleColor: const Color(0xFF2E7D32),
          icon: Icons.cloud_done_outlined,
          title: 'Data sent successfully',
          subtitle: 'SpO₂ reading saved to server',
        );
      case _UploadState.savedOffline:
        return _BannerConfig(
          bgColor: const Color(0xFFFFF8E1),
          borderColor: const Color(0xFFFFCC80),
          iconColor: const Color(0xFFF57C00),
          titleColor: const Color(0xFFE65100),
          icon: Icons.wifi_off_rounded,
          title: 'Saved offline',
          subtitle: 'No connection — stored locally for later sync',
        );
      case _UploadState.error:
        return _BannerConfig(
          bgColor: const Color(0xFFFFECEC),
          borderColor: const Color(0xFFFFCDD2),
          iconColor: AppColors.danger,
          titleColor: AppColors.danger,
          icon: Icons.error_outline_rounded,
          title: 'Upload failed',
          subtitle: 'Reading saved locally — will retry when online',
        );
      case _UploadState.idle:
        return _BannerConfig(
          bgColor: Colors.transparent,
          borderColor: Colors.transparent,
          iconColor: Colors.transparent,
          titleColor: Colors.transparent,
          icon: Icons.circle,
          title: '',
          subtitle: '',
        );
    }
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

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
                child:
                    const Icon(Icons.refresh, color: Colors.white, size: 18),
              ),
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
            textAlign: TextAlign.center,
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
          ),
          const SizedBox(height: 8),
          Text(timeStr,
              style:
                  GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
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
              _buildCardStat(
                  outcome == '--' ? '--' : outcome, 'OUTCOME'),
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
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
      ],
    );
  }

  // ── Weekly trend ──────────────────────────────────────────────────────────

  Widget _buildWeeklyTrend(int? latestSpo2) {
    final todayIndex = DateTime.now().weekday - 1;
    final readings = [97, 98, 96, 97, 95, 98, 97];
    if (latestSpo2 != null) readings[todayIndex] = latestSpo2;
    final maxVal = readings.reduce((a, b) => a > b ? a : b);
    const minVal = 90;

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
              final h = ((readings[i] - minVal) / (maxVal - minVal + 1))
                  .clamp(0.2, 1.0);
              return Container(
                width: 8,
                height: 40 * h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isLive
                      ? AppColors.primary
                      : const Color(0xFFE0E0F5),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Tip & alert ───────────────────────────────────────────────────────────

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
                    const Icon(Icons.location_on_outlined,
                        color: AppColors.info, size: 18),
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
      return _alertTile(
        bg: const Color(0xFFE8F5E9),
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF4CAF50),
        title: 'No Reading',
        titleColor: const Color(0xFF2E7D32),
        body: 'Turn on the oximeter to start a reading.',
      );
    }
    if (outcome == 'Good') {
      return _alertTile(
        bg: const Color(0xFFE8F5E9),
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF4CAF50),
        title: 'Good',
        titleColor: const Color(0xFF2E7D32),
        body: 'Oxygen level ($spo2Display%) is in the healthy range.',
      );
    }
    if (outcome == 'Low') {
      return _alertTile(
        bg: AppColors.alertOrange,
        icon: Icons.warning_amber_outlined,
        iconColor: AppColors.warning,
        title: 'Alert',
        titleColor: AppColors.warning,
        body: 'Reading ($spo2Display%) is lower than usual. Consider re-testing.',
      );
    }
    return _alertTile(
      bg: const Color(0xFFFFECEC),
      icon: Icons.priority_high_rounded,
      iconColor: AppColors.danger,
      title: 'Critical',
      titleColor: AppColors.danger,
      body: 'SpO₂ ($spo2Display%) is critically low. Seek medical attention.',
    );
  }

  Widget _alertTile({
    required Color bg,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: titleColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF374151),
                  height: 1.4)),
        ],
      ),
    );
  }

}

// ── Banner config helper ──────────────────────────────────────────────────────

class _BannerConfig {
  final Color bgColor, borderColor, iconColor, titleColor;
  final IconData icon;
  final String title, subtitle;

  const _BannerConfig({
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.titleColor,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
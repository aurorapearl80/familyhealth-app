import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/ble_constants.dart';
import '../../services/ble_scan_service.dart';
import '../../services/ble_summary_service.dart';
import '../../services/health_database.dart';
import '../../services/temperature_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/lottie_background.dart';
import '../../widgets/vitals_history_section.dart';

// Upload state machine
enum _UploadState { idle, sending, success, savedOffline, error }

class BodyTemperatureScreen extends StatefulWidget {
  const BodyTemperatureScreen({super.key});

  @override
  State<BodyTemperatureScreen> createState() => _BodyTemperatureScreenState();
}

class _BodyTemperatureScreenState extends State<BodyTemperatureScreen> {
  // ── Upload state ──────────────────────────────────────────────────────────
  _UploadState _uploadState = _UploadState.idle;

  // Track the timestamp of the last reading we already processed so we don't
  // re-send on every notifyListeners() rebuild.
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

  // ── BLE listener ─────────────────────────────────────────────────────────

  void _onBleChanged() {
    // Skip BLE processing if temperature is disabled for this account
    if (!context.read<BleSummaryService>().isTemperatureEnabled) return;
    final readings = _ble.readings;

    // Only react to fresh temperature readings
    if (readings.lastReadingKind != BleReadingKind.temperature) return;
    if (readings.temperature == null) return;
    if (readings.lastUpdated == null) return;
    if (readings.lastUpdated == _lastProcessedAt) return;

    _lastProcessedAt = readings.lastUpdated;
    _handleNewReading(readings.temperature!, readings.lastUpdated!);
  }

  // ── Upload flow ───────────────────────────────────────────────────────────

  Future<void> _handleNewReading(double tempC, DateTime measuredAt) async {
    if (!mounted) return;
    setState(() => _uploadState = _UploadState.sending);

    final measuredAtStr = _formatMeasuredAt(measuredAt);
    const deviceId = BleConstants.deviceTemperature;
    const timezone = 'Asia/Manila';

    // 1. Check internet connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet =
        connectivity.any((r) => r != ConnectivityResult.none);

    if (hasInternet) {
      // 2a. Online → send to server
      final success = await TemperatureApiService.sendReading(
        temperature: tempC,
        measuredAt: measuredAtStr,
        deviceId: deviceId,
        timezone: timezone,
      );

      if (!mounted) return;
      setState(() =>
          _uploadState = success ? _UploadState.success : _UploadState.error);
    } else {
      // 2b. Offline → save to local DB
      await HealthDatabase.insertTemperatureReading(
        temperature: tempC,
        measuredAt: measuredAtStr,
        deviceId: deviceId,
        timezone: timezone,
      );

      if (!mounted) return;
      setState(() => _uploadState = _UploadState.savedOffline);
    }

    // Auto-clear status after 4 seconds
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => _uploadState = _UploadState.idle);
  }

  // ── Formatters ────────────────────────────────────────────────────────────

  static String _formatMeasuredAt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
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

  static String _shortOutcome(String outcome) {
    if (outcome == 'High Fever') return 'High';
    if (outcome == 'Slight Fever') return 'Slight';
    return outcome;
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
              final temp = ble.readings.temperature ?? summary.temperature;
              final tempDisplay = temp != null
                  ? temp.toStringAsFixed(1)
                  : '--';
              final lastUpdated =
                  ble.readings.lastUpdated ?? summary.temperatureDate;
              final outcome = _getOutcome(temp);
              final timeStr =
                  lastUpdated != null ? _formatTime(lastUpdated) : '--:--';

              return Column(
                children: [
                  _buildAppBar(context),
                  // ── Upload status banner ─────────────────────────────────
                  _buildUploadBanner(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          context.read<BleSummaryService>().fetch(),
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: Column(
                          children: [
                            _buildHeroCard(ble, tempDisplay, timeStr, outcome),
                            const SizedBox(height: 16),
                            _buildAlert(outcome, temp),
                            const SizedBox(height: 16),
                            _buildWeeklyInsights(temp),
                            const SizedBox(height: 16),
                            VitalsHistorySection(
                              endpoint: 'temperatures',
                              title: 'Temperature History',
                              rowIcon: Icons.thermostat_outlined,
                              iconBgColor: const Color(0xFFFFE0B2),
                              iconColor: const Color(0xFFFF8A65),
                              formatValue: (item) {
                                final raw = item['temperature'];
                                if (raw == null) return '--';
                                final t = num.tryParse(raw.toString());
                                return t != null
                                    ? '${t.toStringAsFixed(1)} °C'
                                    : '--';
                              },
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

    final config = _bannerConfig(_uploadState);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.borderColor),
      ),
      child: Row(
        children: [
          if (_uploadState == _UploadState.sending)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: config.iconColor,
              ),
            )
          else
            Icon(config.icon, size: 18, color: config.iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: config.titleColor,
                  ),
                ),
                Text(
                  config.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: config.titleColor.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          if (_uploadState == _UploadState.sending)
            const SizedBox.shrink()
          else
            Icon(Icons.check_circle_outline,
                size: 18, color: config.iconColor),
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
          subtitle: 'Uploading temperature reading',
        );
      case _UploadState.success:
        return _BannerConfig(
          bgColor: const Color(0xFFE8F5E9),
          borderColor: const Color(0xFFA5D6A7),
          iconColor: const Color(0xFF388E3C),
          titleColor: const Color(0xFF2E7D32),
          icon: Icons.cloud_done_outlined,
          title: 'Data sent successfully',
          subtitle: 'Temperature saved to server',
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

  // ── App bar ───────────────────────────────────────────────────────────────

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

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(
      BleScanService ble, String tempDisplay, String timeStr, String outcome) {
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
            style: GoogleFonts.inter(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Divider(
              color: Colors.white.withValues(alpha: 0.3), thickness: 1),
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
                child: const Icon(Icons.thermostat_rounded,
                    color: Color(0xFFFF8A65), size: 28),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      if (outcome == 'High Fever' || outcome == 'Fever') ...[
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
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

  // ── Alert card ────────────────────────────────────────────────────────────

  Widget _buildAlert(String outcome, double? temp) {
    if (outcome == '--' || outcome == 'Normal') {
      return _alertCard(
        bgColor: const Color(0xFFE8F5E9),
        borderColor: const Color(0xFFA5D6A7),
        iconBg: const Color(0xFF4CAF50),
        icon: Icons.check_rounded,
        title: outcome == '--' ? 'No Reading Yet' : 'Normal Temperature',
        message: outcome == '--'
            ? 'Turn on the thermometer device to start reading.'
            : 'Temperature is within the healthy range.',
        titleColor: const Color(0xFF2E7D32),
      );
    }
    if (outcome == 'Low' || outcome == 'Very Low') {
      return _alertCard(
        bgColor: const Color(0xFFE3F2FD),
        borderColor: const Color(0xFF90CAF9),
        iconBg: const Color(0xFF1976D2),
        icon: Icons.thermostat_outlined,
        title: 'Low Temperature',
        message: 'Body temperature is below normal range.',
        titleColor: const Color(0xFF1565C0),
      );
    }
    if (outcome == 'Slight Fever') {
      return _alertCard(
        bgColor: const Color(0xFFFFF3E0),
        borderColor: const Color(0xFFFFCC80),
        iconBg: const Color(0xFFFF9800),
        icon: Icons.warning_rounded,
        title: 'Slight Fever',
        message: 'Temperature is slightly elevated. Rest and stay hydrated.',
        titleColor: const Color(0xFFE65100),
      );
    }
    return _alertCard(
      bgColor: const Color(0xFFFFECEC),
      borderColor: const Color(0xFFFFCDD2),
      iconBg: AppColors.danger,
      icon: Icons.priority_high_rounded,
      title: outcome,
      message: outcome == 'High Fever'
          ? 'Consider checking with a doctor if symptoms persist.'
          : 'Monitor temperature closely. Rest and stay hydrated.',
      titleColor: AppColors.danger,
    );
  }

  Widget _alertCard({
    required Color bgColor,
    required Color borderColor,
    required Color iconBg,
    required IconData icon,
    required String title,
    required String message,
    required Color titleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor)),
                const SizedBox(height: 4),
                Text(message,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMedium,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly insights ───────────────────────────────────────────────────────

  Widget _buildWeeklyInsights(double? latestTemp) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final readings = [36.8, 37.2, 36.6, 38.1, 36.5, 37.0, 37.4];
    final todayIndex = DateTime.now().weekday - 1;
    if (latestTemp != null) readings[todayIndex] = latestTemp;

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
          Text(
            'Weekly Insights',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
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
    const minV = 36.0, maxV = 39.5, barH = 120.0;
    final dotPosition =
        1.0 - ((value - minV) / (maxV - minV)).clamp(0.0, 1.0);
    final dotColor =
        isLive ? const Color(0xFFFF8A65) : const Color(0xFF4A9EFF);

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
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
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

// ── Banner config helper ──────────────────────────────────────────────────────

class _BannerConfig {
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final Color titleColor;
  final IconData icon;
  final String title;
  final String subtitle;

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
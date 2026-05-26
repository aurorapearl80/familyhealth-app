import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/device_readings.dart';
import '../../services/ble_constants.dart';
import '../../services/ble_scan_service.dart';
import '../../services/ble_summary_service.dart';
import '../../services/blood_glucose_api_service.dart';
import '../../services/health_database.dart';
import '../../theme/app_colors.dart';
import '../../widgets/lottie_background.dart';

enum _UploadState { idle, sending, success, savedOffline, error }

class BloodGlucoseScreen extends StatefulWidget {
  const BloodGlucoseScreen({super.key});

  @override
  State<BloodGlucoseScreen> createState() => _BloodGlucoseScreenState();
}

class _BloodGlucoseScreenState extends State<BloodGlucoseScreen> {
  _UploadState _uploadState = _UploadState.idle;
  DateTime? _lastProcessedAt;

  static const _deviceId = '5e4c0db6bc20236a64ca3467';
  static const _timezone = 'Asia/Manila';

  // Weekly chart data (static display)
  static const _readings = [98.0, 112.0, 88.0, 105.0, 76.0, 95.0, 103.0];
  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  static const _blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
  );

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleScanService>().addListener(_onBleChanged);
    });
  }

  @override
  void dispose() {
    context.read<BleScanService>().removeListener(_onBleChanged);
    super.dispose();
  }

  // ── BLE listener ──────────────────────────────────────────────────────────

  void _onBleChanged() {
    final ble = context.read<BleScanService>();
    if (ble.readings.lastReadingKind != BleReadingKind.bloodGlucose) return;
    final updated = ble.readings.lastUpdated;
    if (updated == null || updated == _lastProcessedAt) return;
    _lastProcessedAt = updated;
    _handleNewReading(ble.readings);
  }

  Future<void> _handleNewReading(DeviceReadings readings) async {
    final glucoseRaw = readings.bloodGlucose;
    if (glucoseRaw == null) return;

    final glucose = glucoseRaw.toDouble();
    // Convert mg/dL → mmol/L (mail_value)
    final mailValue = double.parse((glucose / 18.02).toStringAsFixed(2));
    final measuredAt = _formatMeasuredAt(readings.lastUpdated ?? DateTime.now());

    setState(() => _uploadState = _UploadState.sending);

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((r) => r != ConnectivityResult.none);

    if (isOnline) {
      final ok = await BloodGlucoseApiService.sendReading(
        glucose: glucose,
        mailValue: mailValue,
        measuredAt: measuredAt,
        deviceId: _deviceId,
        timezone: _timezone,
      );
      setState(() => _uploadState = ok ? _UploadState.success : _UploadState.error);
    } else {
      await HealthDatabase.insertGlucoseReading(
        glucose: glucose,
        mailValue: mailValue,
        measuredAt: measuredAt,
        deviceId: _deviceId,
        timezone: _timezone,
      );
      setState(() => _uploadState = _UploadState.savedOffline);
    }

    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => _uploadState = _UploadState.idle);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatMeasuredAt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  String _glucoseStatus(int? v) {
    if (v == null) return 'No Data';
    if (v < 70) return 'Low';
    if (v <= 99) return 'Normal';
    if (v <= 125) return 'Pre-diabetic';
    return 'High';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Normal':
        return AppColors.success;
      case 'Pre-diabetic':
        return AppColors.warning;
      case 'High':
        return AppColors.danger;
      case 'Low':
        return AppColors.danger;
      default:
        return AppColors.textMedium;
    }
  }

  // ── Upload banner ─────────────────────────────────────────────────────────

  Widget _buildUploadBanner() {
    if (_uploadState == _UploadState.idle) return const SizedBox.shrink();

    final (Color bg, IconData icon, String message) = switch (_uploadState) {
      _UploadState.sending => (
          Colors.blueGrey.shade700,
          Icons.cloud_upload_outlined,
          'Sending reading to server…',
        ),
      _UploadState.success => (
          AppColors.success,
          Icons.cloud_done_outlined,
          'Reading uploaded successfully.',
        ),
      _UploadState.savedOffline => (
          Colors.orange.shade700,
          Icons.save_outlined,
          'No connection — saved offline.',
        ),
      _UploadState.error => (
          AppColors.danger,
          Icons.cloud_off_outlined,
          'Upload failed. Will retry later.',
        ),
      _UploadState.idle => (Colors.transparent, Icons.circle, ''),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (_uploadState == _UploadState.sending)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          else
            Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
              // Summary glucose is in mg/dL as double; BLE is int (mg/dL)
              final glucoseRaw = ble.readings.bloodGlucose ??
                  summary.glucose?.toInt();
              final lastUpdated =
                  ble.readings.lastUpdated ?? summary.glucoseDate;
              final status = _glucoseStatus(glucoseRaw);
              final statusColor = _statusColor(status);

              final glucoseDisplay = glucoseRaw?.toString() ?? '--';
              final timeStr = lastUpdated != null
                  ? _formatTimeAgo(lastUpdated)
                  : '--';

              return Column(
                children: [
                  _buildAppBar(context),
                  _buildUploadBanner(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroCard(
                            glucoseDisplay: glucoseDisplay,
                            timeStr: timeStr,
                            status: status,
                            statusColor: statusColor,
                          ),
                          const SizedBox(height: 20),
                          _buildInsightsHeader(),
                          const SizedBox(height: 12),
                          _buildChartCard(),
                        ],
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

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

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

  Widget _buildHeroCard({
    required String glucoseDisplay,
    required String timeStr,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _blueGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircleButton(Icons.refresh_rounded),
              _buildCircleButton(Icons.show_chart_rounded),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            glucoseDisplay,
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
            timeStr,
            style: GoogleFonts.inter(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'STATUS',
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
                    _uploadState == _UploadState.success ? 'Synced' : 'Good',
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
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF29B6F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 38,
                      height: barH,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD6EEF8),
                        borderRadius: BorderRadius.vertical(
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
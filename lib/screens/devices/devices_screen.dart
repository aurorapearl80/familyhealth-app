import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/ble_device_info.dart';
import '../../services/ble_constants.dart';
import '../../services/ble_scan_service.dart';
import '../../services/ble_summary_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_avatar.dart';
import '../vitals/blood_oxygen_screen.dart';
import '../vitals/blood_pressure_screen.dart';
import '../vitals/body_composition_screen.dart';
import '../vitals/heart_rate_screen.dart';
import '../vitals/body_temperature_screen.dart';
import '../vitals/blood_glucose_screen.dart';
import '../achieve/health_score_screen.dart';
import '../../widgets/lottie_background.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch both providers so the grid rebuilds when either changes
    final summary = context.watch<BleSummaryService>();
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: LottieBackground(child: SafeArea(
        child: Consumer<BleScanService>(
          builder: (context, ble, _) {
            return Column(
              children: [
                _buildHeader(ble),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => context.read<BleSummaryService>().fetch(),
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      // physics must allow overscroll for RefreshIndicator to trigger
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusBanner(ble),
                          const SizedBox(height: 12),
                          _buildSectionTitle('Health Vitals'),
                          const SizedBox(height: 12),
                          _buildVitalsGrid(context, ble, summary),
                          const SizedBox(height: 20),
                          _buildSectionTitle('Connected Devices'),
                          const SizedBox(height: 12),
                          _buildDevicesList(ble, summary),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      )),
    );
  }

  Widget _buildHeader(BleScanService ble) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Vitals',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Row(
            children: [
              Icon(
                ble.isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                color: ble.isScanning ? AppColors.primary : AppColors.textLight,
                size: 22,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textDark),
                onPressed: () {},
              ),
              const ProfileAvatar(radius: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BleScanService ble) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ble.isScanning ? AppColors.success : AppColors.textLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ble.status,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMedium,
              ),
            ),
          ),
          if (ble.readings.lastUpdated != null)
            Text(
              _formatTime(ble.readings.lastUpdated!),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildVitalsGrid(
      BuildContext context, BleScanService ble, BleSummaryService summary) {
    final r = ble.readings;

    // ── Resolved values: live BLE first, then server summary ─────────────────
    final heartRateVal =
        r.heartRate?.toString() ?? r.pulseRate?.toString() ??
        summary.heartRate?.toString() ?? '--';

    final bloodOxygenVal =
        r.bloodOxygen?.toString() ?? summary.bloodOxygen?.toString() ?? '--';

    final bpVal = (r.systolic != null && r.diastolic != null)
        ? '${r.systolic}/${r.diastolic}'
        : (summary.bpSystolic != null && summary.bpDiastolic != null)
            ? '${summary.bpSystolic}/${summary.bpDiastolic}'
            : '--/--';

    final weightVal = r.weight?.toStringAsFixed(1) ??
        summary.weight?.toStringAsFixed(1) ?? '--';

    final tempVal = r.temperature?.toStringAsFixed(1) ??
        summary.temperature?.toStringAsFixed(1) ?? '--';

    final glucoseVal = r.bloodGlucose?.toString() ??
        summary.glucose?.toInt().toString() ?? '--';

    // Build the full list, then filter by types_availability
    final allVitals = <Map<String, Object>>[
      if (summary.isElectrocardiogramEnabled) {
        'title': 'Heart Rate',
        'value': heartRateVal,
        'unit': 'bpm',
        'gradient': AppColors.purpleGradient,
        'icon': Icons.favorite,
        'screen': const HeartRateScreen(),
      },
      if (summary.isBloodOxygenEnabled) {
        'title': 'Blood Oxygen',
        'value': bloodOxygenVal,
        'unit': '%',
        'gradient': AppColors.pinkGradient,
        'icon': Icons.air,
        'screen': const BloodOxygenScreen(),
      },
      if (summary.isBloodPressureEnabled) {
        'title': 'Blood Pressure',
        'value': bpVal,
        'unit': 'mmHg',
        'gradient': AppColors.orangeGradient,
        'icon': Icons.monitor_heart,
        'screen': const BloodPressureScreen(),
      },
      if (summary.isWeightEnabled) {
        'title': 'Body Comp',
        'value': weightVal,
        'unit': 'kgs',
        'gradient': AppColors.greenGradient,
        'icon': Icons.accessibility_new,
        'screen': const BodyCompositionScreen(),
      },
      // Health Score is always shown (not a device type)
      {
        'title': 'Health Score',
        'value': '68',
        'unit': '/100',
        'gradient': const LinearGradient(
          colors: [Color(0xFF1A2332), Color(0xFF0D1117)],
        ),
        'icon': Icons.star,
        'screen': const HealthScoreScreen(),
      },
      if (summary.isTemperatureEnabled) {
        'title': 'Body Temp',
        'value': tempVal,
        'unit': '°C',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9B7FF5), Color(0xFF5B3FD4)],
        ),
        'icon': Icons.thermostat_outlined,
        'screen': const BodyTemperatureScreen(),
      },
      if (summary.isBloodGlucoseEnabled) {
        'title': 'Blood Glucose',
        'value': glucoseVal,
        'unit': r.glucoseUnit ?? 'mg/dL',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
        ),
        'icon': Icons.water_drop_outlined,
        'screen': const BloodGlucoseScreen(),
      },
    ];
    final vitals = allVitals;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: vitals.length,
      itemBuilder: (context, i) {
        final v = vitals[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => v['screen'] as Widget),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: v['gradient'] as LinearGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(v['icon'] as IconData, color: Colors.white70, size: 22),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: v['value'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: ' ${v['unit']}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      v['title'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevicesList(BleScanService ble, BleSummaryService summary) {
    // Only show devices whose type is enabled via types_availability
    final displayDevices = ble.registeredDevices
        .where((d) => summary.isDeviceTypeEnabled(d.type))
        .toList();

    return Column(
      children: displayDevices.map((d) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: d.connected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForType(d.type),
                  color: d.connected ? AppColors.primary : AppColors.textLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      BleDeviceInfo.labelForType(d.type),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                    Text(
                      'ID: ${d.deviceId}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textLight,
                      ),
                    ),
                    if (d.lastSeen != null)
                      Text(
                        'Last seen ${_formatTime(d.lastSeen!)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: d.connected
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  d.connected ? 'Connected' : 'Scanning',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: d.connected ? AppColors.success : AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForType(BleDeviceType type) {
    switch (type) {
      case BleDeviceType.bloodPressure:
        return Icons.monitor_heart_outlined;
      case BleDeviceType.bloodOxygen:
        return Icons.air;
      case BleDeviceType.temperature:
        return Icons.thermostat_outlined;
      case BleDeviceType.weight:
        return Icons.scale;
      case BleDeviceType.bloodGlucose:
        return Icons.water_drop_outlined;
      case BleDeviceType.unknown:
        return Icons.devices;
    }
  }
}

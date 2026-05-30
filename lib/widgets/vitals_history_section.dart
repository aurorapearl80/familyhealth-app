import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/vitals_history_service.dart';
import '../theme/app_colors.dart';

/// A self-contained widget that shows a range-selector dropdown and a
/// scrollable list of historical readings fetched from the API.
///
/// Drop this into any vitals screen below the existing chart/card.
///
/// ```dart
/// VitalsHistorySection(
///   endpoint: 'temperatures',
///   title: 'Temperature History',
///   rowIcon: Icons.thermostat_outlined,
///   iconBgColor: const Color(0xFFFFE0B2),
///   iconColor: const Color(0xFFFF8A65),
///   formatValue: (item) {
///     final t = item['temperature'];
///     return t != null ? '${(t as num).toStringAsFixed(1)} °C' : '--';
///   },
/// )
/// ```
class VitalsHistorySection extends StatefulWidget {
  /// Endpoint path relative to the API base, e.g. `'temperatures'`, `'glucose'`.
  final String endpoint;

  /// Section header label, e.g. `'Temperature History'`.
  final String title;

  /// Icon shown inside each row's leading circle.
  final IconData rowIcon;

  /// Background fill of the leading icon circle.
  final Color iconBgColor;

  /// Foreground colour of the leading icon and the value text.
  final Color iconColor;

  /// Returns the primary value string for a row, e.g. `'36.8 °C'`.
  final String Function(Map<String, dynamic>) formatValue;

  /// Optional secondary subtitle. Defaults to a time-ago string.
  final String Function(Map<String, dynamic>)? formatSubtitle;

  const VitalsHistorySection({
    super.key,
    required this.endpoint,
    this.title = 'History',
    required this.rowIcon,
    required this.iconBgColor,
    required this.iconColor,
    required this.formatValue,
    this.formatSubtitle,
  });

  @override
  State<VitalsHistorySection> createState() => _VitalsHistorySectionState();
}

class _VitalsHistorySectionState extends State<VitalsHistorySection> {
  VitalsRange _range = VitalsRange.week;
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await VitalsHistoryService.fetch(widget.endpoint, _range);
    if (mounted) {
      setState(() {
        _items = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              _buildRangeDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          // ── Body ─────────────────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.history, size: 36, color: AppColors.textLight),
                  const SizedBox(height: 8),
                  Text(
                    'No data for this period',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildRow(_items[i]),
            ),
        ],
      ),
    );
  }

  // ── Range dropdown ──────────────────────────────────────────────────────────

  Widget _buildRangeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.alertBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VitalsRange>(
          value: _range,
          isDense: true,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.info,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.info,
            size: 18,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: VitalsRange.values.map((r) {
            return DropdownMenuItem(
              value: r,
              child: Text(
                r.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: _range == r
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: _range == r
                      ? AppColors.primary
                      : AppColors.textDark,
                ),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v == null || v == _range) return;
            setState(() => _range = v);
            _fetch();
          },
        ),
      ),
    );
  }

  // ── History row ─────────────────────────────────────────────────────────────

  Widget _buildRow(Map<String, dynamic> item) {
    final rawDate = item['measured_at']?.toString() ??
        item['created_at']?.toString() ??
        item['date']?.toString() ??
        item['datetime']?.toString();

    final dateStr = VitalsHistoryService.formatDate(rawDate);
    final timeAgo = VitalsHistoryService.timeAgo(rawDate);
    final value = widget.formatValue(item);
    final subtitle = widget.formatSubtitle?.call(item) ?? timeAgo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.rowIcon, color: widget.iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          // Date + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          // Value
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: widget.iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

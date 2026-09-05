import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/appointment_time_slot.dart';
import '../../../theme/app_colors.dart';

/// A vertically-scrolling list of time slots with a draggable thumb on the right edge that
/// shows the currently-centered time (mirrors aga-mobile's appointment-booking time picker).
class TimeSlotPicker extends StatefulWidget {
  final List<AppointmentTimeSlot> slots;
  final void Function(AppointmentTimeSlot slot) onSlotTap;
  final String Function(DateTime) formatTime;
  final Color accentColor;

  const TimeSlotPicker({
    super.key,
    required this.slots,
    required this.onSlotTap,
    required this.formatTime,
    this.accentColor = AppColors.primary,
  });

  @override
  State<TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<TimeSlotPicker> {
  static const _itemHeight = 50.0;
  static const _thumbHeight = 58.0;

  final ScrollController _scrollController = ScrollController();
  double _trackHeight = 0;
  double _barOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncThumbToScroll);
  }

  @override
  void didUpdateWidget(covariant TimeSlotPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slots != widget.slots && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
      _barOffset = 0;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncThumbToScroll);
    _scrollController.dispose();
    super.dispose();
  }

  double get _barMaxExtent => (_trackHeight - _thumbHeight).clamp(0.0, double.infinity);

  void _syncThumbToScroll() {
    if (_isDragging || !_scrollController.hasClients || _barMaxExtent <= 0) return;
    final viewMax = _scrollController.position.maxScrollExtent;
    if (viewMax <= 0) return;
    setState(() {
      _barOffset = (_scrollController.position.pixels / viewMax * _barMaxExtent).clamp(0.0, _barMaxExtent);
    });
  }

  void _onThumbDrag(DragUpdateDetails details) {
    final viewMax = _scrollController.position.maxScrollExtent;
    setState(() {
      _barOffset = (_barOffset + details.delta.dy).clamp(0.0, _barMaxExtent);
      if (viewMax > 0 && _barMaxExtent > 0) {
        _scrollController.jumpTo((_barOffset / _barMaxExtent * viewMax).clamp(0.0, viewMax));
      }
    });
  }

  String get _thumbLabel {
    if (widget.slots.isEmpty) return '';
    final pixels = _scrollController.hasClients ? _scrollController.position.pixels : 0.0;
    final index = (pixels / _itemHeight).round().clamp(0, widget.slots.length - 1);
    return widget.formatTime(widget.slots[index].startsAt);
  }

  @override
  Widget build(BuildContext context) {
    final showScrollbar = widget.slots.length > 10;
    final trailingGap = showScrollbar ? 40.0 : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.white, widget.accentColor.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Slide up to see more available times',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(right: trailingGap),
            child: Text(
              widget.formatTime(widget.slots.first.startsAt),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: widget.accentColor),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _trackHeight = constraints.maxHeight;
                return Stack(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 8, bottom: 8, right: trailingGap),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Material(
                        color: Colors.transparent,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: widget.slots.length,
                          itemBuilder: (context, index) => _buildRow(index),
                        ),
                      ),
                    ),
                    if (showScrollbar)
                      Positioned(
                        top: 8 + _barOffset,
                        right: 0,
                        child: GestureDetector(
                          onVerticalDragStart: (_) => setState(() => _isDragging = true),
                          onVerticalDragUpdate: _onThumbDrag,
                          onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                          child: _buildThumb(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: trailingGap),
            child: Text(
              widget.formatTime(widget.slots.last.startsAt),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: widget.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int index) {
    final slot = widget.slots[index];
    final isLast = index == widget.slots.length - 1;
    return InkWell(
      onTap: () => widget.onSlotTap(slot),
      child: Container(
        height: _itemHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Colors.white, width: 1)),
        ),
        child: Text(
          widget.formatTime(slot.startsAt),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
      ),
    );
  }

  Widget _buildThumb() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(Icons.keyboard_arrow_up_rounded, color: widget.accentColor, size: 20),
        Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10),
            ],
          ),
          child: Text(
            _thumbLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: widget.accentColor),
          ),
        ),
        Icon(Icons.keyboard_arrow_down_rounded, color: widget.accentColor, size: 20),
      ],
    );
  }
}

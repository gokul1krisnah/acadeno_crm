import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Shows the exact Figma Calendar UI (`node-id=1713-335`) as a modal dialog
/// and returns the selected [DateTime], or `null` if dismissed.
Future<DateTime?> showFigmaCalendarDialog({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Center(
          child: FigmaCalendarCard(
            initialDate: initialDate,
            firstDate: firstDate ?? DateTime(2020),
            lastDate: lastDate ?? DateTime(2035, 12, 31),
            onDateSelected: (picked) => Navigator.of(ctx).pop(picked),
          ),
        ),
      ),
    ),
  );
}

class FigmaCalendarCard extends StatefulWidget {
  const FigmaCalendarCard({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<FigmaCalendarCard> createState() => _FigmaCalendarCardState();
}

class _FigmaCalendarCardState extends State<FigmaCalendarCard> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  bool _showYearMonthPicker = false;

  static const List<String> _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _displayedMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  List<_CalendarDayItem> _buildMonthDays() {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    // Monday = 1 -> index 0, Sunday = 7 -> index 6
    final leadingDays = firstDayOfMonth.weekday - 1;
    final prevMonthLastDay = DateTime(year, month, 0);
    final daysInPrevMonth = prevMonthLastDay.day;
    final daysInCurrentMonth = DateTime(year, month + 1, 0).day;

    final items = <_CalendarDayItem>[];

    // Previous month overflow days
    for (int i = leadingDays - 1; i >= 0; i--) {
      final day = daysInPrevMonth - i;
      items.add(
        _CalendarDayItem(
          date: DateTime(year, month - 1, day),
          isCurrentMonth: false,
        ),
      );
    }

    // Current month days
    for (int day = 1; day <= daysInCurrentMonth; day++) {
      items.add(
        _CalendarDayItem(
          date: DateTime(year, month, day),
          isCurrentMonth: true,
        ),
      );
    }

    // Next month overflow days to complete 35 (5 rows) or 42 (6 rows)
    final totalCells = items.length <= 35 ? 35 : 42;
    final trailingDays = totalCells - items.length;
    for (int day = 1; day <= trailingDays; day++) {
      items.add(
        _CalendarDayItem(
          date: DateTime(year, month + 1, day),
          isCurrentMonth: false,
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat('MMMM yyyy').format(_displayedMonth);
    final dayItems = _buildMonthDays();
    final rowCount = dayItems.length ~/ 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? math.min(504.0, constraints.maxWidth)
            : 504.0;
        final isCompact = maxW < 440;
        final cardPadding = isCompact ? 24.0 : 48.0;
        final cardRadius = isCompact ? 32.0 : 48.0;
        final rowHeight = isCompact ? 48.0 : 64.0;
        final minDate = DateTime(
          widget.firstDate.year,
          widget.firstDate.month,
          widget.firstDate.day,
        );
        final maxDate = DateTime(
          widget.lastDate.year,
          widget.lastDate.month,
          widget.lastDate.day,
        );

        return Container(
          width: maxW,
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(cardRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000), // rgba(0, 0, 0, 0.06)
                blurRadius: 30,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Heading Container (node 1713:337)
              SizedBox(
                height: 60,
                width: double.infinity,
                child: Align(
                  alignment: const Alignment(-1.0, -0.15),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _showYearMonthPicker = !_showYearMonthPicker;
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            monthTitle,
                            style: GoogleFonts.inter(
                              fontSize: isCompact ? 20 : 24,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                              letterSpacing: 0.0938,
                              height: 36 / 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Transform.rotate(
                            angle: _showYearMonthPicker ? math.pi : 0,
                            child: const CustomPaint(
                              size: Size(14, 8.75),
                              painter: _DownChevronPainter(
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // Prev / Next Month Chevrons (node 1713:341)
              Padding(
                padding: const EdgeInsets.only(top: 2.75, bottom: 11.25),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _previousMonth,
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 3,
                          ),
                          child: CustomPaint(
                            size: Size(8.75, 14),
                            painter: _SideChevronPainter(
                              isLeft: true,
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _nextMonth,
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 3,
                          ),
                          child: CustomPaint(
                            size: Size(8.75, 14),
                            painter: _SideChevronPainter(
                              isLeft: false,
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_showYearMonthPicker)
                _buildMonthYearPickerGrid()
              else ...[
                // Weekday Header Pill Bar (node 1713:354)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: List.generate(_weekdays.length, (index) {
                      final isSunday = index == 6;
                      return Expanded(
                        child: Center(
                          child: Text(
                            _weekdays[index],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: isCompact ? 12 : 14,
                              fontWeight: FontWeight.w500,
                              color: isSunday
                                  ? const Color(0xFF1A1A1A)
                                  : const Color(0xFF666666),
                              letterSpacing: 0.7,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 2),

                // Dates Grid (node 1713:369)
                SizedBox(
                  height: rowCount * rowHeight,
                  width: double.infinity,
                  child: Column(
                    children: List.generate(rowCount, (rowIndex) {
                      return SizedBox(
                        height: rowHeight,
                        child: Row(
                          children: List.generate(7, (colIndex) {
                            final item = dayItems[rowIndex * 7 + colIndex];
                            final normalizedItemDate = DateTime(
                              item.date.year,
                              item.date.month,
                              item.date.day,
                            );
                            final isDisabled =
                                normalizedItemDate.isBefore(minDate) ||
                                normalizedItemDate.isAfter(maxDate);
                            final isSelected =
                                item.date.year == _selectedDate.year &&
                                item.date.month == _selectedDate.month &&
                                item.date.day == _selectedDate.day;

                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: isDisabled
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedDate = item.date;
                                        });
                                        widget.onDateSelected(item.date);
                                      },
                                child: MouseRegion(
                                  cursor: isDisabled
                                      ? SystemMouseCursors.basic
                                      : SystemMouseCursors.click,
                                  child: Center(
                                    child: isSelected
                                        ? Container(
                                            width: isCompact ? 36 : 40,
                                            height: isCompact ? 36 : 40,
                                            alignment: Alignment.center,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF3B82F6),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0x1A000000),
                                                  blurRadius: 6,
                                                  offset: Offset(0, 4),
                                                  spreadRadius: -1,
                                                ),
                                                BoxShadow(
                                                  color: Color(0x1A000000),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                  spreadRadius: -2,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              '${item.date.day}',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                fontSize: isCompact ? 16 : 18,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                                height: 28 / 18,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            '${item.date.day}',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: isCompact ? 16 : 18,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  (item.isCurrentMonth &&
                                                      !isDisabled)
                                                  ? const Color(0xFF1A1A1A)
                                                  : const Color(0xFFD1D5DB),
                                              height: 28 / 18,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthYearPickerGrid() {
    final currentYear = _displayedMonth.year;
    final months = List.generate(
      12,
      (i) => DateFormat('MMM').format(DateTime(currentYear, i + 1, 1)),
    );

    return SizedBox(
      height: 374,
      width: double.infinity,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year - 1,
                        _displayedMonth.month,
                        1,
                      );
                    });
                  },
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: CustomPaint(
                        size: Size(8.75, 14),
                        painter: _SideChevronPainter(
                          isLeft: true,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  '$currentYear',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year + 1,
                        _displayedMonth.month,
                        1,
                      );
                    });
                  },
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: CustomPaint(
                        size: Size(8.75, 14),
                        painter: _SideChevronPainter(
                          isLeft: false,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.1,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final monthNum = index + 1;
                final isSelectedMonth = _displayedMonth.month == monthNum;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _displayedMonth = DateTime(currentYear, monthNum, 1);
                      _showYearMonthPicker = false;
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelectedMonth
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        months[index],
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isSelectedMonth
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDayItem {
  const _CalendarDayItem({
    required this.date,
    required this.isCurrentMonth,
  });

  final DateTime date;
  final bool isCurrentMonth;
}

class _DownChevronPainter extends CustomPainter {
  const _DownChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(1.2, 1.5)
      ..lineTo(size.width / 2, size.height - 1.2)
      ..lineTo(size.width - 1.2, 1.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DownChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SideChevronPainter extends CustomPainter {
  const _SideChevronPainter({
    required this.isLeft,
    required this.color,
  });

  final bool isLeft;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (isLeft) {
      path
        ..moveTo(size.width - 1.2, 1.2)
        ..lineTo(1.2, size.height / 2)
        ..lineTo(size.width - 1.2, size.height - 1.2);
    } else {
      path
        ..moveTo(1.2, 1.2)
        ..lineTo(size.width - 1.2, size.height / 2)
        ..lineTo(1.2, size.height - 1.2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SideChevronPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft || oldDelegate.color != color;
}

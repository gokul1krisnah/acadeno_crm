import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Shows the exact Figma Calendar UI (`node-id=1713-335`) as a responsive modal dialog
/// and returns the selected [DateTime], or `null` if dismissed.
/// Adapts dynamically to smaller mobile screens with compact padding, proportional
/// row heights, and clean responsive layout.
Future<DateTime?> showFigmaCalendarDialog({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final mediaQuery = MediaQuery.of(context);
  final screenWidth = mediaQuery.size.width;
  final isSmallMobile = screenWidth < 360;
  final isMobile = screenWidth < 500;
  final hPad = isSmallMobile ? 8.0 : (isMobile ? 12.0 : 20.0);
  final vPad = isMobile ? 14.0 : 24.0;

  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
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
        final screenWidth = MediaQuery.sizeOf(context).width;
        final maxW = constraints.maxWidth.isFinite
            ? math.min(
                screenWidth < 400
                    ? 336.0
                    : (screenWidth < 520 ? 370.0 : 480.0),
                constraints.maxWidth,
              )
            : 350.0;

        final isSmallMobile = maxW < 350;
        final isMobile = maxW < 440;

        final cardPadding = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 28.0);
        final cardRadius = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 36.0);
        final titleFontSize = isSmallMobile ? 17.0 : (isMobile ? 19.0 : 22.0);
        final headerGap = isSmallMobile ? 6.0 : (isMobile ? 8.0 : 12.0);
        final weekdayBarVPad = isSmallMobile ? 6.0 : (isMobile ? 8.0 : 12.0);
        final weekdayFontSize = isSmallMobile ? 10.5 : (isMobile ? 11.5 : 13.0);
        final rowHeight = isSmallMobile ? 32.0 : (isMobile ? 36.0 : 46.0);
        final dayCircleSize = isSmallMobile ? 26.0 : (isMobile ? 30.0 : 38.0);
        final dayFontSize = isSmallMobile ? 12.5 : (isMobile ? 14.0 : 16.0);

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
              // Top Heading Container & Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
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
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                              letterSpacing: 0.0938,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Transform.rotate(
                            angle: _showYearMonthPicker ? math.pi : 0,
                            child: const CustomPaint(
                              size: Size(12, 7.5),
                              painter: _DownChevronPainter(
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Month Navigation & Close
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _previousMonth,
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: CustomPaint(
                              size: Size(8, 13),
                              painter: _SideChevronPainter(
                                isLeft: true,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _nextMonth,
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: CustomPaint(
                              size: Size(8, 13),
                              painter: _SideChevronPainter(
                                isLeft: false,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: headerGap),

              if (_showYearMonthPicker)
                _buildMonthYearPickerGrid(isSmallMobile: isSmallMobile, isMobile: isMobile)
              else ...[
                // Weekday Header Pill Bar (node 1713:354)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: weekdayBarVPad,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
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
                              fontSize: weekdayFontSize,
                              fontWeight: FontWeight.w500,
                              color: isSunday
                                  ? const Color(0xFF1A1A1A)
                                  : const Color(0xFF666666),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 4),

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
                                            width: dayCircleSize,
                                            height: dayCircleSize,
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
                                                fontSize: dayFontSize,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            '${item.date.day}',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: dayFontSize,
                                              fontWeight: FontWeight.w500,
                                              color: (item.isCurrentMonth &&
                                                      !isDisabled)
                                                  ? const Color(0xFF1A1A1A)
                                                  : const Color(0xFFD1D5DB),
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

  Widget _buildMonthYearPickerGrid({
    required bool isSmallMobile,
    required bool isMobile,
  }) {
    final currentYear = _displayedMonth.year;
    final months = List.generate(
      12,
      (i) => DateFormat('MMM').format(DateTime(currentYear, i + 1, 1)),
    );
    final pickerHeight = isSmallMobile ? 220.0 : (isMobile ? 250.0 : 310.0);
    final monthFontSize = isSmallMobile ? 12.5 : (isMobile ? 13.5 : 15.0);
    final yearFontSize = isSmallMobile ? 15.0 : (isMobile ? 16.0 : 18.0);

    return SizedBox(
      height: pickerHeight,
      width: double.infinity,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
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
                      padding: EdgeInsets.all(4),
                      child: CustomPaint(
                        size: Size(8, 13),
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
                    fontSize: yearFontSize,
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
                      padding: EdgeInsets.all(4),
                      child: CustomPaint(
                        size: Size(8, 13),
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
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: isSmallMobile ? 6 : 8,
                crossAxisSpacing: isSmallMobile ? 6 : 8,
                childAspectRatio: isSmallMobile ? 2.4 : 2.2,
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
                          fontSize: monthFontSize,
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

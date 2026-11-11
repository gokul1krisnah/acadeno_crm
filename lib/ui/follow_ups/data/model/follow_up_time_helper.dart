import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'follow_up_models.dart';

/// Helper to parse and evaluate follow-up schedules against current time.
/// Dynamically calculates whether a follow-up is Overdue, Today, or Upcoming,
/// and returns human-readable status labels.
class FollowUpTimeHelper {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Evaluates the follow-up record and returns:
  /// - [bucket]: Overdue, Today, or Upcoming
  /// - [displayLabel]: Formatted, contextual label (e.g. 'Overdue · Was due yesterday')
  /// - [scheduledTime]: Exact parsed or inferred DateTime
  /// - [isOverdue]: Boolean flag
  static ({
    FollowUpBucket bucket,
    String displayLabel,
    DateTime scheduledTime,
    bool isOverdue,
  })
  evaluate({
    required dynamic rawFollowUpTime,
    dynamic assignedDateKey,
    dynamic assignedDateLabel,
    dynamic assignedAt,
    dynamic updatedAt,
    dynamic createdAt,
    String status = '',
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final statusLower = status.trim().toLowerCase();

    // 1. Resolve base date from assignedDateKey or timestamp if present
    DateTime? baseDate;
    if (assignedDateKey != null &&
        assignedDateKey.toString().trim().isNotEmpty) {
      try {
        final parts = assignedDateKey.toString().trim().split('-');
        if (parts.length == 3) {
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          baseDate = DateTime(y, m, d);
        }
      } catch (_) {}
    }

    if (baseDate == null) {
      final ts = assignedAt ?? createdAt ?? updatedAt;
      if (ts is Timestamp) {
        final dt = ts.toDate();
        baseDate = DateTime(dt.year, dt.month, dt.day);
      } else if (ts is DateTime) {
        baseDate = DateTime(ts.year, ts.month, ts.day);
      }
    }

    // 2. Parse time string
    final rawStr = (rawFollowUpTime ?? '').toString().trim();
    final rawLower = rawStr.toLowerCase();

    DateTime? resolvedDateTime;

    // Check if rawFollowUpTime is a Timestamp or DateTime directly
    if (rawFollowUpTime is Timestamp) {
      resolvedDateTime = rawFollowUpTime.toDate();
    } else if (rawFollowUpTime is DateTime) {
      resolvedDateTime = rawFollowUpTime;
    } else if (rawStr.isNotEmpty) {
      // Extract time part like '10:30 AM' or '4:30 PM' or '16:00'
      final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?');
      final timeMatch = timeRegex.firstMatch(rawStr);
      int hour = 18; // default to end of work day if no time specified
      int minute = 0;

      if (timeMatch != null) {
        int parsedHour = int.parse(timeMatch.group(1)!);
        minute = int.parse(timeMatch.group(2)!);
        final meridiem = timeMatch.group(3)?.toUpperCase();

        if (meridiem == 'PM' && parsedHour < 12) {
          parsedHour += 12;
        } else if (meridiem == 'AM' && parsedHour == 12) {
          parsedHour = 0;
        }
        hour = parsedHour;
      }

      if (rawLower.contains('yesterday')) {
        final yesterday = todayMidnight.subtract(const Duration(days: 1));
        resolvedDateTime = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          hour,
          minute,
        );
      } else if (rawLower.contains('tomorrow')) {
        // Caution: If 'Tomorrow' was stored yesterday (baseDate is yesterday),
        // then yesterday's 'Tomorrow' is actually TODAY!
        DateTime targetDay = todayMidnight.add(const Duration(days: 1));
        if (baseDate != null && baseDate.isBefore(todayMidnight)) {
          // If stored on yesterday or earlier, advance from baseDate
          final diff = todayMidnight.difference(baseDate).inDays;
          if (diff == 1) {
            targetDay = todayMidnight; // yesterday's tomorrow is today
          } else {
            targetDay = baseDate.add(
              const Duration(days: 1),
            ); // earlier past day
          }
        }
        resolvedDateTime = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day,
          hour,
          minute,
        );
      } else if (rawLower.contains('today')) {
        // If 'Today' was stored yesterday, it is now YESTERDAY!
        DateTime targetDay = todayMidnight;
        if (baseDate != null && baseDate.isBefore(todayMidnight)) {
          targetDay = baseDate;
        }
        resolvedDateTime = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day,
          hour,
          minute,
        );
      } else {
        // Attempt to parse date from string (e.g. 'Mon, 2 Nov · 10:30 AM' or '2026-11-02')
        DateTime? parsedDay;

        // Try standard ISO formats
        try {
          final dt = DateTime.parse(rawStr);
          resolvedDateTime = dt;
        } catch (_) {}

        if (resolvedDateTime == null) {
          // Check for day and month name (e.g. '2 Nov', '02 Nov')
          for (int m = 0; m < _months.length; m++) {
            final monthName = _months[m].toLowerCase();
            if (rawLower.contains(monthName)) {
              final dayRegex = RegExp(
                r'\b(\d{1,2})\s+' + monthName,
                caseSensitive: false,
              );
              final match = dayRegex.firstMatch(rawStr);
              if (match != null) {
                final d = int.parse(match.group(1)!);
                int y = now.year;
                // Year regex if present (e.g. 2026)
                final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(rawStr);
                if (yearMatch != null) {
                  y = int.parse(yearMatch.group(1)!);
                }
                parsedDay = DateTime(y, m + 1, d);
                break;
              }
            }
          }

          if (parsedDay != null) {
            resolvedDateTime = DateTime(
              parsedDay.year,
              parsedDay.month,
              parsedDay.day,
              hour,
              minute,
            );
          }
        }
      }
    }

    // Fallback to baseDate or today
    if (resolvedDateTime == null) {
      if (baseDate != null) {
        resolvedDateTime = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          10,
          0,
        );
      } else {
        resolvedDateTime = DateTime(
          todayMidnight.year,
          todayMidnight.month,
          todayMidnight.day,
          18,
          0,
        );
      }
    } else if (baseDate != null && !baseDate.isBefore(todayMidnight)) {
      // If the lead was assigned to today or a future date via assignedDateKey,
      // but resolvedDateTime ended up in the past (e.g. from an old stale follow-up text),
      // the explicit current/future assignment date takes precedence!
      if (resolvedDateTime.isBefore(todayMidnight)) {
        resolvedDateTime = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          resolvedDateTime.hour == 18 ? 10 : resolvedDateTime.hour,
          resolvedDateTime.minute,
        );
      }
    }

    final itemDay = DateTime(
      resolvedDateTime.year,
      resolvedDateTime.month,
      resolvedDateTime.day,
    );

    // CRITICAL: A follow-up scheduled for tomorrow or a future date can NEVER be overdue!
    final isFuture = itemDay.isAfter(todayMidnight);

    // Determine overdue status
    final isPast = resolvedDateTime.isBefore(now);
    final isOverdue = !isFuture && (statusLower == 'overdue' || isPast);

    FollowUpBucket bucket;
    String displayLabel;

    if (isOverdue) {
      bucket = FollowUpBucket.overdue;
      if (itemDay.isBefore(todayMidnight)) {
        final daysAgo = todayMidnight.difference(itemDay).inDays;
        if (daysAgo == 1) {
          displayLabel = 'Overdue · Was due yesterday';
        } else {
          final fmt = DateFormat('d MMM').format(itemDay);
          displayLabel = 'Overdue · Was due on $fmt';
        }
      } else {
        // Was due earlier today
        final timeFmt = DateFormat('h:mm a').format(resolvedDateTime);
        displayLabel = 'Overdue · Missed ($timeFmt)';
      }
    } else if (itemDay.isAtSameMomentAs(todayMidnight)) {
      bucket = FollowUpBucket.today;
      final timeFmt = DateFormat('h:mm a').format(resolvedDateTime);
      displayLabel = 'Today · $timeFmt';
    } else {
      bucket = FollowUpBucket.upcoming;
      final daysAhead = itemDay.difference(todayMidnight).inDays;
      final timeFmt = DateFormat('h:mm a').format(resolvedDateTime);
      if (daysAhead == 1) {
        displayLabel = 'Tomorrow · $timeFmt';
      } else {
        final dayFmt = DateFormat('EEE, d MMM').format(itemDay);
        displayLabel = '$dayFmt · $timeFmt';
      }
    }

    return (
      bucket: bucket,
      displayLabel: displayLabel,
      scheduledTime: resolvedDateTime,
      isOverdue: isOverdue,
    );
  }
}

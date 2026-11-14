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

    DateTime? updatedDate;
    if (updatedAt is Timestamp) {
      final dt = updatedAt.toDate();
      updatedDate = DateTime(dt.year, dt.month, dt.day);
    } else if (updatedAt is DateTime) {
      updatedDate = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
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

    // For relative words ("Today", "Tomorrow"), prefer the most recent update date
    // over an older original assignment date so rescheduling/snoozing today works.
    DateTime? relativeRefDate = baseDate;
    if (updatedDate != null &&
        (relativeRefDate == null || updatedDate.isAfter(relativeRefDate))) {
      relativeRefDate = updatedDate;
    }

    // 2. Parse time string
    final rawStr = (rawFollowUpTime ?? '').toString().trim();
    final rawLower = rawStr.toLowerCase();

    DateTime? resolvedDateTime;
    bool hasExplicitConcreteDate = false;

    // Check if rawFollowUpTime is a Timestamp or DateTime directly
    if (rawFollowUpTime is Timestamp) {
      resolvedDateTime = rawFollowUpTime.toDate();
      hasExplicitConcreteDate = true;
    } else if (rawFollowUpTime is DateTime) {
      resolvedDateTime = rawFollowUpTime;
      hasExplicitConcreteDate = true;
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

      // 2a. First check for an explicit concrete date (e.g. 'Sun, 15 Nov · 10:30 AM',
      // 'Today, 14 Nov · 10:00 AM', '2026-11-15') before relative words.
      DateTime? parsedDay;
      try {
        final dt = DateTime.parse(rawStr);
        resolvedDateTime = dt;
        hasExplicitConcreteDate = true;
      } catch (_) {}

      if (resolvedDateTime == null) {
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
          hasExplicitConcreteDate = true;
        }
      }

      // 2b. If no concrete day/month was present, evaluate relative words
      if (resolvedDateTime == null) {
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
          DateTime targetDay = todayMidnight.add(const Duration(days: 1));
          if (relativeRefDate != null &&
              relativeRefDate.isBefore(todayMidnight)) {
            final diff = todayMidnight.difference(relativeRefDate).inDays;
            if (diff == 1) {
              targetDay = todayMidnight;
            } else {
              targetDay = relativeRefDate.add(const Duration(days: 1));
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
          DateTime targetDay = todayMidnight;
          if (relativeRefDate != null &&
              relativeRefDate.isBefore(todayMidnight)) {
            targetDay = relativeRefDate;
          }
          resolvedDateTime = DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            hour,
            minute,
          );
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
    } else if (baseDate != null &&
        !baseDate.isBefore(todayMidnight) &&
        !hasExplicitConcreteDate) {
      // If the lead was assigned to today or a future date via assignedDateKey,
      // but resolvedDateTime ended up in the past from an old relative follow-up text,
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
    final isPastDay = itemDay.isBefore(todayMidnight);
    final isAssignedOnlyStatus =
        statusLower == 'assigned' ||
        statusLower == 'reassigned' ||
        statusLower == 'new';

    // Determine overdue status:
    // - Future days (Tomorrow+) are NEVER overdue.
    // - Past days (Yesterday or earlier) are ALWAYS overdue.
    // - Today:
    //   * If the lead is merely 'assigned'/'new' for today and not yet called, keep it in Today for the day.
    //   * If it has an explicit follow-up time today, it is overdue only if that time has already passed (isPast).
    //   * If it has no explicit follow-up time today, it is overdue if statusLower == 'overdue' or isPast.
    final isPast = resolvedDateTime.isBefore(now);
    final bool isOverdue;
    if (isFuture) {
      isOverdue = false;
    } else if (isPastDay) {
      isOverdue = true;
    } else if (isAssignedOnlyStatus) {
      isOverdue = false;
    } else if (rawStr.isNotEmpty) {
      isOverdue = isPast;
    } else {
      isOverdue = statusLower == 'overdue' || isPast;
    }

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

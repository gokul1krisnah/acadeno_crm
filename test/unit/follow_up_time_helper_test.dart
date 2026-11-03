import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_time_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QA Test Suite: FollowUpTimeHelper & Overdue Evaluation', () {
    final fixedNow = DateTime(2026, 11, 3, 10, 0); // 3 Nov 2026, 10:00 AM

    test('TC-FU-001: Assigned yesterday with no explicit time is automatically Overdue', () {
      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: null,
        assignedDateKey: '2026-11-02',
        status: 'assigned',
        currentTime: fixedNow,
      );

      expect(eval.bucket, equals(FollowUpBucket.overdue));
      expect(eval.isOverdue, isTrue);
      expect(eval.displayLabel, contains('Was due yesterday'));
    });

    test('TC-FU-002: Scheduled earlier today (e.g. 9:00 AM vs 10:00 AM current) is Overdue/Missed', () {
      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: 'Today · 9:00 AM',
        assignedDateKey: '2026-11-03',
        status: 'follow-up',
        currentTime: fixedNow,
      );

      expect(eval.bucket, equals(FollowUpBucket.overdue));
      expect(eval.isOverdue, isTrue);
      expect(eval.displayLabel, contains('Missed'));
    });

    test('TC-FU-003: Scheduled later today (e.g. 4:30 PM vs 10:00 AM current) is in Today bucket', () {
      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: 'Today · 4:30 PM',
        assignedDateKey: '2026-11-03',
        status: 'follow-up',
        currentTime: fixedNow,
      );

      expect(eval.bucket, equals(FollowUpBucket.today));
      expect(eval.isOverdue, isFalse);
      expect(eval.displayLabel, contains('Today · 4:30 PM'));
    });

    test('TC-FU-004: Scheduled tomorrow is in Upcoming bucket', () {
      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: 'Tomorrow · 10:30 AM',
        assignedDateKey: '2026-11-03',
        status: 'follow-up',
        currentTime: fixedNow,
      );

      expect(eval.bucket, equals(FollowUpBucket.upcoming));
      expect(eval.isOverdue, isFalse);
      expect(eval.displayLabel, contains('Tomorrow · 10:30 AM'));
    });
  });
}

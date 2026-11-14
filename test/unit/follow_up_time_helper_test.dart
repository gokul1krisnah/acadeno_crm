import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_time_helper.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QA Test Suite: FollowUpTimeHelper & Overdue Evaluation', () {
    final fixedNow = DateTime(2026, 11, 3, 10, 0); // 3 Nov 2026, 10:00 AM

    test(
      'TC-FU-001: Assigned yesterday with no explicit time is automatically Overdue',
      () {
        final eval = FollowUpTimeHelper.evaluate(
          rawFollowUpTime: null,
          assignedDateKey: '2026-11-02',
          status: 'assigned',
          currentTime: fixedNow,
        );

        expect(eval.bucket, equals(FollowUpBucket.overdue));
        expect(eval.isOverdue, isTrue);
        expect(eval.displayLabel, contains('Was due yesterday'));
      },
    );

    test(
      'TC-FU-002: Scheduled earlier today (e.g. 9:00 AM vs 10:00 AM current) is Overdue/Missed',
      () {
        final eval = FollowUpTimeHelper.evaluate(
          rawFollowUpTime: 'Today · 9:00 AM',
          assignedDateKey: '2026-11-03',
          status: 'follow-up',
          currentTime: fixedNow,
        );

        expect(eval.bucket, equals(FollowUpBucket.overdue));
        expect(eval.isOverdue, isTrue);
        expect(eval.displayLabel, contains('Missed'));
      },
    );

    test(
      'TC-FU-003: Scheduled later today (e.g. 4:30 PM vs 10:00 AM current) is in Today bucket',
      () {
        final eval = FollowUpTimeHelper.evaluate(
          rawFollowUpTime: 'Today · 4:30 PM',
          assignedDateKey: '2026-11-03',
          status: 'follow-up',
          currentTime: fixedNow,
        );

        expect(eval.bucket, equals(FollowUpBucket.today));
        expect(eval.isOverdue, isFalse);
        expect(eval.displayLabel, contains('Today · 4:30 PM'));
      },
    );

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

    test(
      'TC-FU-005: Lead assigned to next day or future date appears in Upcoming even if previous status was overdue',
      () {
        final eval = FollowUpTimeHelper.evaluate(
          rawFollowUpTime: null,
          assignedDateKey: '2026-11-04',
          status: 'overdue',
          currentTime: fixedNow,
        );

        expect(eval.bucket, equals(FollowUpBucket.upcoming));
        expect(eval.isOverdue, isFalse);
        expect(eval.displayLabel, contains('Tomorrow'));
      },
    );

    test(
      'TC-FU-006: Lead assigned to future date overrides stale past follow-up text and lands in Upcoming',
      () {
        final eval = FollowUpTimeHelper.evaluate(
          rawFollowUpTime: 'Yesterday 5 PM',
          assignedDateKey: '2026-11-05',
          status: 'assigned',
          currentTime: fixedNow,
        );

        expect(eval.bucket, equals(FollowUpBucket.upcoming));
        expect(eval.isOverdue, isFalse);
      },
    );

    test(
      'TC-FU-007: Concrete tomorrow date (e.g. Wed, 4 Nov · 10:30 AM) lands in Upcoming even with stale assignedDateKey and overdue status',
      () {
        final eval = FollowUpTimeHelper.evaluate(
          rawFollowUpTime: 'Wed, 4 Nov · 10:30 AM',
          assignedDateKey: '2026-11-01',
          updatedAt: fixedNow,
          status: 'overdue',
          currentTime: fixedNow,
        );

        expect(eval.bucket, equals(FollowUpBucket.upcoming));
        expect(eval.isOverdue, isFalse);
      },
    );

    test(
      'TC-FU-008: Concrete today later time (e.g. Tue, 3 Nov · 4:00 PM) lands in Today even with stale assignedDateKey',
      () {
        final eval = FollowUpTimeHelper.evaluate(
          rawFollowUpTime: 'Tue, 3 Nov · 4:00 PM',
          assignedDateKey: '2026-11-01',
          updatedAt: fixedNow,
          status: 'follow-up',
          currentTime: fixedNow,
        );

        expect(eval.bucket, equals(FollowUpBucket.today));
        expect(eval.isOverdue, isFalse);
      },
    );
  });

  group(
    'QA Test Suite: LeadDateHelper.formatLastContact Actual Data Verification',
    () {
      test(
        'TC-LC-001: New uncalled lead returns Never instead of fake Today/Just now',
        () {
          final result = LeadDateHelper.formatLastContact(
            status: 'New',
            rawLastContact: 'Just now', // previously stored fake default
          );
          expect(result, equals('Never'));
        },
      );

      test('TC-LC-002: Unassigned lead with no call record returns Never', () {
        final result = LeadDateHelper.formatLastContact(
          status: 'Unassigned',
          rawLastContact: null,
        );
        expect(result, equals('Never'));
      });

      test('TC-LC-003: Lead called today returns Today', () {
        final result = LeadDateHelper.formatLastContact(
          status: 'Interested',
          lastContactAt: DateTime.now(),
        );
        expect(result, equals('Today'));
      });

      test('TC-LC-004: Lead called yesterday returns Yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final result = LeadDateHelper.formatLastContact(
          status: 'Follow-up',
          lastContactAt: yesterday,
        );
        expect(result, equals('Yesterday'));
      });

      test(
        'TC-LC-005: Lead called 10 days ago returns formatted day and month',
        () {
          final pastDate = DateTime.now().subtract(const Duration(days: 10));
          final result = LeadDateHelper.formatLastContact(
            status: 'Contacted',
            lastContactAt: pastDate,
          );
          expect(result, contains('${pastDate.day}'));
        },
      );
    },
  );
}

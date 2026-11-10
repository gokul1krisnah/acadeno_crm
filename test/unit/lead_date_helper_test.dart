import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // "Now" for all tests: Tue, 10 Nov 2026, 3:15 PM
  final now = DateTime(2026, 11, 10, 15, 15);

  group('LeadDateHelper real-date handling', () {
    test('timelineStamp is absolute and never uses relative words', () {
      expect(LeadDateHelper.timelineStamp(now), '10 Nov 2026, 3:15 PM');
      expect(
        LeadDateHelper.timelineStamp(DateTime(2026, 11, 5, 9, 5)),
        '5 Nov 2026, 9:05 AM',
      );
      expect(
        LeadDateHelper.timelineStamp(DateTime(2026, 1, 1, 0, 0)),
        '1 Jan 2026, 12:00 AM',
      );
    });

    test('stamp stored on 5 Nov shows 5 Nov (not Today) on 10 Nov', () {
      final parsed = LeadDateHelper.parseStamp('5 Nov 2026, 9:15 AM', now: now)!;
      expect(parsed.hasTime, isTrue);
      expect(
        LeadDateHelper.relativeStamp(parsed.dt, now: now),
        '5 Nov, 9:15 AM',
      );
    });

    test('same-day stamp shows Today, yesterday shows Yesterday', () {
      expect(
        LeadDateHelper.relativeStamp(DateTime(2026, 11, 10, 8, 0), now: now),
        'Today, 8:00 AM',
      );
      expect(
        LeadDateHelper.relativeStamp(DateTime(2026, 11, 9, 20, 30), now: now),
        'Yesterday, 8:30 PM',
      );
    });

    test('legacy "Today, 5 Nov" label resolves to its real date', () {
      final parsed = LeadDateHelper.parseStamp('Today, 5 Nov', now: now)!;
      expect(parsed.hasTime, isFalse);
      expect(
        LeadDateHelper.relativeStamp(parsed.dt, withTime: false, now: now),
        '5 Nov',
      );
    });

    test('plain "Today" has no real date', () {
      expect(LeadDateHelper.parseStamp('Today', now: now), isNull);
    });

    test('other-year dates include the year', () {
      expect(
        LeadDateHelper.relativeStamp(
          DateTime(2025, 12, 30, 10, 0),
          withTime: false,
          now: now,
        ),
        '30 Dec 2025',
      );
    });

    test('follow-up relative text is converted to concrete dates', () {
      expect(
        LeadDateHelper.resolveFollowUpLabel('Tomorrow 10:30', now: now),
        'Wed, 11 Nov · 10:30 AM',
      );
      expect(
        LeadDateHelper.resolveFollowUpLabel('Today 5 PM', now: now),
        'Tue, 10 Nov · 5:00 PM',
      );
      expect(
        LeadDateHelper.resolveFollowUpLabel('In 3 days', now: now),
        'Fri, 13 Nov · 10:30 AM',
      );
      expect(
        LeadDateHelper.resolveFollowUpLabel('Today · 4:00 PM', now: now),
        'Tue, 10 Nov · 4:00 PM',
      );
    });

    test('already concrete follow-up text is untouched', () {
      expect(
        LeadDateHelper.resolveFollowUpLabel('Mon, 2 Nov · 10:30 AM', now: now),
        'Mon, 2 Nov · 10:30 AM',
      );
    });

    test('default follow-up slot never lands in the past', () {
      // 3:15 PM → "No answer" retry slot (4 PM) is still ahead today.
      expect(
        LeadDateHelper.resolveFollowUpLabel(
          null,
          outcome: 'No answer',
          now: now,
        ),
        'Tue, 10 Nov · 4:00 PM',
      );
      // 6 PM → 4 PM / 5:30 PM already passed, roll to tomorrow 10:30.
      final evening = DateTime(2026, 11, 10, 18, 0);
      expect(
        LeadDateHelper.resolveFollowUpLabel(
          null,
          outcome: 'Interested',
          now: evening,
        ),
        'Wed, 11 Nov · 10:30 AM',
      );
      expect(
        LeadDateHelper.resolveFollowUpLabel(null, outcome: 'Converted'),
        isNull,
      );
    });

    test('year rollover follow-up keeps the correct year', () {
      final dec = DateTime(2026, 12, 31, 12, 0);
      expect(
        LeadDateHelper.resolveFollowUpLabel('Tomorrow 10:30', now: dec),
        'Fri, 1 Jan 2027 · 10:30 AM',
      );
    });
  });
}

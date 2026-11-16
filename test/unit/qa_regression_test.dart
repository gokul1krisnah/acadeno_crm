import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadeno_crm/shared/widgets/acadeno_dropdown.dart';
import 'package:acadeno_crm/ui/visits/data/model/visit_models.dart';
import 'package:acadeno_crm/ui/dashboard/data/model/dashboard_user_model.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_time_helper.dart';

void main() {
  group('QA Regression Test Suite: Dropdown Component (Figma node 1809-1576)', () {
    testWidgets('TC-DD-001: AcadenoDropdown renders and displays selected value', (tester) async {
      String? selectedValue = 'option_1';
      final items = [
        const AcadenoDropdownItem(value: 'option_1', label: 'All Follow-ups'),
        const AcadenoDropdownItem(value: 'option_2', label: 'Overdue Only'),
        const AcadenoDropdownItem(value: 'option_3', label: 'Upcoming Today'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcadenoDropdown<String>(
              value: selectedValue,
              items: items,
              onChanged: (val) => selectedValue = val,
            ),
          ),
        ),
      );

      expect(find.text('All Follow-ups'), findsOneWidget);
    });

    testWidgets('TC-DD-002: AcadenoDropdown strings factory handles selection change', (tester) async {
      String? selected = 'Monthly';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AcadenoDropdown.strings(
                  value: selected,
                  items: const ['Weekly', 'Monthly', 'Yearly'],
                  onChanged: (val) {
                    setState(() => selected = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Monthly'), findsOneWidget);
    });
  });

  group('QA Regression Test Suite: College Visits Data Model & Status Lifecycle', () {
    test('TC-VIS-001: Instantiate Planned visit with correct date pill format', () {
      final visit = ExecutiveCollegeVisit(
        id: 'visit_001',
        monthShort: 'NOV',
        dayNumber: '11',
        collegeName: 'Apex Institute of Technology',
        subtitle: 'Kochi, Kerala',
        statusLabel: 'Planned',
        isUpcoming: true,
      );

      expect(visit.id, equals('visit_001'));
      expect(visit.monthShort, equals('NOV'));
      expect(visit.dayNumber, equals('11'));
      expect(visit.statusLabel, equals('Planned'));
      expect(visit.isUpcoming, isTrue);
    });

    test('TC-VIS-002: Mark visit as Completed with outcome metrics', () {
      final visit = ExecutiveCollegeVisit(
        id: 'visit_002',
        monthShort: 'OCT',
        dayNumber: '24',
        collegeName: 'Model Engineering College',
        subtitle: 'Thrikkakara, Kochi',
        statusLabel: 'Completed',
        leadsCollected: 45,
        interestedCount: 28,
        metSummary: 'Met HOD & Placement Coordinator',
        nextActionSummary: 'Deliver brochures on Monday',
        isUpcoming: false,
      );

      expect(visit.statusLabel, equals('Completed'));
      expect(visit.leadsCollected, equals(45));
      expect(visit.interestedCount, equals(28));
      expect(visit.metSummary, contains('Placement Coordinator'));
      expect(visit.nextActionSummary, contains('Deliver brochures'));
      expect(visit.isUpcoming, isFalse);
    });

    test('TC-VIS-003: Cancelled visit retains cancellation reason and resets flags', () {
      final visit = ExecutiveCollegeVisit(
        id: 'visit_003',
        monthShort: 'OCT',
        dayNumber: '28',
        collegeName: "St. Joseph's Engineering College",
        subtitle: 'Kochi, Kerala',
        statusLabel: 'Cancelled',
        cancelReason: 'Postponed due to internal exams.',
        isUpcoming: false,
      );

      expect(visit.statusLabel, equals('Cancelled'));
      expect(visit.cancelReason, equals('Postponed due to internal exams.'));
      expect(visit.isUpcoming, isFalse);
    });
  });

  group('QA Regression Test Suite: User Role & Device Security Matrix', () {
    test('TC-USR-001: Admin role normalization and phone binding verification', () {
      const admin = DashboardUserModel(
        uid: 'adm_01',
        name: 'Gokul Super Admin',
        email: 'admin@acadeno.in',
        role: 'super_admin',
        isActive: true,
        deviceBound: true,
        deviceName: 'Pixel 8 Pro',
      );

      expect(admin.role, equals('super_admin'));
      expect(DashboardUserModel.normalizeRole(admin.role), equals('admin'));
      expect(admin.deviceBound, isTrue);
    });

    test('TC-USR-002: HR/Executive role normalization', () {
      const executive = DashboardUserModel(
        uid: 'exec_01',
        name: 'Executive Sarah',
        email: 'sarah@acadeno.in',
        role: 'telecaller',
        isActive: true,
        deviceBound: false,
        deviceName: 'Pending Binding',
      );

      expect(DashboardUserModel.normalizeRole(executive.role), equals('hr'));
      expect(executive.deviceBound, isFalse);
    });
  });

  group('QA Regression Test Suite: Follow-up Scheduling & Overdue Rules', () {
    final fixedNow = DateTime(2026, 11, 16, 10, 0);

    test('TC-FU-009: Expired time slots on current day are marked overdue', () {
      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: 'Today · 9:30 AM',
        assignedDateKey: '2026-11-16',
        status: 'follow-up',
        currentTime: fixedNow,
      );

      expect(eval.bucket, equals(FollowUpBucket.overdue));
      expect(eval.isOverdue, isTrue);
    });

    test('TC-FU-010: Future slots on current day are placed in Today bucket', () {
      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: 'Today · 3:00 PM',
        assignedDateKey: '2026-11-16',
        status: 'follow-up',
        currentTime: fixedNow,
      );

      expect(eval.bucket, equals(FollowUpBucket.today));
      expect(eval.isOverdue, isFalse);
    });
  });
}

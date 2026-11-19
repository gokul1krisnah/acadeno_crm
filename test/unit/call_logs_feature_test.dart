import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadeno_crm/ui/call_logs/data/model/call_log_model.dart';
import 'package:acadeno_crm/ui/leads/application/leads_state.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';

void main() {
  group('QA Test Suite: Call Logs Native Feature & Models', () {
    test('TC-CL-001: DeviceCallLogItem parses raw call data and formats duration', () {
      final now = DateTime(2026, 7, 8, 9, 49);
      final item = DeviceCallLogItem(
        id: '101',
        number: '+91 7558804685',
        formattedNumber: '+91 7558804685',
        timestamp: now,
        durationSeconds: 710, // 11m 50s
        callType: CallType.outgoing,
        simName: 'BSNL Mobile',
      );

      expect(item.formattedDuration, equals('11m 50s'));
      expect(item.normalizedPhone, equals('7558804685'));
      expect(item.formattedDateTime, contains('9:49 AM'));
      expect(item.simName, equals('BSNL Mobile'));
      expect(item.callType, equals(CallType.outgoing));
    });

    test('TC-CL-002: Formats zero duration and hours correctly', () {
      final zeroCall = DeviceCallLogItem(
        id: '102',
        number: '+91 7558804685',
        formattedNumber: '+91 7558804685',
        timestamp: DateTime.now(),
        durationSeconds: 0,
        callType: CallType.missed,
      );
      expect(zeroCall.formattedDuration, equals('0m 0s'));

      final hourCall = DeviceCallLogItem(
        id: '103',
        number: '+91 9037424448',
        formattedNumber: '+91 9037424448',
        timestamp: DateTime.now(),
        durationSeconds: 3665, // 1h 1m 5s
        callType: CallType.incoming,
      );
      expect(hourCall.formattedDuration, equals('1h 1m 5s'));
    });

    test('TC-CL-003: CallCategory database mapping supports all required categories', () {
      expect(CallCategory.hotLead.dbValue, equals('hot_lead'));
      expect(CallCategory.followUp.dbValue, equals('follow_up'));
      expect(CallCategory.reminder.dbValue, equals('reminder'));
      expect(CallCategory.other.dbValue, equals('other'));

      expect(CallCategoryExtension.fromDbValue('hot_lead'), equals(CallCategory.hotLead));
      expect(CallCategoryExtension.fromDbValue('follow_up'), equals(CallCategory.followUp));
      expect(CallCategoryExtension.fromDbValue('reminder'), equals(CallCategory.reminder));
      expect(CallCategoryExtension.fromDbValue('other'), equals(CallCategory.other));
    });
  });

  group('QA Test Suite: Home Screen Category Filtering', () {
    test('TC-CL-004: LeadsState correctly filters real records by category', () {
      final lead1 = ExecutiveLeadItem(
        id: 'lead_1',
        name: 'Prospective Student 1',
        initials: 'PS',
        maskedPhone: '+91 75588 •••85',
        fullPhone: '+91 7558804685',
        collegeInfo: 'NIT Calicut',
        statusTag: 'Interested',
        statusColor: const Color(0xFF15803D),
        statusBg: const Color(0xFFE6F4EA),
        campaignTag: 'Call Log',
        category: 'hot_lead',
      );

      final lead2 = ExecutiveLeadItem(
        id: 'lead_2',
        name: 'Prospective Student 2',
        initials: 'PS',
        maskedPhone: '+91 90374 •••48',
        fullPhone: '+91 9037424448',
        collegeInfo: 'GEC Barton Hill',
        statusTag: 'Follow-up',
        statusColor: const Color(0xFF3730A3),
        statusBg: const Color(0xFFE8EDFF),
        campaignTag: 'Call Log',
        category: 'follow_up',
      );

      final lead3 = ExecutiveLeadItem(
        id: 'lead_3',
        name: 'Prospective Student 3',
        initials: 'PS',
        maskedPhone: '+91 62384 •••78',
        fullPhone: '+91 6238445578',
        collegeInfo: 'CET Trivandrum',
        statusTag: 'Pending',
        statusColor: const Color(0xFFB54708),
        statusBg: const Color(0xFFFEF0C7),
        campaignTag: 'Campus Drive',
        category: 'reminder',
      );

      final lead4 = ExecutiveLeadItem(
        id: 'lead_4',
        name: 'General Assigned Lead',
        initials: 'GL',
        maskedPhone: '+91 98470 •••00',
        fullPhone: '+91 9847012345',
        collegeInfo: 'Model Engg',
        statusTag: 'Assigned',
        statusColor: const Color(0xFF3730A3),
        statusBg: const Color(0xFFE8EDFF),
        campaignTag: 'Walk-in',
      );

      final state = LeadsState(
        leads: [lead1, lead2, lead3, lead4],
        callRecords: const [],
      );

      expect(state.hotLeads.length, equals(1));
      expect(state.hotLeads.first.id, equals('lead_1'));

      expect(state.followUpLeads.length, equals(1));
      expect(state.followUpLeads.first.id, equals('lead_2'));

      expect(state.reminderLeads.length, equals(1));
      expect(state.reminderLeads.first.id, equals('lead_3'));

      // Filtered leads for all
      expect(state.filteredLeads.length, equals(4));

      // Filtered leads for hot leads
      final hotState = state.copyWith(categoryFilter: HomeCategoryFilter.hotLeads);
      expect(hotState.filteredLeads.length, equals(1));
      expect(hotState.filteredLeads.first.id, equals('lead_1'));

      // Filtered leads for follow-ups
      final fuState = state.copyWith(categoryFilter: HomeCategoryFilter.followUps);
      expect(fuState.filteredLeads.length, equals(1));
      expect(fuState.filteredLeads.first.id, equals('lead_2'));

      // Filtered leads for reminders
      final remState = state.copyWith(categoryFilter: HomeCategoryFilter.reminders);
      expect(remState.filteredLeads.length, equals(1));
      expect(remState.filteredLeads.first.id, equals('lead_3'));
    });

    test('TC-CL-005: Explicit category is mutually exclusive and does not leak across tabs', () {
      final legacyReminder = ExecutiveLeadItem(
        id: 'lead_rem',
        name: 'L01',
        initials: 'L',
        maskedPhone: '+91 98765 •••10',
        fullPhone: '+91 9876543210',
        collegeInfo: 'Call Log Inquiry',
        statusTag: 'Follow-up',
        statusColor: const Color(0xFFB45309),
        statusBg: const Color(0xFFFFFBEB),
        campaignTag: 'Call Log',
        category: 'reminder',
      );

      final otherOutcome = ExecutiveLeadItem(
        id: 'lead_other',
        name: 'L02',
        initials: 'L',
        maskedPhone: '+91 98765 •••11',
        fullPhone: '+91 9876543211',
        collegeInfo: 'Call Log Inquiry',
        statusTag: 'Callback',
        statusColor: const Color(0xFF344054),
        statusBg: const Color(0xFFF2F4F7),
        campaignTag: 'Call Log',
        category: 'other',
      );

      final state = LeadsState(
        leads: [legacyReminder, otherOutcome],
        callRecords: const [],
      );

      expect(state.reminderLeads.map((e) => e.id), equals(['lead_rem']));
      expect(state.followUpLeads, isEmpty);
      expect(state.hotLeads, isEmpty);
    });
  });
}

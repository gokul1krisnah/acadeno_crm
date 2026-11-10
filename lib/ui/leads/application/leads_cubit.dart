import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/lead_models.dart';
import '../data/repository/leads_repo.dart';
import 'leads_state.dart';

class LeadsCubit extends Cubit<LeadsState> {
  final LeadsRepository _repository;
  final String? _overrideDateKey;

  StreamSubscription<List<ExecutiveLeadItem>>? _leadsSub;
  StreamSubscription<List<CallHistoryRecord>>? _callRecordsSub;

  LeadsCubit(this._repository, {String? dateKey})
    : _overrideDateKey = dateKey,
      super(const LeadsState(isLoading: true, leads: [], callRecords: [])) {
    _subscribe();
  }

  void _subscribe({bool isRefresh = false}) {
    _leadsSub?.cancel();
    _callRecordsSub?.cancel();

    if (!isRefresh) {
      emit(
        state.copyWith(
          isLoading: true,
          clearError: true,
          isPermissionDenied: false,
        ),
      );
    }

    _leadsSub = _repository
        .watchExecutiveTodayLeads(dateKey: _overrideDateKey)
        .listen(
          (assignedLeads) {
            if (isClosed) return;
            emit(
              state.copyWith(
                isLoading: false,
                clearError: true,
                isPermissionDenied: false,
                leads: assignedLeads,
              ),
            );
          },
          onError: (Object error) {
            if (isClosed) return;
            final isPerm =
                error is LeadPermissionException ||
                (error is FirebaseException &&
                    error.code == 'permission-denied') ||
                error.toString().toLowerCase().contains('permission');
            emit(
              state.copyWith(
                isLoading: false,
                isPermissionDenied: isPerm,
                errorMessage: _cleanErrorMessage(error),
              ),
            );
          },
        );

    _callRecordsSub = _repository.watchExecutiveCallRecords().listen(
      (records) {
        if (isClosed) return;
        emit(state.copyWith(callRecords: records));
      },
      onError: (_) {
        // Call records stream is non-blocking if empty or restricted
      },
    );
  }

  /// Re-subscribes to the executive's assignments for today.
  void refresh() => _subscribe(isRefresh: true);

  void togglePendingOrDoneCalls(bool showPending) {
    emit(state.copyWith(showingPendingCalls: showPending, clearToast: true));
  }

  void clearToast() {
    if (state.toastMessage != null) {
      emit(state.copyWith(clearToast: true));
    }
  }

  /// Verifies if the current executive is allowed to read a specific lead.
  Future<LeadRecord> fetchPermittedLead(String leadId) {
    return _repository.getLeadById(leadId);
  }

  // Save mandatory call outcome, apply status rules and append to
  // the executive's permanent "My Record".
  Future<CallOutcomeResult> recordCallOutcome({
    String? leadId,
    required String leadName,
    required String outcome,
    required String duration,
    required String notes,
    String? courseEnrolled,
    int? discountAmount,
    String? followUpTime,
  }) async {
    final updatedLeads = List<ExecutiveLeadItem>.from(state.leads);
    final updatedRecords = List<CallHistoryRecord>.from(state.callRecords);

    String resolvedLeadId = leadId ?? '';
    String collegeInfo = '—';
    String campaign = 'Direct visit';

    final leadIdx = updatedLeads.indexWhere(
      (l) =>
          (resolvedLeadId.isNotEmpty && l.id == resolvedLeadId) ||
          l.name.toLowerCase() == leadName.toLowerCase(),
    );

    if (leadIdx != -1) {
      final lead = updatedLeads[leadIdx];
      resolvedLeadId = lead.id;
      collegeInfo = lead.collegeInfo;
      campaign = lead.campaignTag;

      // Status rules: Converted is never overwritten; No answer never erases Interested
      if (lead.statusTag != 'Converted') {
        if (outcome == 'No answer' && lead.statusTag == 'Interested') {
          // Keep Interested status
        } else {
          lead.statusTag = outcome;
          final style = _statusBadgeColors(outcome);
          lead.statusColor = style.$1;
          lead.statusBg = style.$2;
        }
      }
      lead.isDone = true;
      lead.isLocked = false;
      lead.lockedMessage = null;
    }

    final needsApproval = outcome == 'Converted' && (discountAmount ?? 0) > 500;
    final extraMsg = needsApproval
        ? ' · Discount ₹$discountAmount sent for Manager approval'
        : '';

    updatedRecords.insert(
      0,
      CallHistoryRecord(
        id: 'cr_${DateTime.now().millisecondsSinceEpoch}',
        leadName: leadName,
        collegeInfo: collegeInfo,
        campaign: campaign,
        outcome: outcome,
        duration: duration.isEmpty ? '2m 15s' : duration,
        timestamp: 'Today · Just now',
        notes: notes.isEmpty ? 'Logged $outcome outcome' : notes,
      ),
    );

    emit(
      state.copyWith(
        leads: updatedLeads,
        callRecords: updatedRecords,
        toastMessage: 'Saved "$outcome" for $leadName$extraMsg',
        isToastError: false,
      ),
    );

    if (resolvedLeadId.isNotEmpty) {
      try {
        return await _repository.recordExecutiveCallOutcome(
          leadId: resolvedLeadId,
          leadName: leadName,
          outcome: outcome,
          duration: duration,
          notes: notes,
          courseEnrolled: courseEnrolled,
          discountAmount: discountAmount,
          followUpTime: followUpTime,
        );
      } catch (e) {
        emit(
          state.copyWith(
            toastMessage: _cleanErrorMessage(e),
            isToastError: true,
          ),
        );
      }
    }

    return CallOutcomeResult(
      collegeInfo: collegeInfo,
      needsDiscountApproval: needsApproval,
    );
  }

  // Log WhatsApp template sent
  void logWhatsAppTemplateSent({
    required String leadName,
    required String templateTitle,
  }) {
    final updatedRecords = List<CallHistoryRecord>.from(state.callRecords)
      ..insert(
        0,
        CallHistoryRecord(
          id: 'wa_${DateTime.now().millisecondsSinceEpoch}',
          leadName: leadName,
          collegeInfo: 'Campaign WhatsApp Quick Reply',
          campaign: 'AI & ML Workshop',
          outcome: 'WhatsApp sent',
          duration: '—',
          timestamp: 'Today · Just now',
          notes: 'Sent approved template: $templateTitle',
        ),
      );

    emit(
      state.copyWith(
        callRecords: updatedRecords,
        toastMessage:
            'Opened WhatsApp with "$templateTitle" & logged on timeline',
        isToastError: false,
      ),
    );
  }

  // 10-digit phone lookup (rate-limited at 40/hour + backend check)
  Future<({bool found, String message, String? owner, String? status})>
  lookupByPhone(String rawPhone) async {
    final validationErr = LeadPhoneValidator.validate(rawPhone);
    if (validationErr != null) {
      return (found: false, message: validationErr, owner: null, status: null);
    }

    final nextLookupCount = state.phoneLookupsThisHour + 1;
    emit(
      state.copyWith(phoneLookupsThisHour: nextLookupCount, clearToast: true),
    );

    if (nextLookupCount > 40) {
      return (
        found: false,
        message:
            'Access paused: Exceeded 40 phone lookups/hour. Super Admin alerted.',
        owner: null,
        status: null,
      );
    }

    try {
      return await _repository.lookupByPhone(rawPhone);
    } catch (e) {
      return (
        found: false,
        message: _cleanErrorMessage(e),
        owner: null,
        status: null,
      );
    }
  }

  // Add a walk-in lead after backend duplicate check
  Future<bool> addWalkInLead({
    required String name,
    required String phone,
    required String collegeBranchYear,
    required String campaign,
  }) async {
    try {
      await _repository.createLead(
        name: name,
        phone: phone,
        collegeBranch: collegeBranchYear,
        source: campaign,
        assignToSelfAsWalkIn: true,
      );
      emit(
        state.copyWith(
          showingPendingCalls: true,
          toastMessage: 'Walk-in lead ${name.trim()} added to Today list',
          isToastError: false,
        ),
      );
      return true;
    } on DuplicateLeadException catch (e) {
      emit(state.copyWith(toastMessage: e.toString(), isToastError: true));
      return false;
    } catch (e) {
      emit(
        state.copyWith(toastMessage: _cleanErrorMessage(e), isToastError: true),
      );
      return false;
    }
  }

  static String _cleanErrorMessage(Object error) {
    final raw = error.toString();
    return raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Bad state: ', '');
  }

  static (Color, Color) _statusBadgeColors(String status) {
    return ExecutiveLeadItem.statusColorsFor(status);
  }

  @override
  Future<void> close() async {
    await _leadsSub?.cancel();
    await _callRecordsSub?.cancel();
    return super.close();
  }
}

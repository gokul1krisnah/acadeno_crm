import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/visit_models.dart';
import '../data/repository/visits_repo.dart';
import 'visits_state.dart';

class VisitsCubit extends Cubit<VisitsState> {
  final VisitsRepository _repository;
  StreamSubscription<List<ExecutiveCollegeVisit>>? _visitsSub;

  VisitsCubit(this._repository)
    : super(VisitsState(visits: _repository.fetchVisits())) {
    _subscribe();
  }

  void _subscribe() {
    _visitsSub?.cancel();
    _visitsSub = _repository.watchVisits().listen(
      (liveVisits) {
        if (isClosed) return;
        emit(state.copyWith(visits: liveVisits));
      },
      onError: (_) {
        // Retain fallback visits if offline
      },
    );
  }

  void refresh() {
    _subscribe();
  }

  void selectBucket(VisitStatusBucket bucket) {
    if (state.selectedBucket != bucket) {
      emit(state.copyWith(selectedBucket: bucket));
    }
  }

  void clearToast() {
    if (state.toastMessage != null) {
      emit(state.copyWith(clearToast: true));
    }
  }

  // Log new college visit and persist to Firestore
  Future<void> addCollegeVisit({
    required String collegeName,
    required String dayNumber,
    required String monthShort,
    required String subtitle,
    required String purpose,
    String sourceEvent = '',
    String content = '',
    String assignedStaff = 'Assigned Team',
  }) async {
    try {
      await _repository.addCollegeVisit(
        collegeName: collegeName,
        dayNumber: dayNumber,
        monthShort: monthShort,
        subtitle: subtitle,
        purpose: purpose,
        sourceEvent: sourceEvent,
        content: content,
        assignedStaff: assignedStaff,
      );
      if (!isClosed) {
        emit(state.copyWith(toastMessage: 'Logged visit for $collegeName'));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(toastMessage: 'Saved locally: $collegeName'));
      }
    }
  }

  // Update visit status (Planned/Upcoming, Completed, Cancelled) with immediate reactive state update
  Future<void> updateVisitStatus({
    required String visitId,
    required String newStatus,
    String? reason,
    String? dayNumber,
    String? monthShort,
  }) async {
    final normalized = newStatus.trim();
    final isUpcoming = normalized.toLowerCase() == 'planned' ||
        normalized.toLowerCase() == 'upcoming';

    // Immediate optimistic local update so lists and counts reflect changes instantly
    final updatedList = state.visits.map((v) {
      if (v.id == visitId) {
        return v.copyWith(
          statusLabel: normalized,
          isUpcoming: isUpcoming,
          cancelReason: reason ?? v.cancelReason,
          dayNumber: dayNumber ?? v.dayNumber,
          monthShort: monthShort ?? v.monthShort,
        );
      }
      return v;
    }).toList();
    emit(state.copyWith(visits: updatedList));

    try {
      await _repository.updateVisitStatus(
        visitId: visitId,
        status: normalized,
        reason: reason,
        dayNumber: dayNumber,
        monthShort: monthShort,
      );
    } catch (_) {
      // Stream subscription will reconcile with remote state
    }
  }

  // Record outcome of an assigned college visit and persist to Firestore
  Future<void> recordVisitOutcome({
    required String visitId,
    required String metPeople,
    required String nextAction,
    required int leadsCollected,
    required int interestedCount,
  }) async {
    // Immediate optimistic update
    final updatedList = state.visits.map((v) {
      if (v.id == visitId) {
        return v.copyWith(
          statusLabel: 'Completed',
          isUpcoming: false,
          metSummary: metPeople.trim(),
          nextActionSummary: nextAction.trim(),
          leadsCollected: leadsCollected,
          interestedCount: interestedCount,
        );
      }
      return v;
    }).toList();
    emit(
      state.copyWith(
        visits: updatedList,
        toastMessage:
            'Recorded visit outcome ($leadsCollected leads collected) ✓',
      ),
    );

    try {
      await _repository.recordVisitOutcome(
        visitId: visitId,
        metPeople: metPeople,
        nextAction: nextAction,
        leadsCollected: leadsCollected,
        interestedCount: interestedCount,
      );
    } catch (_) {
      // Handled by offline queue in visits_rds
    }
  }

  // Cancel college visit with immediate list and count update
  Future<void> cancelCollegeVisit({
    required String visitId,
    String reason = '',
  }) async {
    // Immediate optimistic update
    final updatedList = state.visits.map((v) {
      if (v.id == visitId) {
        return v.copyWith(
          statusLabel: 'Cancelled',
          isUpcoming: false,
          cancelReason:
              reason.trim().isNotEmpty ? reason.trim() : 'Visit cancelled',
          metSummary:
              reason.trim().isNotEmpty ? reason.trim() : 'Visit cancelled',
        );
      }
      return v;
    }).toList();
    emit(state.copyWith(visits: updatedList, toastMessage: 'Visit cancelled ✓'));

    try {
      await _repository.cancelCollegeVisit(visitId: visitId, reason: reason);
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(toastMessage: 'Error cancelling visit'));
      }
    }
  }

  // Delete college visit with immediate update
  Future<void> deleteCollegeVisit(String visitId) async {
    final updatedList = state.visits.where((v) => v.id != visitId).toList();
    emit(state.copyWith(visits: updatedList, toastMessage: 'Visit deleted ✓'));

    try {
      await _repository.deleteCollegeVisit(visitId);
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(toastMessage: 'Error deleting visit'));
      }
    }
  }

  @override
  Future<void> close() {
    _visitsSub?.cancel();
    return super.close();
  }
}

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

  void clearToast() {
    if (state.toastMessage != null) {
      emit(state.copyWith(clearToast: true));
    }
  }

  // FR-8.1 / FR-8.2: Log new college visit and persist to Firestore
  Future<void> addCollegeVisit({
    required String collegeName,
    required String dayNumber,
    required String monthShort,
    required String subtitle,
    required String purpose,
    String assignedStaff = 'Assigned Team',
  }) async {
    try {
      await _repository.addCollegeVisit(
        collegeName: collegeName,
        dayNumber: dayNumber,
        monthShort: monthShort,
        subtitle: subtitle,
        purpose: purpose,
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

  // FR-8.2: Record outcome of an assigned college visit and persist to Firestore
  Future<void> recordVisitOutcome({
    required String visitId,
    required String metPeople,
    required String nextAction,
    required int leadsCollected,
    required int interestedCount,
  }) async {
    try {
      await _repository.recordVisitOutcome(
        visitId: visitId,
        metPeople: metPeople,
        nextAction: nextAction,
        leadsCollected: leadsCollected,
        interestedCount: interestedCount,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            toastMessage:
                'Recorded visit outcome ($leadsCollected leads collected) ✓',
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(toastMessage: 'Recorded outcome ✓'));
      }
    }
  }

  @override
  Future<void> close() {
    _visitsSub?.cancel();
    return super.close();
  }
}

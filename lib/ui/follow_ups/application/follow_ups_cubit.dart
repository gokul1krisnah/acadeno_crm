import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/follow_up_models.dart';
import '../data/repository/follow_ups_repo.dart';
import 'follow_ups_state.dart';

class FollowUpsCubit extends Cubit<FollowUpsState> {
  final FollowUpsRepository _repository;
  StreamSubscription<List<ExecutiveFollowUpItem>>? _sub;

  FollowUpsCubit(this._repository)
      : super(FollowUpsState(followUps: _repository.fetchFollowUps())) {
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _repository.watchFollowUps().listen(
      (liveItems) {
        if (isClosed) return;
        emit(state.copyWith(followUps: liveItems));
      },
      onError: (_) {
        // Fallback gracefully if offline
      },
    );
  }

  void selectFollowUpBucket(FollowUpBucket bucket) {
    emit(state.copyWith(selectedFollowUpBucket: bucket, clearToast: true));
  }

  void clearToast() {
    if (state.toastMessage != null) {
      emit(state.copyWith(clearToast: true));
    }
  }

  // FR-4.1 & FR-4.3: Create follow-up when a call outcome is Follow-up,
  // Interested, or No answer (auto-retry up to 3 tries).
  void addFromCallOutcome({
    required String leadName,
    required String collegeInfo,
    required String outcome,
    required String notes,
    String? followUpTimeLabel,
    String? maskedPhone,
  }) {
    final updated = List<ExecutiveFollowUpItem>.from(state.followUps);

    if (outcome == 'Follow-up' || outcome == 'Interested') {
      updated.insert(
        0,
        ExecutiveFollowUpItem(
          id: 'fu_${DateTime.now().millisecondsSinceEpoch}',
          leadName: leadName,
          maskedPhone: maskedPhone ?? '—',
          collegeInfo: collegeInfo,
          timeLabel: followUpTimeLabel ?? 'Tomorrow · 10:30 AM',
          channelLabel: 'Call',
          note: notes.isEmpty
              ? 'Scheduled follow-up after $outcome call'
              : notes,
          bucket: FollowUpBucket.upcoming,
        ),
      );
    } else if (outcome == 'No answer') {
      updated.insert(
        0,
        ExecutiveFollowUpItem(
          id: 'fu_${DateTime.now().millisecondsSinceEpoch}',
          leadName: leadName,
          maskedPhone: maskedPhone ?? '—',
          collegeInfo: collegeInfo,
          timeLabel: 'Auto-retry',
          channelLabel: 'Auto-retry',
          note: 'Retry – not reachable',
          bucket: FollowUpBucket.today,
        ),
      );
    } else {
      return;
    }

    emit(state.copyWith(followUps: updated));
  }

  // FR-4.5: Snooze follow-up and persist to Firestore
  Future<void> snoozeFollowUp(
    String id,
    String newTimeLabel, {
    bool moveToUpcoming = false,
  }) async {
    final updated = List<ExecutiveFollowUpItem>.from(state.followUps);
    final idx = updated.indexWhere((f) => f.id == id);
    String name = 'lead';
    if (idx != -1) {
      final item = updated[idx];
      name = item.leadName;
      item.timeLabel = newTimeLabel;
      if (moveToUpcoming) {
        item.bucket = FollowUpBucket.upcoming;
      }
    }

    await _repository.snoozeFollowUp(
      id,
      newTimeLabel,
      moveToUpcoming: moveToUpcoming,
    );

    emit(
      state.copyWith(
        followUps: updated,
        toastMessage: 'Rescheduled follow-up with $name to $newTimeLabel',
      ),
    );
  }

  // FR-4.2: Complete follow-up directly in Firestore
  Future<void> completeFollowUp(String id) => markCompleted(id);

  // FR-4.2: Mark follow-up as done directly in Firestore
  Future<void> markCompleted(String id) async {
    final updated = List<ExecutiveFollowUpItem>.from(state.followUps);
    final idx = updated.indexWhere((f) => f.id == id);
    String name = 'lead';
    if (idx != -1) {
      name = updated[idx].leadName;
      updated.removeAt(idx);
    }

    await _repository.completeFollowUp(id);

    emit(
      state.copyWith(
        followUps: updated,
        toastMessage: 'Follow-up with $name marked complete',
      ),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

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
  }) {
    final updated = List<ExecutiveFollowUpItem>.from(state.followUps);

    if (outcome == 'Follow-up' || outcome == 'Interested') {
      updated.insert(
        0,
        ExecutiveFollowUpItem(
          id: 'fu_${DateTime.now().millisecondsSinceEpoch}',
          leadName: leadName,
          maskedPhone: '98470 •••11',
          collegeInfo: collegeInfo,
          timeLabel: followUpTimeLabel ?? 'Tomorrow · 10:30 AM',
          channelLabel: 'Call',
          note: notes.isEmpty ? 'Scheduled follow-up after $outcome call' : notes,
          bucket: FollowUpBucket.upcoming,
        ),
      );
    } else if (outcome == 'No answer') {
      updated.insert(
        0,
        ExecutiveFollowUpItem(
          id: 'fu_${DateTime.now().millisecondsSinceEpoch}',
          leadName: leadName,
          maskedPhone: '98460 •••22',
          collegeInfo: collegeInfo,
          timeLabel: '4:30 PM',
          channelLabel: 'Auto-retry',
          note: 'Retry – not reachable (1 of 3)',
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
      } else if (item.bucket == FollowUpBucket.overdue) {
        item.bucket = FollowUpBucket.today;
      }
      emit(
        state.copyWith(
          followUps: updated,
          toastMessage: 'Snoozed $name to $newTimeLabel',
        ),
      );
    }
    await _repository.snoozeFollowUp(
      id,
      newTimeLabel,
      moveToUpcoming: moveToUpcoming,
    );
  }

  // FR-4.5: Complete follow-up and persist to Firestore
  Future<void> completeFollowUp(String id) async {
    final updated = List<ExecutiveFollowUpItem>.from(state.followUps);
    final idx = updated.indexWhere((f) => f.id == id);
    if (idx != -1) {
      final name = updated[idx].leadName;
      updated[idx].isCompleted = true;
      emit(
        state.copyWith(
          followUps: updated,
          toastMessage: 'Marked follow-up for $name as done ✓',
        ),
      );
    }
    await _repository.completeFollowUp(id);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

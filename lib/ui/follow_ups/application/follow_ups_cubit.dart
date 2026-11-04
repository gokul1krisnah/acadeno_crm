import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/app_notification_service.dart';
import '../data/model/follow_up_models.dart';
import '../data/repository/follow_ups_repo.dart';
import 'follow_ups_state.dart';

class FollowUpsCubit extends Cubit<FollowUpsState> {
  final FollowUpsRepository _repository;
  StreamSubscription<List<ExecutiveFollowUpItem>>? _sub;
  Timer? _periodicCheckTimer;
  final Set<String> _notifiedOverdueIds = <String>{};

  FollowUpsCubit(this._repository)
    : super(FollowUpsState(followUps: _repository.fetchFollowUps())) {
    _subscribe();
    _startPeriodicOverdueCheck();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _repository.watchFollowUps().listen(
      (liveItems) {
        if (isClosed) return;
        emit(state.copyWith(followUps: liveItems, isLoading: false));
        _notifyOverdueItems(liveItems);
      },
      onError: (_) {
        if (isClosed) return;
        emit(state.copyWith(isLoading: false));
      },
    );
  }

  void _startPeriodicOverdueCheck() {
    _periodicCheckTimer?.cancel();
    // Re-check every 30 seconds so time-sensitive slots transition to Overdue automatically
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isClosed) {
        refresh(silent: true);
      }
    });
  }

  /// Refreshes follow-ups directly from Cloud Firestore.
  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true));
    }
    try {
      final items = await _repository.fetchLiveFollowUps();
      if (!isClosed) {
        emit(state.copyWith(followUps: items, isLoading: false));
        _notifyOverdueItems(items);
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  /// Triggers push notification and in-app alerts for any newly detected overdue follow-ups
  void _notifyOverdueItems(List<ExecutiveFollowUpItem> items) {
    final overdue = items
        .where((f) => !f.isCompleted && f.bucket == FollowUpBucket.overdue)
        .toList();

    for (final item in overdue) {
      if (!_notifiedOverdueIds.contains(item.id)) {
        _notifiedOverdueIds.add(item.id);

        AppNotificationService.instance.showNativeNotification(
          title: '⚠️ Overdue Follow-up: ${item.leadName}',
          body:
              '${item.leadName} (${item.collegeInfo}) was scheduled for ${item.timeLabel} and is now overdue.',
          tag: 'followup_overdue_${item.id}',
          id: item.id.hashCode,
        );
      }
    }
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
      final isDueToday = followUpTimeLabel != null &&
          (followUpTimeLabel.toLowerCase().contains('today') ||
              followUpTimeLabel.toLowerCase().contains('5 pm') ||
              followUpTimeLabel.toLowerCase().contains('now'));
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
          bucket: isDueToday ? FollowUpBucket.today : FollowUpBucket.upcoming,
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
    if (idx == -1) return;
    updated.removeAt(idx);

    // Optimistic immediate update to prevent lag, double rebuilds, or screen blinking
    emit(state.copyWith(followUps: updated, clearToast: true));

    try {
      await _repository.completeFollowUp(id);
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _periodicCheckTimer?.cancel();
    return super.close();
  }
}

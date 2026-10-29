import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/alert_models.dart';
import '../data/repository/alerts_repo.dart';
import 'alerts_state.dart';

class AlertsCubit extends Cubit<AlertsState> {
  final AlertsRepository _repository;
  StreamSubscription<List<ExecutiveAlertItem>>? _alertsSub;

  AlertsCubit(this._repository)
      : super(AlertsState(alerts: _repository.fetchAlerts())) {
    _subscribe();
  }

  void _subscribe() {
    _alertsSub?.cancel();
    _alertsSub = _repository.watchAlerts().listen(
      (liveAlerts) {
        if (isClosed) return;
        emit(state.copyWith(alerts: liveAlerts));
      },
      onError: (_) {},
    );
  }

  void clearToast() {
    if (state.toastMessage != null) {
      emit(state.copyWith(clearToast: true));
    }
  }

  // FR-5.4: Discount above ₹500 raises an approval request for the manager.
  void addDiscountApprovalAlert({
    required String leadName,
    required String? courseEnrolled,
    required int discountAmount,
  }) {
    final updated = List<ExecutiveAlertItem>.from(state.alerts)
      ..insert(
        0,
        ExecutiveAlertItem(
          id: 'al_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Discount approval requested: $leadName',
          subtitle:
              '${courseEnrolled ?? "AI Workshop"} · Discount ₹$discountAmount awaiting manager approval',
          timeLabel: 'Just now',
          iconType: AlertIconType.clock,
          isToday: true,
          isUnread: true,
        ),
      );
    emit(state.copyWith(alerts: updated));
  }

  // FR-9.1: Mark all alerts read
  void markAllAlertsRead() {
    final updated = List<ExecutiveAlertItem>.from(state.alerts);
    for (final a in updated) {
      a.isUnread = false;
    }
    emit(
      state.copyWith(
        alerts: updated,
        toastMessage: 'All alerts marked as read',
      ),
    );
  }

  // Toggle read status of a single alert
  void toggleAlertRead(String id) {
    final updated = List<ExecutiveAlertItem>.from(state.alerts);
    final idx = updated.indexWhere((a) => a.id == id);
    if (idx != -1) {
      updated[idx].isUnread = !updated[idx].isUnread;
      emit(state.copyWith(alerts: updated));
    }
  }

  // FR-9.1: Mark a single alert as read
  void markSingleAlertRead(String id) {
    final updated = List<ExecutiveAlertItem>.from(state.alerts);
    final idx = updated.indexWhere((a) => a.id == id);
    if (idx != -1) {
      updated[idx].isUnread = false;
      emit(state.copyWith(alerts: updated));
    }
  }

  @override
  Future<void> close() {
    _alertsSub?.cancel();
    return super.close();
  }
}

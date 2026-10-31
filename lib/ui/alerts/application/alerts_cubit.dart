import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  // FR-5.4: Discount above ₹500 raises a persistent approval request in Firestore
  Future<void> addDiscountApprovalAlert({
    required String leadName,
    required String? courseEnrolled,
    required int discountAmount,
  }) async {
    try {
      final doc = FirebaseFirestore.instance.collection('alerts').doc();
      await doc.set({
        'id': doc.id,
        'recipientUid': 'all',
        'title': 'Discount approval requested: $leadName',
        'subtitle':
            '${courseEnrolled ?? "AI Workshop"} · Discount ₹$discountAmount awaiting manager approval',
        'category': 'overdue',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // FR-9.1: Mark all alerts read
  void markAllAlertsRead() {
    _repository.markAllAlertsRead();
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
      final newStatus = !updated[idx].isUnread;
      updated[idx].isUnread = newStatus;
      if (!newStatus) {
        _repository.markAlertRead(id);
      }
      emit(state.copyWith(alerts: updated));
    }
  }

  // FR-9.1: Mark a single alert as read
  void markSingleAlertRead(String id) {
    _repository.markAlertRead(id);
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

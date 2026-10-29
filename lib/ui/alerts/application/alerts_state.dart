import '../data/model/alert_models.dart';

class AlertsState {
  final List<ExecutiveAlertItem> alerts;
  final String? toastMessage;

  const AlertsState({required this.alerts, this.toastMessage});

  List<ExecutiveAlertItem> get todayAlerts =>
      alerts.where((a) => a.isToday).toList();

  List<ExecutiveAlertItem> get earlierAlerts =>
      alerts.where((a) => !a.isToday).toList();

  int get unreadAlertsCount => alerts.where((a) => a.isUnread).length;

  AlertsState copyWith({
    List<ExecutiveAlertItem>? alerts,
    String? toastMessage,
    bool clearToast = false,
  }) {
    return AlertsState(
      alerts: alerts ?? this.alerts,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
    );
  }
}


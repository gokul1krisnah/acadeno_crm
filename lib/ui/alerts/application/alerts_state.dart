import '../data/model/alert_models.dart';

class AlertsState {
  final List<ExecutiveAlertItem> alerts;
  final String? toastMessage;
  final bool isLoading;

  const AlertsState({
    required this.alerts,
    this.toastMessage,
    this.isLoading = false,
  });

  /// Alerts created today, strictly ordered newest first
  List<ExecutiveAlertItem> get todayAlerts {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final list = alerts.where((a) {
      final aDay = DateTime(
        a.createdAt.year,
        a.createdAt.month,
        a.createdAt.day,
      );
      return aDay.isAtSameMomentAs(startOfToday) || aDay.isAfter(startOfToday);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Alerts created yesterday, strictly ordered newest first
  List<ExecutiveAlertItem> get yesterdayAlerts {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    final list = alerts.where((a) {
      final aDay = DateTime(
        a.createdAt.year,
        a.createdAt.month,
        a.createdAt.day,
      );
      return aDay.isAtSameMomentAs(startOfYesterday);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Alerts created before yesterday, strictly ordered newest first
  List<ExecutiveAlertItem> get earlierAlerts {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    final list = alerts.where((a) {
      final aDay = DateTime(
        a.createdAt.year,
        a.createdAt.month,
        a.createdAt.day,
      );
      return aDay.isBefore(startOfYesterday);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get unreadAlertsCount => alerts.where((a) => a.isUnread).length;

  AlertsState copyWith({
    List<ExecutiveAlertItem>? alerts,
    String? toastMessage,
    bool clearToast = false,
    bool? isLoading,
  }) {
    return AlertsState(
      alerts: alerts ?? this.alerts,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

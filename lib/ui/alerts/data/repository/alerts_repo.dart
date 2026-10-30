import '../model/alert_models.dart';
import '../sources/alerts_rds.dart';

class AlertsRepository {
  final AlertsRds _rds;

  AlertsRepository(this._rds);

  List<ExecutiveAlertItem> fetchAlerts() => _rds.fetchAlerts();

  Stream<List<ExecutiveAlertItem>> watchAlerts({String? executiveUid}) =>
      _rds.watchAlerts(executiveUid: executiveUid);

  Future<void> markAllAlertsRead({String? executiveUid}) =>
      _rds.markAllAlertsRead(executiveUid: executiveUid);

  Future<void> markAlertRead(String alertId) =>
      _rds.markAlertRead(alertId);
}

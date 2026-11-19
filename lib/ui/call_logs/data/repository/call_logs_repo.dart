import '../model/call_log_model.dart';
import '../sources/call_logs_rds.dart';
import '../../../leads/data/model/lead_models.dart';

class CallLogsRepository {
  final CallLogsRds _rds;

  CallLogsRepository(this._rds);

  bool get isPlatformSupported => _rds.isPlatformSupported;

  Future<bool> checkPermission() => _rds.checkPermission();

  Future<bool> requestPermission() => _rds.requestPermission();

  Future<bool> checkContactsPermission() => _rds.checkContactsPermission();

  Future<bool> requestContactsPermission() => _rds.requestContactsPermission();

  Future<List<DeviceCallLogItem>> fetchDeviceCallLogs({int limit = 100}) =>
      _rds.fetchDeviceCallLogs(limit: limit);

  Stream<Map<String, CallCategory>> streamSavedCategorizations() =>
      _rds.streamSavedCategorizations();

  Future<void> saveCategorization({
    required DeviceCallLogItem item,
    required CallCategory category,
    String? notes,
  }) => _rds.saveCategorization(item: item, category: category, notes: notes);

  Future<void> saveOtherOutcome({
    required DeviceCallLogItem item,
    required String outcome,
    required String notes,
    String? courseEnrolled,
    String? batch,
    String? followUpTime,
  }) => _rds.saveOtherOutcome(
    item: item,
    outcome: outcome,
    notes: notes,
    courseEnrolled: courseEnrolled,
    batch: batch,
    followUpTime: followUpTime,
  );

  Stream<List<ExecutiveLeadItem>> streamLeadsByCategory(CallCategory category) =>
      _rds.streamLeadsByCategory(category);
}

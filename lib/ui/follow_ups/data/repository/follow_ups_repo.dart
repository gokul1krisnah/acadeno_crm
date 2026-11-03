import '../model/follow_up_models.dart';
import '../sources/follow_ups_rds.dart';

class FollowUpsRepository {
  final FollowUpsRds _rds;

  FollowUpsRepository(this._rds);

  List<ExecutiveFollowUpItem> fetchFollowUps() => _rds.fetchFollowUps();

  Future<List<ExecutiveFollowUpItem>> fetchLiveFollowUps({
    String? executiveUid,
  }) => _rds.fetchLiveFollowUps(executiveUid: executiveUid);

  Stream<List<ExecutiveFollowUpItem>> watchFollowUps({String? executiveUid}) =>
      _rds.watchFollowUps(executiveUid: executiveUid);

  Stream<List<ExecutiveFollowUpItem>> watchAllFollowUps() =>
      _rds.watchAllFollowUps();

  Future<void> completeFollowUp(String id) => _rds.completeFollowUp(id);

  Future<void> snoozeFollowUp(
    String id,
    String newTimeLabel, {
    bool moveToUpcoming = false,
  }) => _rds.snoozeFollowUp(id, newTimeLabel, moveToUpcoming: moveToUpcoming);
}

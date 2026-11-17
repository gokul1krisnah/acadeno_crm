import '../model/visit_models.dart';
import '../sources/visits_rds.dart';

class VisitsRepository {
  final VisitsRds _rds;

  VisitsRepository(this._rds);

  List<ExecutiveCollegeVisit> fetchVisits() => _rds.fetchVisits();

  Stream<List<ExecutiveCollegeVisit>> watchVisits({String? executiveUid}) =>
      _rds.watchVisits(executiveUid: executiveUid);

  Future<void> addCollegeVisit({
    required String collegeName,
    required String dayNumber,
    required String monthShort,
    required String subtitle,
    required String purpose,
    String sourceEvent = '',
    String content = '',
    String assignedStaff = '',
  }) => _rds.addCollegeVisit(
    collegeName: collegeName,
    dayNumber: dayNumber,
    monthShort: monthShort,
    subtitle: subtitle,
    purpose: purpose,
    sourceEvent: sourceEvent,
    content: content,
    assignedStaff: assignedStaff,
  );

  Future<void> recordVisitOutcome({
    required String visitId,
    required String metPeople,
    required String nextAction,
    required int leadsCollected,
    required int interestedCount,
  }) => _rds.recordVisitOutcome(
    visitId: visitId,
    metPeople: metPeople,
    nextAction: nextAction,
    leadsCollected: leadsCollected,
    interestedCount: interestedCount,
  );

  Future<void> cancelCollegeVisit({
    required String visitId,
    String reason = '',
  }) => _rds.cancelCollegeVisit(visitId: visitId, reason: reason);

  Future<void> updateVisitStatus({
    required String visitId,
    required String status,
    String? reason,
    String? dayNumber,
    String? monthShort,
  }) => _rds.updateVisitStatus(
    visitId: visitId,
    status: status,
    reason: reason,
    dayNumber: dayNumber,
    monthShort: monthShort,
  );

  Future<void> deleteCollegeVisit(String visitId) =>
      _rds.deleteCollegeVisit(visitId);
}

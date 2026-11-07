import '../model/lead_import_models.dart';
import '../model/lead_models.dart';
import '../sources/leads_rds.dart';

class LeadsRepository {
  final LeadsRds _rds;

  LeadsRepository(this._rds);

  LeadsRds get rds => _rds;

  String? get currentUserId => _rds.currentUserId;

  String get currentUserDisplayName => _rds.currentUserDisplayName;

  // ---------------------------------------------------------------------------
  // Admin Leads & Assignment Operations
  // ---------------------------------------------------------------------------

  Stream<List<LeadRecord>> watchAllLeads() => _rds.watchAllLeads();

  Stream<List<SalesExecutiveOption>> watchActiveExecutives() =>
      _rds.watchActiveExecutives();

  Stream<List<LeadAssignmentModel>> watchAssignmentsForDate(String dateKey) =>
      _rds.watchAssignmentsForDate(dateKey);

  Future<LeadRecord> createLead({
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    String status = 'New',
    String notes = '',
    bool assignToSelfAsWalkIn = false,
  }) => _rds.createLead(
    name: name,
    phone: phone,
    collegeBranch: collegeBranch,
    source: source,
    status: status,
    notes: notes,
    assignToSelfAsWalkIn: assignToSelfAsWalkIn,
  );

  Future<LeadRecord> updateLead({
    required String leadId,
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    required String status,
    String? notes,
  }) => _rds.updateLead(
    leadId: leadId,
    name: name,
    phone: phone,
    collegeBranch: collegeBranch,
    source: source,
    status: status,
    notes: notes,
  );

  Future<AssignmentBatchSummary> assignLeadsToExecutive({
    required List<String> leadIds,
    required String executiveUid,
    required String dateKey,
    required String dateLabel,
    bool allowReassign = false,
  }) => _rds.assignLeadsToExecutive(
    leadIds: leadIds,
    executiveUid: executiveUid,
    dateKey: dateKey,
    dateLabel: dateLabel,
    allowReassign: allowReassign,
  );

  // ---------------------------------------------------------------------------
  // Sales Executive Today Dashboard Operations
  // ---------------------------------------------------------------------------

  Stream<List<ExecutiveLeadItem>> watchExecutiveTodayLeads({String? dateKey}) =>
      _rds.watchExecutiveTodayLeads(dateKey: dateKey);

  Stream<List<CallHistoryRecord>> watchExecutiveCallRecords() =>
      _rds.watchExecutiveCallRecords();

  Future<LeadRecord> getLeadById(String leadId) => _rds.getLeadById(leadId);

  Future<CallOutcomeResult> recordExecutiveCallOutcome({
    required String leadId,
    required String leadName,
    required String outcome,
    required String duration,
    required String notes,
    String? courseEnrolled,
    int? discountAmount,
    String? followUpTime,
  }) => _rds.recordExecutiveCallOutcome(
    leadId: leadId,
    leadName: leadName,
    outcome: outcome,
    duration: duration,
    notes: notes,
    courseEnrolled: courseEnrolled,
    discountAmount: discountAmount,
    followUpTime: followUpTime,
  );

  Future<({bool found, String message, String? owner, String? status})>
  lookupByPhone(String rawPhone) => _rds.lookupByPhone(rawPhone);

  // ---------------------------------------------------------------------------
  // Bulk Lead Import Operations
  // ---------------------------------------------------------------------------

  Future<List<LeadImportItem>> verifyImportAgainstFirestore(
    List<LeadImportItem> items,
  ) => _rds.verifyImportAgainstFirestore(items);

  Future<LeadImportSummary> executeBulkImport({
    required List<LeadImportItem> items,
    required String sourceEvent,
    required String consentBasis,
    required String fileName,
    int fileSizeBytes = 0,
    bool skipExisting = true,
    void Function(int processed, int total)? onProgress,
  }) => _rds.executeBulkImport(
    items: items,
    sourceEvent: sourceEvent,
    consentBasis: consentBasis,
    fileName: fileName,
    fileSizeBytes: fileSizeBytes,
    skipExisting: skipExisting,
    onProgress: onProgress,
  );
}

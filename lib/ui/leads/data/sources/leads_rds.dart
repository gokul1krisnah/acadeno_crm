import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:acadeno_crm/core/services/firestore_stream_cache.dart';
import 'package:acadeno_crm/core/services/offline_queue_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/lead_import_models.dart';
import '../model/lead_models.dart';
import 'lead_import_parser.dart';

/// Backend contract for Leads Management & Lead Assignment data operations.
abstract class LeadsBackend {
  String? get currentUserId;
  String get currentUserDisplayName;

  /// Verifies candidate import rows against Firestore `lead_phones` and `leads`.
  Future<List<LeadImportItem>> verifyImportAgainstFirestore(
    List<LeadImportItem> items,
  );

  /// Executes bulk import of validated leads using batched Firestore writes.
  Future<LeadImportSummary> executeBulkImport({
    required List<LeadImportItem> items,
    required String sourceEvent,
    required String consentBasis,
    required String fileName,
    int fileSizeBytes = 0,
    bool skipExisting = true,
    void Function(int processed, int total)? onProgress,
  });

  /// Streams all leads for authorized Admins / Managers.
  Stream<List<LeadRecord>> watchAllLeads();

  /// Streams active Sales Executives from the `users` collection.
  Stream<List<SalesExecutiveOption>> watchActiveExecutives();

  /// Streams assignments for a specific [dateKey] (`YYYY-MM-DD`) for Admins.
  Stream<List<LeadAssignmentModel>> watchAssignmentsForDate(String dateKey);

  /// Creates a new lead with backend duplicate phone validation.
  Future<LeadRecord> createLead({
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    String status = 'New',
    String notes = '',
    bool assignToSelfAsWalkIn = false,
  });

  /// Updates an existing lead's details according to role permissions.
  Future<LeadRecord> updateLead({
    required String leadId,
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    required String status,
    String? notes,
    String? course,
    String? batch,
  });

  /// Assigns (or reassigns) one or more leads to an active Sales Executive for [dateKey].
  Future<AssignmentBatchSummary> assignLeadsToExecutive({
    required List<String> leadIds,
    required String executiveUid,
    required String dateKey,
    required String dateLabel,
    bool allowReassign = false,
  });

  /// Deletes a lead and its phone index entry.
  Future<void> deleteLead(String leadId);

  /// Deletes multiple leads in batches.
  Future<int> deleteMultipleLeads(List<String> leadIds);

  /// Streams ONLY the currently authenticated Sales Executive's assigned leads
  /// for [dateKey] (defaults to Today). Never fetches all leads locally.
  Stream<List<ExecutiveLeadItem>> watchExecutiveTodayLeads({String? dateKey});

  /// Streams the currently authenticated Sales Executive's call log history.
  Stream<List<CallHistoryRecord>> watchExecutiveCallRecords();

  /// Fetches a single lead by ID, enforcing executive ownership permissions.
  Future<LeadRecord> getLeadById(String leadId);

  /// Records a mandatory call outcome and updates the lead + assignment status.
  Future<CallOutcomeResult> recordExecutiveCallOutcome({
    required String leadId,
    required String leadName,
    required String outcome,
    required String duration,
    required String notes,
    String? courseEnrolled,
    int? discountAmount,
    String? followUpTime,
    String? batch,
    int? feeAmount,
    int? amountPaid,
    String? paymentMode,
    String? receiptNumber,
    String? expectedBalanceDate,
  });

  /// Performs a backend 10-digit phone duplicate lookup via `lead_phones/{phone10}`.
  Future<({bool found, String message, String? owner, String? status})>
  lookupByPhone(String rawPhone);

  /// Atomically claims a 10-minute call lock on [leadId] (FR-3.1, RL-2).
  Future<({bool granted, String? lockedBy})> claimLeadForCall(String leadId);

  Future<void> releaseLeadLock(String leadId);

  /// Logs a WhatsApp approved template send to the lead's timeline and call_logs (FR-5.1, FR-5.2).
  Future<void> logWhatsAppSent({
    required String leadId,
    required String leadName,
    required String templateTitle,
  });

  /// Marks a lead as "Do Not Contact" (`optedOut = true`) per DPDP (PR-9.2).
  Future<void> markLeadOptedOut(String leadId, {bool optedOut = true});

  /// Anonymizes a lead's personal data per DPDP erasure request while keeping call stats (PR-9.3).
  Future<void> eraseLeadPersonalData(String leadId);

  /// Alerts Super Admin when an executive exceeds hourly rate limits (PR-2.5).
  Future<void> reportRateLimitExceeded({
    required String limitType,
    required int count,
  });
}

/// Remote Data Source delegating to [LeadsBackend] (defaults to [FirestoreLeadsBackend]).
class LeadsRds {
  final LeadsBackend _backend;

  LeadsRds({
    LeadsBackend? backend,
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _backend =
           backend ??
           FirestoreLeadsBackend(
             firestore: firestore,
             firebaseAuth: firebaseAuth,
           );

  LeadsBackend get backend => _backend;

  String? get currentUserId => _backend.currentUserId;

  String get currentUserDisplayName => _backend.currentUserDisplayName;

  Stream<List<LeadRecord>> watchAllLeads() => _backend.watchAllLeads();

  Stream<List<SalesExecutiveOption>> watchActiveExecutives() =>
      _backend.watchActiveExecutives();

  Stream<List<LeadAssignmentModel>> watchAssignmentsForDate(String dateKey) =>
      _backend.watchAssignmentsForDate(dateKey);

  Future<LeadRecord> createLead({
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    String status = 'New',
    String notes = '',
    bool assignToSelfAsWalkIn = false,
  }) => _backend.createLead(
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
    String? course,
    String? batch,
  }) => _backend.updateLead(
    leadId: leadId,
    name: name,
    phone: phone,
    collegeBranch: collegeBranch,
    source: source,
    status: status,
    notes: notes,
    course: course,
    batch: batch,
  );

  Future<void> deleteLead(String leadId) => _backend.deleteLead(leadId);

  Future<int> deleteMultipleLeads(List<String> leadIds) =>
      _backend.deleteMultipleLeads(leadIds);

  Future<AssignmentBatchSummary> assignLeadsToExecutive({
    required List<String> leadIds,
    required String executiveUid,
    required String dateKey,
    required String dateLabel,
    bool allowReassign = false,
  }) => _backend.assignLeadsToExecutive(
    leadIds: leadIds,
    executiveUid: executiveUid,
    dateKey: dateKey,
    dateLabel: dateLabel,
    allowReassign: allowReassign,
  );

  Future<List<LeadImportItem>> verifyImportAgainstFirestore(
    List<LeadImportItem> items,
  ) => _backend.verifyImportAgainstFirestore(items);

  Future<LeadImportSummary> executeBulkImport({
    required List<LeadImportItem> items,
    required String sourceEvent,
    required String consentBasis,
    required String fileName,
    int fileSizeBytes = 0,
    bool skipExisting = true,
    void Function(int processed, int total)? onProgress,
  }) => _backend.executeBulkImport(
    items: items,
    sourceEvent: sourceEvent,
    consentBasis: consentBasis,
    fileName: fileName,
    fileSizeBytes: fileSizeBytes,
    skipExisting: skipExisting,
    onProgress: onProgress,
  );

  Stream<List<ExecutiveLeadItem>> watchExecutiveTodayLeads({String? dateKey}) =>
      _backend.watchExecutiveTodayLeads(dateKey: dateKey);

  Stream<List<CallHistoryRecord>> watchExecutiveCallRecords() =>
      _backend.watchExecutiveCallRecords();

  Future<LeadRecord> getLeadById(String leadId) => _backend.getLeadById(leadId);

  Future<CallOutcomeResult> recordExecutiveCallOutcome({
    required String leadId,
    required String leadName,
    required String outcome,
    required String duration,
    required String notes,
    String? courseEnrolled,
    int? discountAmount,
    String? followUpTime,
    String? batch,
    int? feeAmount,
    int? amountPaid,
    String? paymentMode,
    String? receiptNumber,
    String? expectedBalanceDate,
  }) => _backend.recordExecutiveCallOutcome(
    leadId: leadId,
    leadName: leadName,
    outcome: outcome,
    duration: duration,
    notes: notes,
    courseEnrolled: courseEnrolled,
    discountAmount: discountAmount,
    followUpTime: followUpTime,
    batch: batch,
    feeAmount: feeAmount,
    amountPaid: amountPaid,
    paymentMode: paymentMode,
    receiptNumber: receiptNumber,
    expectedBalanceDate: expectedBalanceDate,
  );

  Future<({bool found, String message, String? owner, String? status})>
  lookupByPhone(String rawPhone) => _backend.lookupByPhone(rawPhone);

  Future<({bool granted, String? lockedBy})> claimLeadForCall(String leadId) =>
      _backend.claimLeadForCall(leadId);

  Future<void> releaseLeadLock(String leadId) =>
      _backend.releaseLeadLock(leadId);

  Future<void> logWhatsAppSent({
    required String leadId,
    required String leadName,
    required String templateTitle,
  }) => _backend.logWhatsAppSent(
    leadId: leadId,
    leadName: leadName,
    templateTitle: templateTitle,
  );

  Future<void> markLeadOptedOut(String leadId, {bool optedOut = true}) =>
      _backend.markLeadOptedOut(leadId, optedOut: optedOut);

  Future<void> eraseLeadPersonalData(String leadId) =>
      _backend.eraseLeadPersonalData(leadId);

  Future<void> reportRateLimitExceeded({
    required String limitType,
    required int count,
  }) => _backend.reportRateLimitExceeded(limitType: limitType, count: count);
}

// =============================================================================
// Production Cloud Firestore Implementation
// =============================================================================

class FirestoreLeadsBackend implements LeadsBackend {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  FirestoreLeadsBackend({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _leads =>
      _firestore.collection('leads');

  CollectionReference<Map<String, dynamic>> get _leadPhones =>
      _firestore.collection('lead_phones');

  CollectionReference<Map<String, dynamic>> get _assignments =>
      _firestore.collection('assignments');

  CollectionReference<Map<String, dynamic>> get _callLogs =>
      _firestore.collection('call_logs');

  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _firestore.collection('audit_log');

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  @override
  String get currentUserDisplayName {
    final user = _firebaseAuth.currentUser;
    final name = user?.displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return isAdminSession ? 'Super Admin' : 'Executive';
  }

  static const Set<String> _adminAndManagerRoles = {
    'admin',
    'super_admin',
    'manager',
    'team_lead',
    'operation manager',
    'operation_manager',
    'hr & operation manager',
    'hr_and_operation_manager',
  };

  static bool _isAdminOrManagerRole(String role) {
    final lower = role.trim().toLowerCase();
    return _adminAndManagerRoles.contains(lower) ||
        lower.contains('admin') ||
        lower.contains('manager') ||
        lower.contains('lead');
  }

  /// Verifies the currently authenticated user's profile and active status from `users/{uid}`.
  Future<({String uid, String name, String role, bool isActive})>
  _verifyCurrentActor({bool requireAdminOrManager = false}) async {
    final uid = currentUserId;
    final authUser = _firebaseAuth.currentUser;
    final authEmail = authUser?.email?.trim() ?? '';
    final fallbackName = authUser?.displayName?.trim().isNotEmpty == true
        ? authUser!.displayName!.trim()
        : (authEmail.isNotEmpty
              ? authEmail.split('@').first
              : (isAdminSession ? 'Super Admin' : 'Executive'));
    final fallbackRole = isAdminSession ? 'super_admin' : 'executive';

    if (uid == null || uid.trim().isEmpty) {
      if (isAdminSession) {
        return (
          uid: 'admin_session',
          name: 'Super Admin',
          role: 'super_admin',
          isActive: true,
        );
      }
      throw const LeadPermissionException(
        'You must be signed in to access CRM records.',
      );
    }

    // Immediately resolve offline actor without hanging on network
    if (!OfflineQueueService.instance.isOnline) {
      return (uid: uid, name: fallbackName, role: fallbackRole, isActive: true);
    }

    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await FirestoreStreamCache.instance
          .getDoc('users', uid, firestore: _firestore)
          .timeout(const Duration(milliseconds: 1000));
    } catch (_) {
      return (uid: uid, name: fallbackName, role: fallbackRole, isActive: true);
    }

    var data = doc.data();
    if (data == null) {
      final authUser = _firebaseAuth.currentUser;
      final authEmail = authUser?.email?.trim() ?? '';
      final fallbackName = authUser?.displayName?.trim().isNotEmpty == true
          ? authUser!.displayName!.trim()
          : (authEmail.isNotEmpty
                ? authEmail.split('@').first
                : (isAdminSession ? 'Super Admin' : 'Executive'));
      final fallbackRole = isAdminSession ? 'super_admin' : 'hr';
      data = {
        'email': authEmail,
        'name': fallbackName,
        'role': fallbackRole,
        'isActive': true,
      };
      try {
        await _users.doc(uid).set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    final isActive = data['isActive'] != false;
    if (!isActive) {
      throw const LeadPermissionException(
        'Your account has been deactivated. Access to CRM records is blocked.',
      );
    }

    final rawRole = (data['role'] ?? 'executive').toString().trim();
    final effectiveRole =
        isAdminSession && !_isAdminOrManagerRole(rawRole)
        ? 'super_admin'
        : rawRole;
    final rawName = (data['name'] ?? currentUserDisplayName).toString().trim();

    if (requireAdminOrManager &&
        !_isAdminOrManagerRole(effectiveRole)) {
      throw const LeadPermissionException(
        'Only authorized Admins and Managers can perform this action.',
      );
    }

    return (
      uid: uid,
      name: rawName.isEmpty ? currentUserDisplayName : rawName,
      role: effectiveRole,
      isActive: isActive,
    );
  }

  Future<void> _appendAudit({
    required String actorUid,
    required String actorName,
    required String action,
    required String target,
    required String category,
  }) async {
    try {
      await _auditLogs.add({
        'actorUid': actorUid,
        'actor': actorName,
        'action': action,
        'target': target,
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort audit logging if rules are not yet published
    }
  }

  @override
  Stream<List<LeadRecord>> watchAllLeads() async* {
    try {
      await _verifyCurrentActor(requireAdminOrManager: false);
    } catch (e) {
      debugPrint('[watchAllLeads] actor verification notice: $e');
    }
    yield* FirestoreStreamCache.instance
        .watchCollection('leads', firestore: _firestore)
        .handleError((err) {
          debugPrint('[watchAllLeads] snapshots notice: $err');
        })
        .map((snapshot) {
          final list = snapshot.docs.map(LeadRecord.fromFirestore).toList();
          list.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final cmp = bTime.compareTo(aTime);
            return cmp != 0 ? cmp : a.name.compareTo(b.name);
          });
          return list;
        });
  }

  @override
  Stream<List<SalesExecutiveOption>> watchActiveExecutives() {
    return FirestoreStreamCache.instance
        .watchCollection('users', firestore: _firestore)
        .handleError((e) {
          debugPrint('[watchActiveExecutives] notice: $e');
        })
        .map((snap) {
          final allActive = snap.docs
              .map((d) => SalesExecutiveOption.fromMap(d.id, d.data()))
              .where((u) => u.isActive)
              .toList();
          // HR is the actual caller user receiving lead assignments
          final hrUsers = allActive
              .where(
                (u) =>
                    u.role.toLowerCase() == 'hr' ||
                    u.role.toLowerCase() == 'executive' ||
                    u.role.toLowerCase().contains('hr'),
              )
              .toList();
          final nonAdmins = allActive
              .where((u) => !_isAdminOrManagerRole(u.role))
              .toList();
          final result = hrUsers.isNotEmpty
              ? hrUsers
              : (nonAdmins.isNotEmpty ? nonAdmins : allActive);
          result.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return result;
        });
  }

  @override
  Stream<List<LeadAssignmentModel>> watchAssignmentsForDate(String dateKey) {
    return FirestoreStreamCache.instance
        .watchQuery(
          'assignments:dateKey:$dateKey',
          () => _assignments.where('dateKey', isEqualTo: dateKey),
        )
        .handleError((e) {
          debugPrint('[watchAssignmentsForDate] notice: $e');
        })
        .map(
          (snap) => snap.docs.map(LeadAssignmentModel.fromFirestore).toList(),
        );
  }

  @override
  Future<LeadRecord> createLead({
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    String status = 'New',
    String notes = '',
    bool assignToSelfAsWalkIn = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Student name is required.');
    }
    final phoneError = LeadPhoneValidator.validate(phone);
    if (phoneError != null) {
      throw ArgumentError(phoneError);
    }
    final phone10 = LeadPhoneValidator.normalize10Digits(phone);
    final formattedPhone = LeadPhoneValidator.formatDisplayPhone(phone10);

    final actor = await _verifyCurrentActor(
      requireAdminOrManager: !assignToSelfAsWalkIn,
    );

    // 1. Pre-transaction backend query check against `leads` collection in case
    // pre-existing documents in Firestore were added before `lead_phones` index.
    final existingByNorm = await _leads
        .where('phoneNormalized', isEqualTo: phone10)
        .limit(1)
        .get();
    if (existingByNorm.docs.isNotEmpty) {
      final existing = LeadRecord.fromFirestore(existingByNorm.docs.first);
      throw DuplicateLeadException(
        phone10: phone10,
        existingLeadId: existing.id,
        existingLeadName: existing.name,
        existingOwnerName: existing.assignedToName,
      );
    }

    final existingByFormatted = await _leads
        .where('phone', isEqualTo: formattedPhone)
        .limit(1)
        .get();
    if (existingByFormatted.docs.isNotEmpty) {
      final existing = LeadRecord.fromFirestore(existingByFormatted.docs.first);
      throw DuplicateLeadException(
        phone10: phone10,
        existingLeadId: existing.id,
        existingLeadName: existing.name,
        existingOwnerName: existing.assignedToName,
      );
    }

    final existingByRaw = await _leads
        .where('phone', isEqualTo: phone10)
        .limit(1)
        .get();
    if (existingByRaw.docs.isNotEmpty) {
      final existing = LeadRecord.fromFirestore(existingByRaw.docs.first);
      throw DuplicateLeadException(
        phone10: phone10,
        existingLeadId: existing.id,
        existingLeadName: existing.name,
        existingOwnerName: existing.assignedToName,
      );
    }

    // 2. Atomic Firestore transaction on `lead_phones/{phone10}` + `leads/{id}`
    final newLeadRef = _leads.doc();
    final phoneIndexRef = _leadPhones.doc(phone10);
    final now = DateTime.now();
    final todayKey = LeadDateHelper.todayDateKey(now);
    final todayLabel = LeadDateHelper.dateLabel(now, now: now);

    final parsed = LeadRecord.parseCollegeBranch(collegeBranch);
    final effectiveStatus = assignToSelfAsWalkIn ? 'Assigned' : status;
    final assignedUid = assignToSelfAsWalkIn ? actor.uid : null;
    final assignedName = assignToSelfAsWalkIn ? actor.name : '—';

    final newRecord = LeadRecord(
      id: newLeadRef.id,
      name: trimmedName,
      phone: formattedPhone,
      phoneNormalized: phone10,
      collegeBranch: collegeBranch.trim().isEmpty ? '—' : collegeBranch.trim(),
      college: parsed.college,
      branch: parsed.branch,
      year: parsed.year,
      source: source.trim().isEmpty ? 'Direct visit' : source.trim(),
      status: effectiveStatus,
      lastContact: 'Never',
      assignedToUid: assignedUid,
      assignedToName: assignedName,
      assignedDateKey: assignToSelfAsWalkIn ? todayKey : null,
      assignedDateLabel: assignToSelfAsWalkIn ? todayLabel : null,
      assignedByUid: assignToSelfAsWalkIn ? actor.uid : null,
      assignedByName: assignToSelfAsWalkIn ? actor.name : null,
      assignedAt: assignToSelfAsWalkIn ? now : null,
      notes: notes.trim(),
      timeline: [
        if (assignToSelfAsWalkIn)
          '${LeadDateHelper.timelineStamp(now)} · Walk-in claimed by ${actor.name}',
        '${LeadDateHelper.timelineStamp(now)} · Registered via ${source.trim().isEmpty ? "Direct visit" : source.trim()} (Consent recorded)',
      ],
      createdByUid: actor.uid,
      createdByName: actor.name,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction((tx) async {
      final phoneSnap = await tx.get(phoneIndexRef);
      if (phoneSnap.exists) {
        final pData = phoneSnap.data() ?? const {};
        final existingLeadId = (pData['leadId'] ?? '').toString().trim();
        bool isStaleOrphan = existingLeadId.isEmpty;
        if (!isStaleOrphan) {
          final existingLeadSnap = await tx.get(_leads.doc(existingLeadId));
          isStaleOrphan = !existingLeadSnap.exists;
        }
        if (!isStaleOrphan) {
          throw DuplicateLeadException(
            phone10: phone10,
            existingLeadId: existingLeadId,
            existingLeadName: (pData['leadName'] ?? 'Existing lead').toString(),
            existingOwnerName: (pData['ownerName'] ?? '—').toString(),
          );
        }
      }

      tx.set(newLeadRef, {
        ...newRecord.toFirestoreMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (assignToSelfAsWalkIn) 'assignedAt': FieldValue.serverTimestamp(),
      });

      tx.set(phoneIndexRef, {
        'phoneNormalized': phone10,
        'leadId': newLeadRef.id,
        'leadName': trimmedName,
        'ownerUid': assignedUid,
        'ownerName': assignedName,
        'status': effectiveStatus,
        'createdByUid': actor.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (assignToSelfAsWalkIn) {
        final assignId = LeadAssignmentModel.docId(newLeadRef.id, todayKey);
        final assignRef = _assignments.doc(assignId);
        final assignment = LeadAssignmentModel(
          id: assignId,
          leadId: newLeadRef.id,
          executiveUid: actor.uid,
          executiveName: actor.name,
          dateKey: todayKey,
          dateLabel: todayLabel,
          assignedByUid: actor.uid,
          assignedByName: actor.name,
          assignedAt: now,
          leadName: trimmedName,
          leadPhone: formattedPhone,
          collegeBranch: newRecord.collegeBranch,
          source: newRecord.source,
          leadStatus: 'Assigned',
        );
        tx.set(assignRef, {
          ...assignment.toFirestoreMap(),
          'assignedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    await _appendAudit(
      actorUid: actor.uid,
      actorName: actor.name,
      action: assignToSelfAsWalkIn
          ? 'Added walk-in lead (${newRecord.source})'
          : 'Created lead (${newRecord.source})',
      target: '$trimmedName · $formattedPhone',
      category: 'lead_create',
    );

    return newRecord;
  }

  @override
  Future<LeadRecord> updateLead({
    required String leadId,
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    required String status,
    String? notes,
    String? course,
    String? batch,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Student name is required.');
    }
    final phoneError = LeadPhoneValidator.validate(phone);
    if (phoneError != null) {
      throw ArgumentError(phoneError);
    }
    final newPhone10 = LeadPhoneValidator.normalize10Digits(phone);
    final formattedPhone = LeadPhoneValidator.formatDisplayPhone(newPhone10);

    final actor = await _verifyCurrentActor();
    final isAdminOrManager = _isAdminOrManagerRole(actor.role);

    final leadRef = _leads.doc(leadId);
    late LeadRecord updatedRecord;

    await _firestore.runTransaction((tx) async {
      final leadSnap = await tx.get(leadRef);
      if (!leadSnap.exists) {
        throw StateError('Lead $leadId no longer exists.');
      }
      final current = LeadRecord.fromFirestore(leadSnap);

      if (!isAdminOrManager && current.assignedToUid != actor.uid) {
        throw const LeadPermissionException(
          'You do not have permission to edit a lead assigned to another executive.',
        );
      }

      final oldPhone10 = current.phoneNormalized;
      if (newPhone10 != oldPhone10) {
        if (!isAdminOrManager) {
          throw const LeadPermissionException(
            'Only Admins and Managers can change a lead phone number.',
          );
        }
        final newPhoneRef = _leadPhones.doc(newPhone10);
        final newPhoneSnap = await tx.get(newPhoneRef);
        if (newPhoneSnap.exists) {
          final pData = newPhoneSnap.data() ?? const {};
          final existingId = (pData['leadId'] ?? '').toString().trim();
          if (existingId.isNotEmpty && existingId != leadId) {
            final existingLeadSnap = await tx.get(_leads.doc(existingId));
            if (existingLeadSnap.exists) {
              throw DuplicateLeadException(
                phone10: newPhone10,
                existingLeadId: existingId,
                existingLeadName: (pData['leadName'] ?? 'Existing lead')
                    .toString(),
                existingOwnerName: (pData['ownerName'] ?? '—').toString(),
              );
            }
          }
        }
        if (oldPhone10.isNotEmpty) {
          tx.delete(_leadPhones.doc(oldPhone10));
        }
        tx.set(newPhoneRef, {
          'phoneNormalized': newPhone10,
          'leadId': leadId,
          'leadName': trimmedName,
          'ownerUid': current.assignedToUid,
          'ownerName': current.assignedToName,
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (oldPhone10.isNotEmpty) {
        tx.set(_leadPhones.doc(oldPhone10), {
          'phoneNormalized': oldPhone10,
          'leadId': leadId,
          'leadName': trimmedName,
          'ownerUid': current.assignedToUid,
          'ownerName': current.assignedToName,
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final parsed = LeadRecord.parseCollegeBranch(collegeBranch);
      updatedRecord = current.copyWith(
        name: isAdminOrManager ? trimmedName : current.name,
        phone: isAdminOrManager ? formattedPhone : current.phone,
        phoneNormalized: isAdminOrManager
            ? newPhone10
            : current.phoneNormalized,
        collegeBranch: isAdminOrManager
            ? collegeBranch.trim()
            : current.collegeBranch,
        college: isAdminOrManager ? parsed.college : current.college,
        branch: isAdminOrManager ? parsed.branch : current.branch,
        year: isAdminOrManager ? parsed.year : current.year,
        source: isAdminOrManager ? source.trim() : current.source,
        status: status.trim(),
        notes: notes ?? current.notes,
        course: course ?? current.course,
        batch: batch ?? current.batch,
        updatedAt: DateTime.now(),
      );

      tx.update(leadRef, {
        ...updatedRecord.toFirestoreMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _appendAudit(
      actorUid: actor.uid,
      actorName: actor.name,
      action: 'Updated lead details',
      target: '${updatedRecord.name} (${updatedRecord.phone})',
      category: 'lead_update',
    );

    return updatedRecord;
  }

  @override
  Future<void> deleteLead(String leadId) async {
    final cleanId = leadId.trim();
    if (cleanId.isEmpty) return;
    final actor = await _verifyCurrentActor(requireAdminOrManager: true);
    final leadDoc = await _leads.doc(cleanId).get();
    final data = leadDoc.data() ?? {};
    final phoneNormalized = (data['phoneNormalized'] ?? '').toString().trim();
    final leadName = (data['name'] ?? 'Lead').toString();
    final leadPhone = (data['phone'] ?? '').toString();
    final fallbackPhone10 = LeadPhoneValidator.normalize10Digits(leadPhone);

    final phonesToDelete = <String>{
      if (phoneNormalized.isNotEmpty) phoneNormalized,
      if (fallbackPhone10.length == 10) fallbackPhone10,
    };

    final byLeadIdPhones = await _leadPhones
        .where('leadId', isEqualTo: cleanId)
        .get();
    for (final doc in byLeadIdPhones.docs) {
      phonesToDelete.add(doc.id);
    }

    final byLeadIdAssignments = await _assignments
        .where('leadId', isEqualTo: cleanId)
        .get();

    final batch = _firestore.batch();
    batch.delete(_leads.doc(cleanId));
    for (final p in phonesToDelete) {
      batch.delete(_leadPhones.doc(p));
    }
    for (final assignDoc in byLeadIdAssignments.docs) {
      batch.delete(assignDoc.reference);
    }
    await batch.commit();

    await _appendAudit(
      actorUid: actor.uid,
      actorName: actor.name,
      action: 'Deleted lead',
      target: '$leadName ($leadPhone)',
      category: 'lead_deletion',
    );
  }

  @override
  Future<int> deleteMultipleLeads(List<String> leadIds) async {
    final cleanIds =
        leadIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (cleanIds.isEmpty) return 0;
    final actor = await _verifyCurrentActor(requireAdminOrManager: true);

    int deletedCount = 0;
    for (var i = 0; i < cleanIds.length; i += 100) {
      final chunk = cleanIds.sublist(i, math.min(i + 100, cleanIds.length));

      // Read lead docs to gather phone numbers for `lead_phones` index cleanup
      final leadSnaps = await Future.wait(
        chunk.map((id) => _leads.doc(id).get()),
      );

      final phonesToDelete = <String>{};
      for (final snap in leadSnaps) {
        if (!snap.exists) continue;
        final data = snap.data() ?? const {};
        final pNorm = (data['phoneNormalized'] ?? '').toString().trim();
        final rawPhone = (data['phone'] ?? '').toString();
        final fallback10 = LeadPhoneValidator.normalize10Digits(rawPhone);
        if (pNorm.isNotEmpty) phonesToDelete.add(pNorm);
        if (fallback10.length == 10) phonesToDelete.add(fallback10);
      }

      // Also clean up any lead_phones and lead_assignments referencing these leadIds (in chunks of 30 for whereIn)
      final assignmentRefs = <DocumentReference<Map<String, dynamic>>>[];
      for (var j = 0; j < chunk.length; j += 30) {
        final subChunk = chunk.sublist(j, math.min(j + 30, chunk.length));
        final phoneQuery = await _leadPhones
            .where('leadId', whereIn: subChunk)
            .get();
        for (final doc in phoneQuery.docs) {
          phonesToDelete.add(doc.id);
        }
        final assignQuery = await _assignments
            .where('leadId', whereIn: subChunk)
            .get();
        for (final doc in assignQuery.docs) {
          assignmentRefs.add(doc.reference);
        }
      }

      final ops = <void Function(WriteBatch)>[
        for (final id in chunk) (b) => b.delete(_leads.doc(id)),
        for (final p in phonesToDelete) (b) => b.delete(_leadPhones.doc(p)),
        for (final ref in assignmentRefs) (b) => b.delete(ref),
      ];

      for (var k = 0; k < ops.length; k += 400) {
        final batch = _firestore.batch();
        final slice = ops.sublist(k, math.min(k + 400, ops.length));
        for (final op in slice) {
          op(batch);
        }
        await batch.commit();
      }
      deletedCount += chunk.length;
    }

    await _appendAudit(
      actorUid: actor.uid,
      actorName: actor.name,
      action: 'Deleted multiple leads',
      target: '$deletedCount leads',
      category: 'lead_deletion',
    );

    return deletedCount;
  }

  @override
  Future<AssignmentBatchSummary> assignLeadsToExecutive({
    required List<String> leadIds,
    required String executiveUid,
    required String dateKey,
    required String dateLabel,
    bool allowReassign = false,
  }) async {
    final cleanIds = leadIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (cleanIds.isEmpty) {
      throw const AssignmentConflictException(
        'Select at least one lead to assign.',
      );
    }
    if (executiveUid.trim().isEmpty) {
      throw const AssignmentConflictException(
        'Select an active Sales Executive.',
      );
    }
    if (dateKey.trim().isEmpty) {
      throw const AssignmentConflictException('Select an assignment date.');
    }

    // 1. Verify caller is an authorized Admin or Manager
    final actor = await _verifyCurrentActor(requireAdminOrManager: true);

    // 2. Verify target Sales Executive exists and is active in `users/{executiveUid}`
    final execSnap = await _users.doc(executiveUid.trim()).get();
    final execData = execSnap.data();
    if (!execSnap.exists || execData == null) {
      throw const AssignmentConflictException(
        'Selected Sales Executive does not exist in users collection.',
      );
    }
    if (execData['isActive'] == false) {
      final inactiveName = (execData['name'] ?? 'Executive').toString();
      throw AssignmentConflictException(
        'Cannot assign leads to $inactiveName because their account is inactive.',
      );
    }
    final executive = SalesExecutiveOption.fromMap(execSnap.id, execData);
    final now = DateTime.now();

    final createdAssignments = <LeadAssignmentModel>[];
    int newlyAssignedCount = 0;
    int reassignedCount = 0;

    // 3. Atomic transaction preventing duplicate/conflicting assignments
    await _firestore.runTransaction((tx) async {
      // Firestore requires all reads before writes in a transaction.
      final leadSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final assignSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final leadId in cleanIds) {
        final leadRef = _leads.doc(leadId);
        final assignId = LeadAssignmentModel.docId(leadId, dateKey);
        final assignRef = _assignments.doc(assignId);

        leadSnaps[leadId] = await tx.get(leadRef);
        assignSnaps[leadId] = await tx.get(assignRef);
      }

      for (final leadId in cleanIds) {
        final leadSnap = leadSnaps[leadId]!;
        if (!leadSnap.exists) {
          throw AssignmentConflictException(
            'Lead $leadId was not found in Firestore.',
          );
        }
        final lead = LeadRecord.fromFirestore(leadSnap);

        if (lead.status == 'Converted' && !allowReassign) {
          throw AssignmentConflictException(
            '${lead.name} is already Converted and cannot be reassigned without override.',
          );
        }

        final assignId = LeadAssignmentModel.docId(leadId, dateKey);
        final assignRef = _assignments.doc(assignId);
        final existingAssignSnap = assignSnaps[leadId]!;

        String? prevExecUid;
        String? prevExecName;
        bool isReassignment = false;

        if (existingAssignSnap.exists) {
          final existingAssign = LeadAssignmentModel.fromFirestore(
            existingAssignSnap,
          );
          if (existingAssign.executiveUid == executive.uid) {
            // Already assigned to this same executive for this date: allow updating smoothly
            prevExecUid = existingAssign.executiveUid;
            prevExecName = existingAssign.executiveName;
            isReassignment = false;
          } else if (existingAssign.executiveUid != executive.uid && !allowReassign) {
            throw AssignmentConflictException(
              '${lead.name} is already assigned to ${existingAssign.executiveName} for $dateLabel. Confirm reassignment to proceed.',
            );
          } else {
            prevExecUid = existingAssign.executiveUid;
            prevExecName = existingAssign.executiveName;
            isReassignment = existingAssign.executiveUid != executive.uid;
          }
        } else if (lead.assignedDateKey == dateKey &&
            lead.assignedToUid != null &&
            lead.assignedToUid!.isNotEmpty) {
          if (lead.assignedToUid == executive.uid) {
            // Already assigned to this same executive for this date: allow updating smoothly
            prevExecUid = lead.assignedToUid;
            prevExecName = lead.assignedToName;
            isReassignment = false;
          } else if (lead.assignedToUid != executive.uid && !allowReassign) {
            throw AssignmentConflictException(
              '${lead.name} is already assigned to ${lead.assignedToName} for $dateLabel. Confirm reassignment to proceed.',
            );
          } else {
            prevExecUid = lead.assignedToUid;
            prevExecName = lead.assignedToName;
            isReassignment = lead.assignedToUid != executive.uid;
          }
        }

        if (isReassignment) {
          reassignedCount++;
        } else {
          newlyAssignedCount++;
        }

        final nextLeadStatus = (lead.status == 'New' || lead.status.isEmpty)
            ? 'Assigned'
            : lead.status;

        final assignmentModel = LeadAssignmentModel(
          id: assignId,
          leadId: lead.id,
          executiveUid: executive.uid,
          executiveName: executive.name,
          executiveEmail: executive.email,
          dateKey: dateKey,
          dateLabel: dateLabel,
          assignedByUid: actor.uid,
          assignedByName: actor.name,
          assignedAt: now,
          previousExecutiveUid: prevExecUid,
          previousExecutiveName: prevExecName,
          reassignedAt: isReassignment ? now : null,
          status: isReassignment ? 'reassigned' : 'assigned',
          isDone: false,
          leadName: lead.name,
          leadPhone: lead.phone,
          collegeBranch: lead.collegeBranch,
          source: lead.source,
          leadStatus: nextLeadStatus,
        );

        tx.set(assignRef, {
          ...assignmentModel.toFirestoreMap(),
          'assignedAt': FieldValue.serverTimestamp(),
          if (isReassignment) 'reassignedAt': FieldValue.serverTimestamp(),
        });

        // Persist the concrete date only ("11 Nov"), never "Today"/"Tomorrow".
        final concreteDate = dateLabel.contains(', ')
            ? dateLabel.split(', ').last
            : dateKey;
        final timelineEntry = isReassignment
            ? '${LeadDateHelper.timelineStamp()} · Reassigned from ${prevExecName ?? "previous executive"} to ${executive.name} by ${actor.name} (For $concreteDate)'
            : '${LeadDateHelper.timelineStamp()} · Assigned to ${executive.name} by ${actor.name} (For $concreteDate)';

        final updatedTimeline = <String>[timelineEntry, ...lead.timeline];

        final effectiveStatus = (nextLeadStatus == 'overdue' || nextLeadStatus == 'New')
            ? 'Assigned'
            : nextLeadStatus;
        final formattedFollowUp = '$dateLabel · 10:00 AM';

        tx.update(_leads.doc(lead.id), {
          'assignedToUid': executive.uid,
          'assignedToName': executive.name,
          'assignedTo': executive.name,
          'assignedDateKey': dateKey,
          'assignedDateLabel': dateLabel,
          'followUpTime': formattedFollowUp,
          'isOverdue': false,
          'assignedByUid': actor.uid,
          'assignedByName': actor.name,
          'assignedAt': FieldValue.serverTimestamp(),
          'status': effectiveStatus,
          'isDone': false,
          'timeline': updatedTimeline,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (lead.phoneNormalized.length == 10) {
          tx.set(_leadPhones.doc(lead.phoneNormalized), {
            'phoneNormalized': lead.phoneNormalized,
            'leadId': lead.id,
            'leadName': lead.name,
            'ownerUid': executive.uid,
            'ownerName': executive.name,
            'status': nextLeadStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        createdAssignments.add(assignmentModel);
      }
    });

    final targetNames = createdAssignments.map((a) => a.leadName).join(', ');
    final leadCount = createdAssignments.length;
    final leadNamesList = createdAssignments.map((a) => a.leadName).toList();
    final leadNamesPreview = leadNamesList.take(3).join(', ');
    final leadNamesSuffix = leadNamesList.length > 3
        ? ' +${leadNamesList.length - 3} more'
        : '';
    final alertTitle = reassignedCount > 0 && newlyAssignedCount > 0
        ? '$newlyAssignedCount New & $reassignedCount Reassigned Leads'
        : reassignedCount > 0
        ? '$reassignedCount ${reassignedCount == 1 ? "Lead" : "Leads"} Reassigned to You'
        : '$leadCount ${leadCount == 1 ? "Lead" : "Leads"} Assigned for $dateLabel';
    final alertSubtitle =
        'Assigned by ${actor.name} · ($leadNamesPreview$leadNamesSuffix)';

    try {
      final alertDoc = _firestore.collection('alerts').doc();
      await alertDoc.set({
        'id': alertDoc.id,
        'recipientUid': executive.uid,
        'recipientName': executive.name,
        'title': alertTitle,
        'subtitle': alertSubtitle,
        'category': 'assignment',
        'leadCount': leadCount,
        'leadIds': cleanIds,
        'leadNames': leadNamesList,
        'assignedByUid': actor.uid,
        'assignedByName': actor.name,
        'dateKey': dateKey,
        'dateLabel': dateLabel,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final execFcmToken = (execData['fcmToken'] ?? '').toString();
      await _firestore.collection('notification_queue').add({
        'recipientUid': executive.uid,
        'recipientName': executive.name,
        'recipientEmail': executive.email,
        'fcmToken': execFcmToken.isNotEmpty ? execFcmToken : null,
        'title': alertTitle,
        'body': alertSubtitle,
        'data': {
          'type': 'lead_assigned',
          'dateKey': dateKey,
          'tabIndex': '0',
          'leadCount': '$leadCount',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Direct Vercel Push Dispatch for Android out-of-app delivery
      if (execFcmToken.isNotEmpty) {
        try {
          http
              .post(
                Uri.parse('/api/send-push'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'token': execFcmToken,
                  'title': alertTitle,
                  'body': alertSubtitle,
                  'data': {
                    'type': 'lead_assigned',
                    'dateKey': dateKey,
                    'tabIndex': '0',
                    'leadCount': '$leadCount',
                  },
                }),
              )
              .timeout(const Duration(seconds: 4))
              .ignore();
        } catch (_) {}
      }
    } catch (_) {}
    await _appendAudit(
      actorUid: actor.uid,
      actorName: actor.name,
      action: reassignedCount > 0
          ? 'Assigned $newlyAssignedCount & reassigned $reassignedCount leads to ${executive.name} ($dateLabel)'
          : 'Assigned ${createdAssignments.length} leads to ${executive.name} ($dateLabel)',
      target: targetNames,
      category: 'assignment',
    );

    return AssignmentBatchSummary(
      assignments: createdAssignments,
      newlyAssignedCount: newlyAssignedCount,
      reassignedCount: reassignedCount,
      executiveUid: executive.uid,
      executiveName: executive.name,
      dateKey: dateKey,
      dateLabel: dateLabel,
    );
  }

  @override
  Stream<List<ExecutiveLeadItem>> watchExecutiveTodayLeads({
    String? dateKey,
  }) async* {
    // 1. Identify currently authenticated user's Firebase UID & verify active profile
    final actor = await _verifyCurrentActor(requireAdminOrManager: false);
    final effectiveDateKey = dateKey ?? LeadDateHelper.todayDateKey();
    final todayKey = LeadDateHelper.todayDateKey();

    // 2. Query ALL leads assigned to this executive in real-time from the authoritative leads collection
    yield* FirestoreStreamCache.instance
        .watchQuery(
          'leads:assignedToUid:${actor.uid}',
          () => _leads.where('assignedToUid', isEqualTo: actor.uid),
        )
        .map((snap) {
          final items = <ExecutiveLeadItem>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final isOptedOut =
                data['optedOut'] == true ||
                (data['status'] ?? '').toString().toLowerCase() == 'opted out';
            if (isOptedOut) continue;

            final aDateKey = (data['assignedDateKey'] ?? '').toString().trim();
            final aDateLabel =
                (data['assignedDateLabel'] ?? '').toString().toLowerCase();

            bool isForTargetDate = false;
            if (aDateKey.isNotEmpty) {
              isForTargetDate = (aDateKey == effectiveDateKey);
            } else if (aDateLabel.contains('today') &&
                effectiveDateKey == todayKey) {
              isForTargetDate = true;
            } else if (effectiveDateKey == todayKey) {
              // If no explicit date key was specified, check assignedAt or active status
              final ts = data['assignedAt'] ?? data['createdAt'];
              if (ts is Timestamp) {
                final d = ts.toDate();
                if (LeadDateHelper.dateKey(d) == todayKey) {
                  isForTargetDate = true;
                }
              } else {
                final s = (data['status'] ?? '').toString().toLowerCase();
                if (s == 'assigned' || s == 'new') {
                  isForTargetDate = true;
                }
              }
            }

            if (isForTargetDate) {
              final lead = LeadRecord.fromFirestore(doc);
              items.add(lead.toExecutiveLeadItem());
            }
          }
          return items;
        });
  }

  @override
  Stream<List<CallHistoryRecord>> watchExecutiveCallRecords() async* {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      yield const <CallHistoryRecord>[];
      return;
    }
    yield* FirestoreStreamCache.instance
        .watchQuery(
          'call_logs:executiveUid:$uid',
          () => _callLogs.where('executiveUid', isEqualTo: uid),
        )
        .map((
      snap,
    ) {
      final records = snap.docs
          .map((d) => CallHistoryRecord.fromMap(d.id, d.data()))
          .toList();

      // Merge locally queued calls so the executive sees them in My Record immediately (RL-5, RL-6)
      final queued = OfflineQueueService.instance.getQueuedCalls();
      for (final q in queued) {
        if (!records.any((r) => r.id == q.clientId)) {
          records.insert(
            0,
            CallHistoryRecord(
              id: q.clientId,
              leadName: q.leadName,
              collegeInfo: '—',
              campaign: 'Direct visit',
              outcome: q.outcome,
              duration: q.duration,
              timestamp: 'Today · Pending sync',
              notes: q.notes,
            ),
          );
        }
      }

      records.sort((a, b) => b.id.compareTo(a.id));
      return records;
    });
  }

  @override
  Future<LeadRecord> getLeadById(String leadId) async {
    final actor = await _verifyCurrentActor();
    final isAdminOrManager = _isAdminOrManagerRole(actor.role);
    final doc = await _leads.doc(leadId).get();
    if (!doc.exists || doc.data() == null) {
      throw StateError('Lead $leadId not found.');
    }
    final lead = LeadRecord.fromFirestore(doc);
    if (!isAdminOrManager && lead.assignedToUid != actor.uid) {
      throw const LeadPermissionException(
        'Access denied: Sales Executives can only access leads assigned to them.',
      );
    }
    return lead;
  }

  @override
  Future<CallOutcomeResult> recordExecutiveCallOutcome({
    required String leadId,
    required String leadName,
    required String outcome,
    required String duration,
    required String notes,
    String? courseEnrolled,
    int? discountAmount,
    String? followUpTime,
    String? batch,
    int? feeAmount,
    int? amountPaid,
    String? paymentMode,
    String? receiptNumber,
    String? expectedBalanceDate,
  }) async {
    final actor = await _verifyCurrentActor();
    final todayKey = LeadDateHelper.todayDateKey();
    String collegeInfo = '—';
    String campaign = 'Direct visit';

    final leadRef = _leads.doc(leadId);
    final assignId = LeadAssignmentModel.docId(leadId, todayKey);
    final assignRef = _assignments.doc(assignId);

    final remainingBalance = math.max(
      0,
      (feeAmount ?? 0) - (discountAmount ?? 0) - (amountPaid ?? 0),
    );
    final hasBalanceFollowUp =
        outcome == 'Converted' &&
        remainingBalance > 0 &&
        expectedBalanceDate != null &&
        expectedBalanceDate.trim().isNotEmpty;

    final isFollowUpPending =
        outcome == 'Follow-up' ||
        outcome == 'Callback' ||
        outcome == 'Interested' ||
        outcome == 'No answer' ||
        hasBalanceFollowUp;

    final effectiveFollowUpInput = hasBalanceFollowUp
        ? expectedBalanceDate
        : followUpTime;

    // Persist a concrete date/time (never "Today"/"Tomorrow") so follow-ups
    // can't drift as days pass. Only outcomes that need a follow-up get one.
    String? resolvedFollowUp = isFollowUpPending
        ? LeadDateHelper.resolveFollowUpLabel(
            effectiveFollowUpInput,
            outcome: hasBalanceFollowUp ? 'Follow-up' : outcome,
          )
        : null;

    final clientId =
        'call_${leadId}_${DateTime.now().millisecondsSinceEpoch}_${leadId.hashCode.abs()}';

    // 1. If offline, IMMEDIATELY enqueue to persistent Hive queue & apply local cache writes (RL-5, RL-6)
    if (!OfflineQueueService.instance.isOnline) {
      await OfflineQueueService.instance.enqueueOutcome(
        leadId: leadId,
        leadName: leadName,
        outcome: outcome,
        duration: duration,
        notes: notes,
        courseEnrolled: courseEnrolled,
        discountAmount: discountAmount,
        executiveUid: actor.uid,
        executiveName: actor.name,
      );

      // Write to local Firestore offline cache so UI updates immediately
      try {
        await leadRef.set({
          'status': outcome,
          'lastContact': 'Today',
          'lastContactAt': FieldValue.serverTimestamp(),
          'lastCalledAt': FieldValue.serverTimestamp(),
          'isDone': !isFollowUpPending,
          'isLocked': false,
          'lockedByUid': null,
          'lockedByName': null,
          'lockedAt': null,
          'lockedMessage': null,
          'followUpTime': ?resolvedFollowUp,
          if (courseEnrolled != null && courseEnrolled.trim().isNotEmpty)
            'course': courseEnrolled.trim(),
          if (feeAmount != null && feeAmount > 0) 'fee': '₹$feeAmount',
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await assignRef.set({
          'isDone': true,
          'lastOutcome': outcome,
          'leadStatus': outcome,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      final needsApproval =
          outcome == 'Converted' && (discountAmount ?? 0) > 500;
      return CallOutcomeResult(
        collegeInfo: collegeInfo,
        needsDiscountApproval: needsApproval,
      );
    }

    // 2. If online, update Firestore with strict timeouts, falling back to offline queue on failure
    try {
      final leadSnap = await leadRef.get().timeout(
        const Duration(milliseconds: 1500),
      );
      if (leadSnap.exists && leadSnap.data() != null) {
        final lead = LeadRecord.fromFirestore(leadSnap);
        collegeInfo = lead.collegeBranch;
        campaign = lead.source;

        final int nextNoAnswerCount = outcome == 'No answer'
            ? (lead.noAnswerCount + 1)
            : 0;
        final bool reachedMaxNoAnswer =
            outcome == 'No answer' && nextNoAnswerCount >= 3;

        String nextStatus = lead.status;
        if (lead.status != 'Converted') {
          if (outcome == 'No answer' && lead.status == 'Interested') {
            nextStatus = 'Interested';
          } else if (reachedMaxNoAnswer) {
            // FR-3.6: After 3 unanswered retries within working hours, mark Unreachable
            nextStatus = 'Unreachable';
          } else {
            nextStatus = outcome;
          }
        }

        bool effectiveIsDone = !isFollowUpPending;
        if (reachedMaxNoAnswer) {
          effectiveIsDone = true;
          resolvedFollowUp = null;
        }

        final nextTimeline = <String>[
          if (reachedMaxNoAnswer)
            '${LeadDateHelper.timelineStamp()} · Marked Unreachable after 3 No-answer attempts',
          if (hasBalanceFollowUp)
            '${LeadDateHelper.timelineStamp()} · Pending balance ₹$remainingBalance follow-up scheduled for $resolvedFollowUp',
          '${LeadDateHelper.timelineStamp()} · $outcome logged by ${actor.name}${notes.trim().isNotEmpty ? " ($notes)" : ""}',
          ...lead.timeline,
        ];

        await leadRef
            .update({
              'status': nextStatus,
              'lastContact': 'Today',
              'lastContactAt': FieldValue.serverTimestamp(),
              'lastCalledAt': FieldValue.serverTimestamp(),
              'isDone': effectiveIsDone,
              'followUpDone': effectiveIsDone,
              'isLocked': false,
              'lockedByUid': null,
              'lockedByName': null,
              'lockedAt': null,
              'lockedMessage': null,
              'noAnswerCount': nextNoAnswerCount,
              'followUpTime': resolvedFollowUp ?? '',
              'isOverdue': false,
              if (courseEnrolled != null && courseEnrolled.trim().isNotEmpty)
                'course': courseEnrolled.trim(),
              if (feeAmount != null && feeAmount > 0) 'fee': '₹$feeAmount',
              if (batch != null && batch.trim().isNotEmpty)
                'batch': batch.trim(),
              'discountAmount': ?discountAmount,
              'amountPaid': ?amountPaid,
              if (paymentMode != null && paymentMode.trim().isNotEmpty)
                'paymentMode': paymentMode.trim(),
              if (receiptNumber != null && receiptNumber.trim().isNotEmpty)
                'receiptNumber': receiptNumber.trim(),
              if (expectedBalanceDate != null &&
                  expectedBalanceDate.trim().isNotEmpty)
                'expectedBalanceDate': expectedBalanceDate.trim(),
              if (notes.trim().isNotEmpty) 'notes': notes.trim(),
              'timeline': nextTimeline,
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(milliseconds: 1500));

        final assignSnap = await assignRef.get().timeout(
          const Duration(milliseconds: 1500),
        );
        if (assignSnap.exists) {
          await assignRef
              .update({
                'isDone': true,
                'lastOutcome': outcome,
                'leadStatus': nextStatus,
                'updatedAt': FieldValue.serverTimestamp(),
              })
              .timeout(const Duration(milliseconds: 1500));
        }
      }
    } catch (_) {
      // Partial failure or timeout: queue locally
    }

    // FR-5.4: Discount > ₹500 triggers immediate approval alert to Manager & Super Admin
    final needsApproval = outcome == 'Converted' && (discountAmount ?? 0) > 500;
    if (needsApproval) {
      try {
        await _firestore.collection('alerts').add({
          'title': 'Discount Approval Required',
          'message':
              '${actor.name} logged a ₹$discountAmount discount for $leadName (${courseEnrolled ?? "Program"}). Approval needed.',
          'type': 'discount_approval',
          'category': 'discount',
          'leadId': leadId,
          'leadName': leadName,
          'executiveUid': actor.uid,
          'executiveName': actor.name,
          'discountAmount': discountAmount,
          'status': 'pending',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    try {
      await _callLogs
          .doc(clientId)
          .set({
            'leadId': leadId,
            'leadName': leadName,
            'executiveUid': actor.uid,
            'executiveName': actor.name,
            'collegeInfo': collegeInfo,
            'campaign': campaign,
            'outcome': outcome,
            'duration': duration.trim().isEmpty ? '0s' : duration.trim(),
            'notes': notes.trim().isEmpty
                ? 'Logged $outcome outcome'
                : notes.trim(),
            'courseEnrolled': ?courseEnrolled,
            'discountAmount': ?discountAmount,
            'batch': ?batch,
            'feeAmount': ?feeAmount,
            'amountPaid': ?amountPaid,
            'paymentMode': ?paymentMode,
            'receiptNumber': ?receiptNumber,
            'expectedBalanceDate': ?expectedBalanceDate,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      await OfflineQueueService.instance.enqueueOutcome(
        leadId: leadId,
        leadName: leadName,
        outcome: outcome,
        duration: duration,
        notes: notes,
        courseEnrolled: courseEnrolled,
        discountAmount: discountAmount,
        executiveUid: actor.uid,
        executiveName: actor.name,
      );
    }

    return CallOutcomeResult(
      collegeInfo: collegeInfo,
      needsDiscountApproval: needsApproval,
    );
  }

  @override
  Future<({bool granted, String? lockedBy})> claimLeadForCall(
    String leadId,
  ) async {
    if (leadId.trim().isEmpty || !OfflineQueueService.instance.isOnline) {
      return (granted: true, lockedBy: null);
    }
    try {
      final actor = await _verifyCurrentActor();
      final leadRef = _leads.doc(leadId);
      return await _firestore
          .runTransaction<({bool granted, String? lockedBy})>((tx) async {
            final snap = await tx.get(leadRef);
            if (!snap.exists || snap.data() == null) {
              return (granted: true, lockedBy: null);
            }
            final lead = LeadRecord.fromFirestore(snap);
            if (lead.isActivelyLocked &&
                lead.lockedByUid != null &&
                lead.lockedByUid != actor.uid) {
              final locker = (lead.lockedByName ?? '').trim().isNotEmpty
                  ? lead.lockedByName!.trim()
                  : 'Another executive';
              return (granted: false, lockedBy: locker);
            }
            tx.update(leadRef, {
              'isLocked': true,
              'lockedByUid': actor.uid,
              'lockedByName': actor.name,
              'lockedMessage': '${actor.name} is calling now',
              'lockedAt': FieldValue.serverTimestamp(),
            });
            return (granted: true, lockedBy: null);
          })
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      return (granted: true, lockedBy: null);
    }
  }

  /// Releases the active call lock for [leadId] if held by the current user.
  @override
  Future<void> releaseLeadLock(String leadId) async {
    if (leadId.trim().isEmpty || !OfflineQueueService.instance.isOnline) {
      return;
    }
    try {
      final actor = await _verifyCurrentActor();
      final leadRef = _leads.doc(leadId);
      await _firestore
          .runTransaction((tx) async {
            final snap = await tx.get(leadRef);
            if (!snap.exists || snap.data() == null) return;
            final data = snap.data()!;
            if (data['isLocked'] == true &&
                data['lockedByUid']?.toString() == actor.uid) {
              tx.update(leadRef, {
                'isLocked': false,
                'lockedByUid': null,
                'lockedByName': null,
                'lockedAt': null,
                'lockedMessage': null,
              });
            }
          })
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  @override
  Future<void> logWhatsAppSent({
    required String leadId,
    required String leadName,
    required String templateTitle,
  }) async {
    final actor = await _verifyCurrentActor();
    final stamp = LeadDateHelper.timelineStamp();
    final entry =
        '$stamp · WhatsApp sent ("$templateTitle") by ${actor.name}';
    if (leadId.trim().isNotEmpty) {
      try {
        await _leads.doc(leadId).update({
          'lastContact': 'Today',
          'lastContactAt': FieldValue.serverTimestamp(),
          'timeline': FieldValue.arrayUnion([entry]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    try {
      final docId =
          'wa_${leadId}_${DateTime.now().millisecondsSinceEpoch}';
      await _callLogs.doc(docId).set({
        'leadId': leadId,
        'leadName': leadName,
        'executiveUid': actor.uid,
        'executiveName': actor.name,
        'outcome': 'WhatsApp sent',
        'duration': '—',
        'notes': 'Sent approved template: $templateTitle',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> markLeadOptedOut(String leadId, {bool optedOut = true}) async {
    final actor = await _verifyCurrentActor();
    final stamp = LeadDateHelper.timelineStamp();
    final entry = optedOut
        ? '$stamp · Marked "Do Not Contact" (DPDP Opt-out) by ${actor.name}'
        : '$stamp · Re-enabled contact consent by ${actor.name}';
    await _leads.doc(leadId).update({
      'optedOut': optedOut,
      if (optedOut) 'status': 'Opted out',
      if (optedOut) 'isDone': true,
      if (optedOut) 'followUpTime': '',
      'timeline': FieldValue.arrayUnion([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _appendAudit(
      actorUid: actor.uid,
      actorName: actor.name,
      action: optedOut
          ? 'Marked lead Do Not Contact (DPDP Opt-out)'
          : 'Cleared DPDP Opt-out',
      target: 'Lead ID: $leadId',
      category: 'dpdp_privacy',
    );
  }

  @override
  Future<void> eraseLeadPersonalData(String leadId) async {
    final actor = await _verifyCurrentActor(requireAdminOrManager: true);
    final leadRef = _leads.doc(leadId);
    final snap = await leadRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? const {};
    final oldPhone10 = (data['phoneNormalized'] ?? '').toString().trim();
    final stamp = LeadDateHelper.timelineStamp();

    final batch = _firestore.batch();
    batch.update(leadRef, {
      'name': 'Redacted Student (DPDP)',
      'phone': '00000 00000',
      'phoneNormalized': '',
      'email': '',
      'notes': 'Personal data erased per DPDP Act 2023 request.',
      'optedOut': true,
      'status': 'Opted out',
      'isDone': true,
      'followUpTime': '',
      'timeline': [
        '$stamp · Personal data erased per DPDP Act 2023 by ${actor.name}',
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (oldPhone10.isNotEmpty) {
      batch.delete(_leadPhones.doc(oldPhone10));
    }
    await batch.commit();

    await _appendAudit(
      actorUid: actor.uid,
      actorName: actor.name,
      action: 'Erased personal data (DPDP Act 2023)',
      target: 'Lead ID: $leadId',
      category: 'dpdp_erasure',
    );
  }

  @override
  Future<void> reportRateLimitExceeded({
    required String limitType,
    required int count,
  }) async {
    try {
      final actor = await _verifyCurrentActor();
      await _firestore.collection('alerts').add({
        'title': 'Security Alert: Rate Limit Exceeded',
        'message':
            '${actor.name} exceeded the hourly $limitType limit ($count attempts/hour). Access temporarily paused.',
        'type': 'security_rate_limit',
        'category': 'security',
        'executiveUid': actor.uid,
        'executiveName': actor.name,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _appendAudit(
        actorUid: actor.uid,
        actorName: actor.name,
        action: 'Rate limit exceeded ($limitType: $count/hr)',
        target: actor.name,
        category: 'security_alert',
      );
    } catch (_) {}
  }

  @override
  Future<({bool found, String message, String? owner, String? status})>
  lookupByPhone(String rawPhone) async {
    final err = LeadPhoneValidator.validate(rawPhone);
    if (err != null) {
      return (found: false, message: err, owner: null, status: null);
    }
    final phone10 = LeadPhoneValidator.normalize10Digits(rawPhone);
    await _verifyCurrentActor();

    final snap = await _leadPhones.doc(phone10).get();
    if (snap.exists && snap.data() != null) {
      final d = snap.data()!;
      final existingLeadId = (d['leadId'] ?? '').toString().trim();
      bool leadStillExists = false;
      if (existingLeadId.isNotEmpty) {
        final leadSnap = await _leads.doc(existingLeadId).get();
        leadStillExists = leadSnap.exists;
      }
      if (!leadStillExists) {
        // Stale index entry from a previously deleted lead — clean it up automatically
        try {
          await _leadPhones.doc(phone10).delete();
        } catch (_) {}
      } else {
        final leadName = (d['leadName'] ?? 'Existing Lead').toString();
        final ownerName = (d['ownerName'] ?? '—').toString();
        final status = (d['status'] ?? 'Assigned').toString();
        return (
          found: true,
          message: 'Already exists: $leadName ($phone10)',
          owner: ownerName,
          status: status,
        );
      }
    }

    return (
      found: false,
      message: 'No existing lead with phone $phone10. Safe to add as walk-in.',
      owner: null,
      status: null,
    );
  }

  @override
  Future<List<LeadImportItem>> verifyImportAgainstFirestore(
    List<LeadImportItem> items,
  ) async {
    await _verifyCurrentActor(requireAdminOrManager: true);

    final candidatePhones = items
        .where(
          (i) =>
              i.status == LeadImportStatus.valid &&
              i.phoneNormalized.isNotEmpty,
        )
        .map((i) => i.phoneNormalized)
        .toSet()
        .toList();

    if (candidatePhones.isEmpty) return items;

    final existingPhoneMap =
        <String, ({String leadId, String leadName, String ownerName})>{};

    // 1. Query lead_phones in batches of 30
    for (int i = 0; i < candidatePhones.length; i += 30) {
      final chunk = candidatePhones.sublist(
        i,
        i + 30 > candidatePhones.length ? candidatePhones.length : i + 30,
      );
      final futures = chunk.map((p) => _leadPhones.doc(p).get());
      final snaps = await Future.wait(futures);
      for (final snap in snaps) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final existingLeadId = (data['leadId'] ?? '').toString().trim();
          if (existingLeadId.isNotEmpty) {
            final leadSnap = await _leads.doc(existingLeadId).get();
            if (!leadSnap.exists) {
              try {
                await _leadPhones.doc(snap.id).delete();
              } catch (_) {}
              continue;
            }
          } else {
            continue;
          }
          existingPhoneMap[snap.id] = (
            leadId: existingLeadId,
            leadName: (data['leadName'] ?? 'Existing Lead').toString(),
            ownerName: (data['ownerName'] ?? '—').toString(),
          );
        }
      }
    }

    // 2. Query leads collection where phoneNormalized in chunk (for any leads created before lead_phones)
    final remainingToCheck = candidatePhones
        .where((p) => !existingPhoneMap.containsKey(p))
        .toList();
    for (int i = 0; i < remainingToCheck.length; i += 30) {
      final chunk = remainingToCheck.sublist(
        i,
        i + 30 > remainingToCheck.length ? remainingToCheck.length : i + 30,
      );
      final querySnap = await _leads
          .where('phoneNormalized', whereIn: chunk)
          .get();
      for (final doc in querySnap.docs) {
        final data = doc.data();
        final pNorm = (data['phoneNormalized'] ?? '').toString();
        if (pNorm.isNotEmpty && !existingPhoneMap.containsKey(pNorm)) {
          existingPhoneMap[pNorm] = (
            leadId: doc.id,
            leadName: (data['name'] ?? 'Existing Lead').toString(),
            ownerName: (data['assignedToName'] ?? '—').toString(),
          );
        }
      }
    }

    // 3. Mark matching items as existing
    for (final item in items) {
      if (item.status == LeadImportStatus.valid &&
          existingPhoneMap.containsKey(item.phoneNormalized)) {
        final match = existingPhoneMap[item.phoneNormalized]!;
        item.status = LeadImportStatus.existing;
        item.existingLeadId = match.leadId;
        item.existingLeadName = match.leadName;
        item.existingOwner = match.ownerName;
        final ownerSuffix = match.ownerName.isNotEmpty && match.ownerName != '—'
            ? ' – owned by ${match.ownerName}'
            : '';
        item.issueMessage =
            'Existing lead in database$ownerSuffix (blanks filled in, never overwritten)';
      }
    }

    return items;
  }

  @override
  Future<LeadImportSummary> executeBulkImport({
    required List<LeadImportItem> items,
    required String sourceEvent,
    required String consentBasis,
    required String fileName,
    int fileSizeBytes = 0,
    bool skipExisting = true,
    void Function(int processed, int total)? onProgress,
  }) async {
    final actor = await _verifyCurrentActor(requireAdminOrManager: true);
    final startTime = DateTime.now();

    int validCount = 0;
    int existingCount = 0;
    int duplicateInFileCount = 0;
    int invalidCount = 0;
    int importedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;

    for (final item in items) {
      switch (item.status) {
        case LeadImportStatus.valid:
          validCount++;
          break;
        case LeadImportStatus.existing:
          existingCount++;
          break;
        case LeadImportStatus.duplicateInFile:
          duplicateInFileCount++;
          break;
        case LeadImportStatus.invalid:
          invalidCount++;
          break;
        default:
          break;
      }
    }

    // Identify rows to write to Firestore
    final itemsToWrite = <LeadImportItem>[];
    for (final item in items) {
      if (item.isExcluded) {
        item.status = LeadImportStatus.skipped;
        skippedCount++;
        continue;
      }

      if (item.status == LeadImportStatus.invalid ||
          item.status == LeadImportStatus.duplicateInFile) {
        skippedCount++;
        continue;
      }

      if (item.status == LeadImportStatus.existing) {
        if (skipExisting) {
          item.status = LeadImportStatus.skipped;
          skippedCount++;
          continue;
        } else {
          itemsToWrite.add(item);
        }
      } else if (item.status == LeadImportStatus.valid) {
        itemsToWrite.add(item);
      }
    }

    final totalCandidates = itemsToWrite.length;
    var processedCount = 0;

    // Batched writes: 150 items per batch (each new lead writes 2 docs = 300 ops, well under 500 limit)
    const int batchSize = 150;
    for (int i = 0; i < itemsToWrite.length; i += batchSize) {
      final chunk = itemsToWrite.sublist(
        i,
        i + batchSize > itemsToWrite.length
            ? itemsToWrite.length
            : i + batchSize,
      );

      final batch = _firestore.batch();
      final now = DateTime.now();

      for (final item in chunk) {
        if (item.status == LeadImportStatus.valid) {
          final newLeadRef = _leads.doc();
          final phoneRef = _leadPhones.doc(item.phoneNormalized);

          final leadRecord = item.toLeadRecord(
            creatorUid: actor.uid,
            creatorName: actor.name,
            now: now,
          );

          batch.set(newLeadRef, {
            ...leadRecord.toFirestoreMap(),
            'source': sourceEvent.isNotEmpty ? sourceEvent : leadRecord.source,
            'consent': consentBasis.isNotEmpty
                ? consentBasis
                : leadRecord.consent,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          batch.set(phoneRef, {
            'phoneNormalized': item.phoneNormalized,
            'leadId': newLeadRef.id,
            'leadName': item.name.trim(),
            'ownerUid': null,
            'ownerName': '—',
            'status': 'New',
            'source': sourceEvent,
            'createdByUid': actor.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else if (item.status == LeadImportStatus.existing &&
            !skipExisting &&
            item.existingLeadId != null) {
          final existingLeadRef = _leads.doc(item.existingLeadId);
          final enrichUpdates = <String, dynamic>{
            'updatedAt': FieldValue.serverTimestamp(),
            if (item.email.isNotEmpty) 'email': item.email,
            if (item.college.isNotEmpty) 'college': item.college,
            if (item.branch.isNotEmpty) 'branch': item.branch,
            if (item.year.isNotEmpty) 'year': item.year,
            if (item.course.isNotEmpty) 'course': item.course,
            'timeline': FieldValue.arrayUnion([
              '${LeadDateHelper.timelineStamp(now)} · Profile enriched via Bulk Import by ${actor.name} (Source: $sourceEvent)',
            ]),
          };
          batch.update(existingLeadRef, enrichUpdates);
        }
      }

      try {
        await batch.commit();
        for (final item in chunk) {
          item.status = LeadImportStatus.imported;
          importedCount++;
        }
      } catch (err) {
        for (final item in chunk) {
          item.status = LeadImportStatus.failed;
          item.issueMessage = 'Batch write error: ${err.toString()}';
          failedCount++;
        }
      }

      processedCount += chunk.length;
      onProgress?.call(processedCount, totalCandidates);
    }

    // Append Audit Log record
    await _appendAudit(
      actorUid: actor.uid,
      actorName: actor.name,
      action: 'leads.bulk_import',
      target:
          'Imported $importedCount leads ($validCount new, $existingCount existing, $skippedCount skipped, $failedCount failed) from $fileName ($sourceEvent)',
      category: 'import',
    );

    final errorReportCsv = LeadImportParser.generateErrorReportCsv(items);

    return LeadImportSummary(
      totalRows: items.length,
      validCount: validCount,
      existingCount: existingCount,
      duplicateInFileCount: duplicateInFileCount,
      invalidCount: invalidCount,
      importedCount: importedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      startedAt: startTime,
      completedAt: DateTime.now(),
      errorReportCsv: errorReportCsv,
    );
  }
}

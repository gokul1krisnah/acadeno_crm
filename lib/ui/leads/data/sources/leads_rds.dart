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
  });

  /// Assigns (or reassigns) one or more leads to an active Sales Executive for [dateKey].
  Future<AssignmentBatchSummary> assignLeadsToExecutive({
    required List<String> leadIds,
    required String executiveUid,
    required String dateKey,
    required String dateLabel,
    bool allowReassign = false,
  });

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
  });

  /// Performs a backend 10-digit phone duplicate lookup via `lead_phones/{phone10}`.
  Future<({bool found, String message, String? owner, String? status})>
  lookupByPhone(String rawPhone);
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
  }) => _backend.updateLead(
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
  }) => _backend.recordExecutiveCallOutcome(
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
  lookupByPhone(String rawPhone) => _backend.lookupByPhone(rawPhone);
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

  static const Set<String> _adminAndManagerRoles = {'admin', 'super_admin'};

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
      doc = await _users
          .doc(uid)
          .get()
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
        isAdminSession && !_adminAndManagerRoles.contains(rawRole)
        ? 'super_admin'
        : rawRole;
    final rawName = (data['name'] ?? currentUserDisplayName).toString().trim();

    if (requireAdminOrManager &&
        !_adminAndManagerRoles.contains(effectiveRole)) {
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
    await _verifyCurrentActor(requireAdminOrManager: true);
    yield* _leads.snapshots().map((snapshot) {
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
    return _users.where('isActive', isEqualTo: true).snapshots().map((snap) {
      final allActive = snap.docs
          .map((d) => SalesExecutiveOption.fromMap(d.id, d.data()))
          .where((u) => u.isActive)
          .toList();
      // HR is the actual caller user receiving lead assignments
      final hrUsers = allActive
          .where(
            (u) =>
                u.role.toLowerCase() == 'hr' ||
                u.role.toLowerCase() == 'executive',
          )
          .toList();
      final nonAdmins = allActive
          .where((u) => !_adminAndManagerRoles.contains(u.role.toLowerCase()))
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
    return _assignments
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
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
        throw DuplicateLeadException(
          phone10: phone10,
          existingLeadId: (pData['leadId'] ?? '').toString(),
          existingLeadName: (pData['leadName'] ?? 'Existing lead').toString(),
          existingOwnerName: (pData['ownerName'] ?? '—').toString(),
        );
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
    final isAdminOrManager = _adminAndManagerRoles.contains(actor.role);

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
          final existingId = (pData['leadId'] ?? '').toString();
          if (existingId != leadId) {
            throw DuplicateLeadException(
              phone10: newPhone10,
              existingLeadId: existingId,
              existingLeadName: (pData['leadName'] ?? 'Existing lead')
                  .toString(),
              existingOwnerName: (pData['ownerName'] ?? '—').toString(),
            );
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
          if (existingAssign.executiveUid == executive.uid && !allowReassign) {
            throw AssignmentConflictException(
              '${lead.name} is already assigned to ${executive.name} for $dateLabel.',
            );
          }
          if (existingAssign.executiveUid != executive.uid && !allowReassign) {
            throw AssignmentConflictException(
              '${lead.name} is already assigned to ${existingAssign.executiveName} for $dateLabel. Confirm reassignment to proceed.',
            );
          }
          prevExecUid = existingAssign.executiveUid;
          prevExecName = existingAssign.executiveName;
          isReassignment = existingAssign.executiveUid != executive.uid;
        } else if (lead.assignedDateKey == dateKey &&
            lead.assignedToUid != null &&
            lead.assignedToUid!.isNotEmpty) {
          if (lead.assignedToUid == executive.uid && !allowReassign) {
            throw AssignmentConflictException(
              '${lead.name} is already assigned to ${executive.name} for $dateLabel.',
            );
          }
          if (lead.assignedToUid != executive.uid && !allowReassign) {
            throw AssignmentConflictException(
              '${lead.name} is already assigned to ${lead.assignedToName} for $dateLabel. Confirm reassignment to proceed.',
            );
          }
          prevExecUid = lead.assignedToUid;
          prevExecName = lead.assignedToName;
          isReassignment = lead.assignedToUid != executive.uid;
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

        tx.update(_leads.doc(lead.id), {
          'assignedToUid': executive.uid,
          'assignedToName': executive.name,
          'assignedTo': executive.name,
          'assignedDateKey': dateKey,
          'assignedDateLabel': dateLabel,
          'assignedByUid': actor.uid,
          'assignedByName': actor.name,
          'assignedAt': FieldValue.serverTimestamp(),
          'status': nextLeadStatus,
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

    // 2. Query ONLY this executive's assignments for the target date.
    // Use synchronous .map to prevent targetId desynchronization & WatchChangeAggregator crashes on Web (RL-5, RL-6)
    yield* _assignments
        .where('executiveUid', isEqualTo: actor.uid)
        .where('dateKey', isEqualTo: effectiveDateKey)
        .snapshots()
        .map((assignmentSnap) {
          if (assignmentSnap.docs.isEmpty) {
            return const <ExecutiveLeadItem>[];
          }

          return assignmentSnap.docs.map((doc) {
            final assignment = LeadAssignmentModel.fromFirestore(doc);
            return assignment.toFallbackLeadRecord().toExecutiveLeadItem(
              assignment: assignment,
            );
          }).toList();
        });
  }

  @override
  Stream<List<CallHistoryRecord>> watchExecutiveCallRecords() async* {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      yield const <CallHistoryRecord>[];
      return;
    }
    yield* _callLogs.where('executiveUid', isEqualTo: uid).snapshots().map((
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
    final isAdminOrManager = _adminAndManagerRoles.contains(actor.role);
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
  }) async {
    final actor = await _verifyCurrentActor();
    final todayKey = LeadDateHelper.todayDateKey();
    String collegeInfo = '—';
    String campaign = 'Direct visit';

    final leadRef = _leads.doc(leadId);
    final assignId = LeadAssignmentModel.docId(leadId, todayKey);
    final assignRef = _assignments.doc(assignId);

    final isFollowUpPending =
        outcome == 'Follow-up' ||
        outcome == 'Callback' ||
        outcome == 'Interested' ||
        outcome == 'No answer';

    // Persist a concrete date/time (never "Today"/"Tomorrow") so follow-ups
    // can't drift as days pass. Only outcomes that need a follow-up get one.
    final resolvedFollowUp = isFollowUpPending
        ? LeadDateHelper.resolveFollowUpLabel(followUpTime, outcome: outcome)
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
          'lockedMessage': null,
          'followUpTime': ?resolvedFollowUp,
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

        String nextStatus = lead.status;
        if (lead.status != 'Converted') {
          if (outcome == 'No answer' && lead.status == 'Interested') {
            nextStatus = 'Interested';
          } else {
            nextStatus = outcome;
          }
        }

        final nextTimeline = <String>[
          '${LeadDateHelper.timelineStamp()} · $outcome logged by ${actor.name}${notes.trim().isNotEmpty ? " ($notes)" : ""}',
          ...lead.timeline,
        ];

        await leadRef
            .update({
              'status': nextStatus,
              'lastContact': 'Today',
              'lastContactAt': FieldValue.serverTimestamp(),
              'lastCalledAt': FieldValue.serverTimestamp(),
              'isDone': !isFollowUpPending,
              'isLocked': false,
              'lockedByUid': null,
              'lockedMessage': null,
              'followUpTime': ?resolvedFollowUp,
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
            'duration': duration.trim().isEmpty ? '2m 15s' : duration.trim(),
            'notes': notes.trim().isEmpty
                ? 'Logged $outcome outcome'
                : notes.trim(),
            'courseEnrolled': ?courseEnrolled,
            'discountAmount': ?discountAmount,
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

    final needsApproval = outcome == 'Converted' && (discountAmount ?? 0) > 500;
    return CallOutcomeResult(
      collegeInfo: collegeInfo,
      needsDiscountApproval: needsApproval,
    );
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
          existingPhoneMap[snap.id] = (
            leadId: (data['leadId'] ?? '').toString(),
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

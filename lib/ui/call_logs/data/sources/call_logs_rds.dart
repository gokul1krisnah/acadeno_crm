import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../leads/data/model/lead_models.dart';
import '../model/call_log_model.dart';

class CallLogsRds {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  static const MethodChannel _channel = MethodChannel(
    'com.acadeno.crm/phone_call',
  );

  CallLogsRds({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _callCategorizations =>
      _firestore.collection('call_categorizations');

  CollectionReference<Map<String, dynamic>> get _leads =>
      _firestore.collection('leads');

  CollectionReference<Map<String, dynamic>> get _leadPhones =>
      _firestore.collection('lead_phones');

  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  String get currentUserDisplayName {
    final user = _firebaseAuth.currentUser;
    final name = user?.displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'Executive';
  }

  /// Whether current platform supports native carrier call logs (Android only).
  bool get isPlatformSupported => !kIsWeb && Platform.isAndroid;

  /// Checks if Android READ_CALL_LOG permission is granted.
  Future<bool> checkPermission() async {
    if (!isPlatformSupported) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('checkPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests runtime call log permissions from the native operating system.
  Future<bool> requestPermission() async {
    if (!isPlatformSupported) return false;
    try {
      await _channel.invokeMethod('requestPermissions');
      // Verify granted status after requesting
      return await checkPermission();
    } catch (_) {
      return false;
    }
  }

  /// Checks if Android READ_CONTACTS permission is granted.
  Future<bool> checkContactsPermission() async {
    if (!isPlatformSupported) return false;
    try {
      final granted = await _channel.invokeMethod<bool>(
        'checkContactsPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests runtime READ_CONTACTS permission from Android.
  Future<bool> requestContactsPermission() async {
    if (!isPlatformSupported) return false;
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestContactsPermission',
      );
      return granted ?? await checkContactsPermission();
    } catch (_) {
      return false;
    }
  }

  /// Fetches real device call logs from the native telephony provider.
  Future<List<DeviceCallLogItem>> fetchDeviceCallLogs({int limit = 100}) async {
    if (!isPlatformSupported) return [];

    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'getCallLogs',
        {'limit': limit},
      );
      if (rawList == null) return [];

      final items = <DeviceCallLogItem>[];
      for (final raw in rawList) {
        if (raw is Map) {
          items.add(DeviceCallLogItem.fromMap(raw));
        }
      }
      return items;
    } catch (e) {
      debugPrint('CallLogsRds.fetchDeviceCallLogs error: $e');
      return [];
    }
  }

  /// Streams saved call categorizations for the current executive to keep pills synced.
  Stream<Map<String, CallCategory>> streamSavedCategorizations() {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      return Stream.value(const <String, CallCategory>{});
    }

    final query = _callCategorizations.where('executiveUid', isEqualTo: uid);

    return query.snapshots().map((snap) {
      final map = <String, CallCategory>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final cat = CallCategoryExtension.fromDbValue(
          data['category'] as String?,
        );
        final phoneNorm = (data['phoneNormalized'] ?? '').toString();
        final callId = (data['callId'] ?? doc.id).toString();

        if (phoneNorm.isNotEmpty) {
          map[phoneNorm] = cat;
        }
        if (callId.isNotEmpty) {
          map[callId] = cat;
        }
      }
      return map;
    });
  }

  /// Categorizes a call and persists the assignment in Firestore & CRM records.
  Future<void> saveCategorization({
    required DeviceCallLogItem item,
    required CallCategory category,
    String? notes,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw StateError('Please sign in to save categorizations.');
    }
    final name = currentUserDisplayName;
    final norm = item.normalizedPhone;
    final rawDigits = item.number.replaceAll(RegExp(r'\D'), '');
    final baseKey = norm.isNotEmpty
        ? norm
        : (rawDigits.isNotEmpty ? rawDigits : item.id);
    final docId = '${uid}_$baseKey';

    final String statusForCategory;
    if (category == CallCategory.followUp) {
      statusForCategory = 'Follow-up';
    } else if (category == CallCategory.reminder) {
      statusForCategory = 'Reminder';
    } else if (category == CallCategory.hotLead) {
      statusForCategory = 'Hot Lead';
    } else {
      statusForCategory = 'Assigned';
    }

    final now = DateTime.now();
    final String? defaultFollowUpSlot =
        (category == CallCategory.followUp ||
            category == CallCategory.reminder)
        ? LeadDateHelper.formatFollowUp(
            now
                .add(const Duration(days: 1))
                .copyWith(
                  hour: category == CallCategory.reminder ? 11 : 10,
                  minute: 30,
                ),
          )
        : null;

    final timelineEntry =
        '${LeadDateHelper.timelineStamp(now)} · Categorized as ${category.label} from Call Log by $name';

    // 1. Persist categorization in `call_categorizations/{uid}_{phoneOrCallId}`
    // and synchronize with `leads` in parallel so Home screen tabs update immediately.
    await Future.wait([
      _callCategorizations.doc(docId).set({
        'callId': item.id,
        'phone': item.number,
        'phoneNormalized': baseKey,
        if (item.hasContactName) 'contactName': item.contactName,
        'category': category.dbValue,
        'durationSeconds': item.durationSeconds,
        'callTimestamp': Timestamp.fromDate(item.timestamp),
        'categorizedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'executiveUid': uid,
        'executiveName': name,
        'notes': notes ?? '',
      }, SetOptions(merge: true)),
      _upsertExecutiveLeadFromCallLog(
        item: item,
        uid: uid,
        executiveName: name,
        category: category,
        status: statusForCategory,
        lastContactLabel: 'Today · Categorized via Call Log',
        timelineEntry: timelineEntry,
        notes: (notes != null && notes.trim().isNotEmpty)
            ? notes.trim()
            : 'Auto-categorized as ${category.label} from device call log.',
        followUpTime: defaultFollowUpSlot,
      ),
    ]);
  }

  /// Saves a detailed outcome from the "Other" popup to `call_categorizations`,
  /// `leads`, `call_logs`, and (if Callback/Follow-up) follow-ups.
  /// Throws on failure so the popup can remain open and let the user retry.
  Future<void> saveOtherOutcome({
    required DeviceCallLogItem item,
    required String outcome,
    required String notes,
    String? courseEnrolled,
    String? batch,
    String? followUpTime,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw StateError('Please sign in to save call outcomes.');
    }
    final trimmedOutcome = outcome.trim();
    if (trimmedOutcome.isEmpty) {
      throw ArgumentError('Please select a call outcome.');
    }
    final trimmedNotes = notes.trim();
    final name = currentUserDisplayName;
    final norm = item.normalizedPhone;
    final rawDigits = item.number.replaceAll(RegExp(r'\D'), '');
    final baseKey = norm.isNotEmpty
        ? norm
        : (rawDigits.isNotEmpty ? rawDigits : item.id);
    final docId = '${uid}_$baseKey';
    final now = DateTime.now();

    final String? effectiveFollowUpSlot =
        (trimmedOutcome == 'Callback' || trimmedOutcome == 'Follow-up')
        ? ((followUpTime != null && followUpTime.trim().isNotEmpty)
              ? followUpTime.trim()
              : LeadDateHelper.formatFollowUp(
                  now.add(const Duration(days: 1)).copyWith(
                    hour: 10,
                    minute: 30,
                  ),
                ))
        : ((followUpTime != null && followUpTime.trim().isNotEmpty)
              ? followUpTime.trim()
              : null);

    final timelineEntry =
        '${LeadDateHelper.timelineStamp(now)} · $trimmedOutcome logged from Call Log by $name'
        '${trimmedNotes.isNotEmpty ? " ($trimmedNotes)" : ""}';

    // 1. Persist categorization + outcome in `call_categorizations/{uid}_{key}`
    await _callCategorizations.doc(docId).set({
      'callId': item.id,
      'phone': item.number,
      'phoneNormalized': baseKey,
      if (item.hasContactName) 'contactName': item.contactName,
      'category': CallCategory.other.dbValue,
      'outcome': trimmedOutcome,
      'durationSeconds': item.durationSeconds,
      'callTimestamp': Timestamp.fromDate(item.timestamp),
      'categorizedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'executiveUid': uid,
      'executiveName': name,
      'notes': trimmedNotes,
      if (courseEnrolled != null && courseEnrolled.trim().isNotEmpty)
        'course': courseEnrolled.trim(),
      if (batch != null && batch.trim().isNotEmpty) 'batch': batch.trim(),
      'followUpTime': ?effectiveFollowUpSlot,
    }, SetOptions(merge: true));

    // 2. Synchronize with `leads` without rejecting non-6-9 or non-10-digit call log numbers
    final targetLeadId = await _upsertExecutiveLeadFromCallLog(
      item: item,
      uid: uid,
      executiveName: name,
      category: CallCategory.other,
      status: trimmedOutcome,
      lastContactLabel: 'Today · $trimmedOutcome',
      timelineEntry: timelineEntry,
      notes: trimmedNotes.isNotEmpty
          ? trimmedNotes
          : 'Logged as $trimmedOutcome from device call log.',
      courseEnrolled: courseEnrolled,
      batch: batch,
      followUpTime: effectiveFollowUpSlot,
    );

    // 3. Append permanent call log record for executive & admin visibility
    try {
      await _firestore.collection('call_logs').add({
        'leadId': targetLeadId ?? '',
        'leadName': item.hasContactName
            ? item.contactName
            : item.formattedNumber,
        'phone': item.number,
        'phoneNormalized': baseKey,
        'collegeInfo': 'Call Log Inquiry',
        'campaign': 'Call Log',
        'outcome': trimmedOutcome,
        'category': CallCategory.other.dbValue,
        'duration': item.formattedDuration,
        'notes': trimmedNotes,
        'executiveUid': uid,
        'executiveName': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('CallLogsRds.saveOtherOutcome call_logs append notice: $e');
    }
  }

  /// Finds, claims, or creates a `leads` document assigned to [uid] for [item]
  /// in a single pass with [category] and [status] already populated so the
  /// Home screen tabs (Hot Leads, Follow-ups, Reminders, All Calls) update
  /// immediately without failing on non-6-9 phone numbers or stale `lead_phones`.
  Future<String?> _upsertExecutiveLeadFromCallLog({
    required DeviceCallLogItem item,
    required String uid,
    required String executiveName,
    required CallCategory category,
    required String status,
    required String lastContactLabel,
    required String timelineEntry,
    String? notes,
    String? courseEnrolled,
    String? batch,
    String? followUpTime,
  }) async {
    final norm = item.normalizedPhone;
    final rawDigits = item.number.replaceAll(RegExp(r'\D'), '');
    final phoneKey = norm.isNotEmpty
        ? norm
        : (rawDigits.isNotEmpty ? rawDigits : item.id);
    if (phoneKey.isEmpty) return null;

    final displayPhone = item.number.trim().isNotEmpty
        ? LeadPhoneValidator.formatDisplayPhone(item.number)
        : (norm.isNotEmpty
              ? LeadPhoneValidator.formatDisplayPhone(norm)
              : phoneKey);

    final now = DateTime.now();
    final todayKey = LeadDateHelper.todayDateKey(now);
    final todayLabel = LeadDateHelper.dateLabel(now, now: now);

    final statusLower = status.trim().toLowerCase();
    final bool isTerminalDone =
        category == CallCategory.other &&
        (statusLower == 'converted' ||
            statusLower == 'not interested' ||
            statusLower == 'wrong number');
    final bool isDone = isTerminalDone;

    final commonUpdates = <String, dynamic>{
      'category': category.dbValue,
      'status': status,
      'assignedToUid': uid,
      'assignedToName': executiveName,
      'assignedTo': executiveName,
      'assignedDateKey': todayKey,
      'assignedDateLabel': todayLabel,
      'lastContact': lastContactLabel,
      'lastContactAt': FieldValue.serverTimestamp(),
      'lastCalledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDone': isDone,
      'followUpDone': isDone,
      'isOverdue': false,
      if (followUpTime != null && followUpTime.trim().isNotEmpty)
        'followUpTime': followUpTime.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (notes != null && notes.trim().isNotEmpty)
        'studentNotes': notes.trim(),
      if (courseEnrolled != null && courseEnrolled.trim().isNotEmpty)
        'course': courseEnrolled.trim(),
      if (batch != null && batch.trim().isNotEmpty) 'batch': batch.trim(),
      'timeline': FieldValue.arrayUnion([timelineEntry]),
    };

    // 1. Check executive's own assigned leads first (always permitted by firestore.rules).
    try {
      final ownQuery = await _leads
          .where('assignedToUid', isEqualTo: uid)
          .where('phoneNormalized', isEqualTo: phoneKey)
          .limit(1)
          .get();

      if (ownQuery.docs.isNotEmpty) {
        final doc = ownQuery.docs.first;
        final existingName = (doc.data()['name'] ?? '').toString().trim();
        final isAutoCode = RegExp(
          r'^L0*\d+$',
          caseSensitive: false,
        ).hasMatch(existingName);
        await doc.reference.update({
          ...commonUpdates,
          if (item.hasContactName && (existingName.isEmpty || isAutoCode))
            'name': item.contactName.trim(),
        });
        return doc.id;
      }
    } catch (e) {
      debugPrint('CallLogsRds own lead lookup notice: $e');
    }

    // 2. Check global phone index in case an unassigned lead exists that this executive can claim.
    try {
      final phoneDoc = await _leadPhones.doc(phoneKey).get();
      if (phoneDoc.exists && phoneDoc.data() != null) {
        final indexedLeadId = (phoneDoc.data()!['leadId'] ?? '')
            .toString()
            .trim();
        if (indexedLeadId.isNotEmpty) {
          try {
            await _leads.doc(indexedLeadId).update({
              ...commonUpdates,
              if (item.hasContactName) 'name': item.contactName.trim(),
            });
            await _leadPhones.doc(phoneKey).set({
              'ownerUid': uid,
              'ownerName': executiveName,
              'status': status,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            return indexedLeadId;
          } catch (_) {
            // The indexed lead was either deleted or belongs to another executive;
            // fall through to deterministic executive lead creation below.
          }
        }
      }
    } catch (_) {}

    // 3. Create or update the executive's deterministic lead document for this call log.
    final detLeadId = 'call_${uid}_$phoneKey';
    final detLeadRef = _leads.doc(detLeadId);

    String resolvedName = item.hasContactName ? item.contactName.trim() : '';
    if (resolvedName.isEmpty) {
      try {
        final existingDet = await detLeadRef.get();
        if (existingDet.exists && existingDet.data() != null) {
          resolvedName = (existingDet.data()!['name'] ?? '').toString().trim();
        }
      } catch (_) {}
    }
    if (resolvedName.isEmpty) {
      resolvedName = await _allocateNextLeadSequenceName(uid);
    }

    await detLeadRef.set({
      'id': detLeadId,
      'name': resolvedName,
      'phone': displayPhone,
      'phoneNormalized': phoneKey,
      'collegeBranch': 'Call Log Inquiry',
      'college': 'Call Log Inquiry',
      'branch': '',
      'year': '',
      'source': 'Call Log',
      'optedOut': false,
      'isLocked': false,
      'createdByUid': uid,
      'createdByName': executiveName,
      'createdAt': FieldValue.serverTimestamp(),
      'assignedByUid': uid,
      'assignedByName': executiveName,
      'assignedAt': FieldValue.serverTimestamp(),
      ...commonUpdates,
    }, SetOptions(merge: true));

    try {
      await _leadPhones.doc(phoneKey).set({
        'phoneNormalized': phoneKey,
        'leadId': detLeadId,
        'leadName': resolvedName,
        'ownerUid': uid,
        'ownerName': executiveName,
        'status': status,
        'createdByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    return detLeadId;
  }

  /// Atomically allocates the next sequential `L01`, `L02`, `L03` lead code.
  Future<String> _allocateNextLeadSequenceName(String uid) async {
    int seedMax = 0;
    try {
      final ownDocs = await _leads.where('assignedToUid', isEqualTo: uid).get();
      for (final d in ownDocs.docs) {
        final n = (d.data()['name'] ?? '').toString().trim();
        final m = RegExp(r'^L0*(\d+)$', caseSensitive: false).firstMatch(n);
        if (m != null) {
          final parsed = int.tryParse(m.group(1) ?? '0') ?? 0;
          if (parsed > seedMax) seedMax = parsed;
        }
      }
    } catch (_) {}

    final counterRef = _firestore.collection('counters').doc('lead_sequence');
    try {
      return await _firestore.runTransaction<String>((tx) async {
        final snap = await tx.get(counterRef);
        final stored = (snap.data()?['lastNumber'] as num?)?.toInt() ?? 0;
        final base = stored > seedMax ? stored : seedMax;
        final next = base + 1;
        tx.set(counterRef, {
          'lastNumber': next,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return 'L${next.toString().padLeft(2, '0')}';
      });
    } catch (_) {
      final next = seedMax + 1;
      return 'L${next.toString().padLeft(2, '0')}';
    }
  }

  /// Streams leads filtered by specific category for the user Home screen.
  Stream<List<ExecutiveLeadItem>> streamLeadsByCategory(CallCategory category) {
    final uid = currentUserId;
    Query<Map<String, dynamic>> query = _leads.where(
      'category',
      isEqualTo: category.dbValue,
    );
    if (uid != null && uid.isNotEmpty) {
      query = query.where('assignedToUid', isEqualTo: uid);
    }

    return query.snapshots().map((snap) {
      return snap.docs.map((doc) {
        final d = doc.data();
        final rawPhone = (d['phone'] ?? '').toString();
        final masked = LeadPhoneValidator.maskPhone(rawPhone);
        final name = (d['name'] ?? 'Lead').toString();
        final status = (d['status'] ?? 'New').toString();
        final (sColor, sBg) = ExecutiveLeadItem.statusColorsFor(status);

        return ExecutiveLeadItem(
          id: doc.id,
          name: name,
          initials: LeadPhoneValidator.initialsFromName(name),
          maskedPhone: masked,
          fullPhone: rawPhone,
          collegeInfo: (d['collegeBranch'] ?? 'Inquiry').toString(),
          statusTag: status,
          statusColor: sColor,
          statusBg: sBg,
          campaignTag: (d['source'] ?? 'Call Log').toString(),
          followUpTime: (d['followUpTime'] ?? 'Tomorrow, 10:30 AM').toString(),
        );
      }).toList();
    });
  }
}

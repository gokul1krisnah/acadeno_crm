import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../leads/data/model/lead_models.dart';
import '../model/follow_up_models.dart';
import '../model/follow_up_time_helper.dart';

/// Remote data source for executive follow-ups connected directly to Cloud Firestore.
/// Live bidirectional synchronization with the Admin Dashboard.
/// Real-time, authentic Firestore leads stream with dynamic overdue evaluation.
class FollowUpsRds {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  FollowUpsRds({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _leads =>
      _firestore.collection('leads');

  CollectionReference<Map<String, dynamic>> get _auditLog =>
      _firestore.collection('audit_log');

  /// Streams real-time follow-ups for the currently signed-in executive.
  Stream<List<ExecutiveFollowUpItem>> watchFollowUps({String? executiveUid}) {
    final uid = executiveUid ?? _firebaseAuth.currentUser?.uid;

    return _leads.snapshots().map((snap) {
      if (snap.docs.isEmpty) {
        return const <ExecutiveFollowUpItem>[];
      }

      final matchingDocs = snap.docs.where((doc) {
        final data = doc.data();
        final assignedUid = (data['assignedToUid'] ?? '').toString();
        if (uid != null &&
            uid.isNotEmpty &&
            assignedUid.isNotEmpty &&
            assignedUid != uid) {
          return false;
        }
        if (_isLeadDone(data)) return false;

        final status = (data['status'] ?? '').toString().toLowerCase();
        final hasFollowUpTime = data['followUpTime'] != null;

        // Matches any active follow-up, assigned call, or open lead candidate
        return hasFollowUpTime ||
            status == 'follow-up' ||
            status == 'callback' ||
            status == 'interested' ||
            status == 'no answer' ||
            status == 'claimed' ||
            status == 'assigned' ||
            status == 'overdue' ||
            status == 'new';
      }).toList();

      final items = <ExecutiveFollowUpItem>[];
      for (final doc in matchingDocs) {
        final item = _itemFromDoc(doc);
        if (item != null) items.add(item);
      }

      _sortFollowUps(items);
      return items;
    });
  }

  /// Streams all open follow-ups across all executives for the Admin Dashboard.
  Stream<List<ExecutiveFollowUpItem>> watchAllFollowUps() {
    return _leads.snapshots().map((snap) {
      final items = <ExecutiveFollowUpItem>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (_isLeadDone(data)) continue;

        final item = _itemFromDoc(doc);
        if (item != null) items.add(item);
      }
      _sortFollowUps(items);
      return items;
    });
  }

  /// Fetches a fresh live snapshot directly from Cloud Firestore (bypassing cached stream).
  Future<List<ExecutiveFollowUpItem>> fetchLiveFollowUps({
    String? executiveUid,
  }) async {
    final uid = executiveUid ?? _firebaseAuth.currentUser?.uid;
    final snap = await _leads.get(
      const GetOptions(source: Source.serverAndCache),
    );

    final items = <ExecutiveFollowUpItem>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final assignedUid = (data['assignedToUid'] ?? '').toString();
      if (uid != null &&
          uid.isNotEmpty &&
          assignedUid.isNotEmpty &&
          assignedUid != uid) {
        continue;
      }
      if (_isLeadDone(data)) continue;

      final item = _itemFromDoc(doc);
      if (item != null) items.add(item);
    }

    _sortFollowUps(items);
    return items;
  }

  ExecutiveFollowUpItem? _itemFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;

    final rawPhone = (data['phone'] ?? '').toString();
    final maskedPhone = _maskPhone(rawPhone);
    final leadName = (data['name'] ?? 'Student Lead').toString();
    final collegeInfo =
        (data['collegeBranch'] ?? data['college'] ?? 'College inquiry')
            .toString();
    final status = (data['status'] ?? '').toString();
    final note = (data['notes'] ?? 'Follow up on course enrollment and details')
        .toString();

    final eval = FollowUpTimeHelper.evaluate(
      rawFollowUpTime: data['followUpTime'],
      assignedDateKey: data['assignedDateKey'],
      assignedDateLabel: data['assignedDateLabel'],
      assignedAt: data['assignedAt'],
      updatedAt: data['updatedAt'],
      createdAt: data['createdAt'],
      status: status,
    );

    // Auto-sync overdue flag in Firestore if missed
    if (eval.isOverdue &&
        data['isOverdue'] != true &&
        status.toLowerCase() != 'overdue') {
      unawaited(
        _leads
            .doc(doc.id)
            .update({
              'isOverdue': true,
              'status': 'overdue',
              'lastEvaluatedOverdue': FieldValue.serverTimestamp(),
            })
            .catchError((_) {}),
      );
    }

    String channelLabel = 'Call';
    if (note.toLowerCase().contains('whatsapp') ||
        (data['channel'] ?? '').toString().toLowerCase().contains('whatsapp')) {
      channelLabel = 'WhatsApp';
    } else if (status.toLowerCase() == 'no answer') {
      channelLabel = 'Auto-retry';
    }

    return ExecutiveFollowUpItem(
      id: doc.id,
      leadName: leadName,
      maskedPhone: maskedPhone,
      phone: rawPhone,
      collegeInfo: collegeInfo,
      timeLabel: eval.displayLabel,
      channelLabel: channelLabel,
      note: note,
      bucket: eval.bucket,
      isCompleted: false,
      scheduledTime: eval.scheduledTime,
      assignedToName: (data['assignedToName'] ?? data['assignedTo'])
          ?.toString(),
      assignedToUid: data['assignedToUid']?.toString(),
    );
  }

  static bool _isLeadDone(Map<String, dynamic> data) {
    final val = data['isDone'] ?? data['followUpDone'];
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  void _sortFollowUps(List<ExecutiveFollowUpItem> items) {
    items.sort((a, b) {
      // Overdue first, then Today, then Upcoming
      if (a.bucket != b.bucket) {
        return a.bucket.index.compareTo(b.bucket.index);
      }
      final aTime = a.scheduledTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.scheduledTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (a.bucket == FollowUpBucket.overdue) {
        // Most overdue (earliest missed) first
        return aTime.compareTo(bTime);
      } else {
        // Earliest scheduled first
        return aTime.compareTo(bTime);
      }
    });
  }

  /// Completes a follow-up directly in Firestore.
  Future<void> completeFollowUp(String id) async {
    try {
      final docRef = _leads.doc(id);
      final snap = await docRef.get();
      if (snap.exists) {
        await docRef.update({
          'isDone': true,
          'followUpDone': true,
          'isOverdue': false,
          'status': 'contacted',
          'lastContact': 'Today',
          'lastContactAt': FieldValue.serverTimestamp(),
          'lastCalledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _appendAudit(
          action: 'Follow-up completed: ${snap.data()?['name'] ?? id}',
          category: 'follow_up',
        );
      }
    } catch (_) {}
  }

  /// Snoozes or reschedules a follow-up directly in Firestore.
  Future<void> snoozeFollowUp(
    String id,
    String newTimeLabel, {
    bool moveToUpcoming = false,
  }) async {
    try {
      final docRef = _leads.doc(id);
      final snap = await docRef.get();
      if (snap.exists) {
        // Store a concrete date so "Today"/"Tomorrow" can't go stale.
        final concreteLabel =
            LeadDateHelper.resolveFollowUpLabel(newTimeLabel) ?? newTimeLabel;
        await docRef.update({
          'followUpTime': concreteLabel,
          'status': 'Follow-up',
          'isDone': false,
          'isOverdue': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _appendAudit(
          action:
              'Follow-up snoozed to $newTimeLabel: ${snap.data()?['name'] ?? id}',
          category: 'follow_up',
        );
      }
    } catch (_) {}
  }

  /// Initial synchronous fetch (empty until stream or fetchLiveFollowUps fires).
  List<ExecutiveFollowUpItem> fetchFollowUps() =>
      const <ExecutiveFollowUpItem>[];

  Future<void> _appendAudit({
    required String action,
    required String category,
  }) async {
    final user = _firebaseAuth.currentUser;
    try {
      await _auditLog.add({
        'action': action,
        'category': category,
        'userId': user?.uid ?? 'unknown',
        'userEmail': user?.email ?? 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final last10 = digits.substring(digits.length - 10);
      return '${last10.substring(0, 5)} •••${last10.substring(8)}';
    }
    return phone.isNotEmpty ? phone : '—';
  }
}

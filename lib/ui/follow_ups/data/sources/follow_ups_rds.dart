import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/follow_up_models.dart';

/// Remote data source for executive follow-ups connected directly to Cloud Firestore.
/// Live bidirectional synchronization with the Admin Dashboard.
/// 100% Real-time, authentic Firestore leads stream.
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
        final isDone = (data['isDone'] as bool?) ?? false;
        if (isDone) return false;

        final status = (data['status'] ?? '').toString().toLowerCase();
        final hasFollowUpTime = data['followUpTime'] != null;
        return hasFollowUpTime ||
            status == 'follow-up' ||
            status == 'callback' ||
            status == 'interested' ||
            status == 'no answer' ||
            status == 'claimed';
      }).toList();

      if (matchingDocs.isEmpty) {
        return const <ExecutiveFollowUpItem>[];
      }

      final items = <ExecutiveFollowUpItem>[];
      for (final doc in matchingDocs) {
        final data = doc.data();
        final rawPhone = (data['phone'] ?? '').toString();
        final maskedPhone = _maskPhone(rawPhone);
        final leadName = (data['name'] ?? 'Student Lead').toString();
        final collegeInfo =
            (data['collegeBranch'] ?? data['college'] ?? 'College inquiry')
                .toString();
        final timeLabel =
            (data['followUpTime'] ?? 'Today · Scheduled').toString();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final note =
            (data['notes'] ?? 'Follow up on course enrollment and details')
                .toString();

        FollowUpBucket bucket;
        final timeLower = timeLabel.toLowerCase();
        if (timeLower.contains('yesterday') || status == 'overdue') {
          bucket = FollowUpBucket.overdue;
        } else if (timeLower.contains('tomorrow') ||
            timeLower.contains('thu') ||
            timeLower.contains('fri') ||
            timeLower.contains('sat') ||
            timeLower.contains('next')) {
          bucket = FollowUpBucket.upcoming;
        } else {
          bucket = FollowUpBucket.today;
        }

        String channelLabel = 'Call';
        if (note.toLowerCase().contains('whatsapp') ||
            (data['channel'] ?? '').toString().toLowerCase().contains(
              'whatsapp',
            )) {
          channelLabel = 'WhatsApp';
        } else if (status == 'no answer') {
          channelLabel = 'Auto-retry';
        }

        items.add(
          ExecutiveFollowUpItem(
            id: doc.id,
            leadName: leadName,
            maskedPhone: maskedPhone,
            collegeInfo: collegeInfo,
            timeLabel: timeLabel,
            channelLabel: channelLabel,
            note: note,
            bucket: bucket,
            isCompleted: false,
          ),
        );
      }

      return items;
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
          'status': 'contacted',
          'lastContact': 'Today',
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
        await docRef.update({
          'followUpTime': newTimeLabel,
          'status': 'Follow-up',
          'isDone': false,
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

  /// Returns empty list initially; all data comes strictly from Firestore.
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

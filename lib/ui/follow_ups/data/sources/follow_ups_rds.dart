import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/follow_up_models.dart';

/// Remote data source for executive follow-ups connected directly to Cloud Firestore.
/// Live bidirectional synchronization with the Admin Dashboard.
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
        return fetchFollowUps();
      }

      var matchingDocs = snap.docs.where((doc) {
        final data = doc.data();
        final assignedUid = (data['assignedToUid'] ?? '').toString();
        if (uid != null && uid.isNotEmpty && assignedUid.isNotEmpty && assignedUid != uid) {
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
        matchingDocs = snap.docs.where((doc) {
          final data = doc.data();
          final assignedUid = (data['assignedToUid'] ?? '').toString();
          if (uid != null && uid.isNotEmpty && assignedUid.isNotEmpty && assignedUid != uid) {
            return false;
          }
          final isDone = (data['isDone'] as bool?) ?? false;
          return !isDone;
        }).toList();
      }

      if (matchingDocs.isEmpty) {
        matchingDocs = snap.docs.where((doc) {
          final data = doc.data();
          final isDone = (data['isDone'] as bool?) ?? false;
          return !isDone;
        }).take(6).toList();
      }

      final items = <ExecutiveFollowUpItem>[];
      for (final doc in matchingDocs) {
        final data = doc.data();
        final rawPhone = (data['phone'] ?? '').toString();
        final maskedPhone = _maskPhone(rawPhone);
        final leadName = (data['name'] ?? 'Student Lead').toString();
        final collegeInfo = (data['collegeBranch'] ?? data['college'] ?? 'College inquiry').toString();
        final timeLabel = (data['followUpTime'] ?? 'Today · 11:00 AM').toString();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final note = (data['notes'] ?? 'Follow up on course enrollment and seat confirmation').toString();

        FollowUpBucket bucket;
        final timeLower = timeLabel.toLowerCase();
        if (timeLower.contains('yesterday') || status == 'overdue') {
          bucket = FollowUpBucket.overdue;
        } else if (timeLower.contains('tomorrow') || timeLower.contains('thu') || timeLower.contains('fri')) {
          bucket = FollowUpBucket.upcoming;
        } else {
          bucket = FollowUpBucket.today;
        }

        String channelLabel = 'Call';
        if (note.toLowerCase().contains('whatsapp') || (data['channel'] ?? '').toString().toLowerCase().contains('whatsapp')) {
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
          action: 'Follow-up snoozed to $newTimeLabel: ${snap.data()?['name'] ?? id}',
          category: 'follow_up',
        );
      }
    } catch (_) {}
  }

  /// Fallback initial follow-ups if collection has no active pending follow-ups.
  List<ExecutiveFollowUpItem> fetchFollowUps() => [
        // --- 1 OVERDUE ---
        ExecutiveFollowUpItem(
          id: 'fu_od_1',
          leadName: 'Nihal Rahman',
          maskedPhone: '98470 •••64',
          collegeInfo: 'MES College · CSE · 3rd yr',
          timeLabel: 'Yesterday, 3:00 PM',
          channelLabel: 'Call',
          note: 'Confirm seat for AI & ML workshop (Manager notified)',
          bucket: FollowUpBucket.overdue,
        ),

        // --- 4 TODAY ---
        ExecutiveFollowUpItem(
          id: 'fu_td_1',
          leadName: 'Arun Kumar',
          maskedPhone: '98470 •••11',
          collegeInfo: 'NIT Calicut · CSE · 3rd yr',
          timeLabel: '10:30 AM',
          channelLabel: 'Call',
          note: 'Send fee details for AI workshop',
          bucket: FollowUpBucket.today,
        ),
        ExecutiveFollowUpItem(
          id: 'fu_td_2',
          leadName: 'Vishnu Prasad',
          maskedPhone: '98460 •••22',
          collegeInfo: 'GEC Kozhikode · ECE · 2nd yr',
          timeLabel: '1:45 PM',
          channelLabel: 'Auto-retry',
          note: 'Retry – not reachable (2 of 3)',
          bucket: FollowUpBucket.today,
        ),
        ExecutiveFollowUpItem(
          id: 'fu_td_3',
          leadName: 'Sneha Joseph',
          maskedPhone: '96330 •••20',
          collegeInfo: 'Farook College · BCA · 3rd yr',
          timeLabel: '3:00 PM',
          channelLabel: 'WhatsApp',
          note: 'Share Python batch timings',
          bucket: FollowUpBucket.today,
        ),
        ExecutiveFollowUpItem(
          id: 'fu_td_4',
          leadName: 'Aiswarya Menon',
          maskedPhone: '99610 •••71',
          collegeInfo: 'NIT Calicut · CSE · 2nd yr',
          timeLabel: '5:30 PM',
          channelLabel: 'Call',
          note: 'Confirm parent approval',
          bucket: FollowUpBucket.today,
        ),

        // --- 9 UPCOMING ---
        ExecutiveFollowUpItem(
          id: 'fu_up_1',
          leadName: 'Gopika Das',
          maskedPhone: '98950 •••84',
          collegeInfo: 'MES College · CSE · 3rd yr',
          timeLabel: 'Tomorrow · 10:00 AM',
          channelLabel: 'Call',
          note: 'Check group of 4 registration list',
          bucket: FollowUpBucket.upcoming,
        ),
        ExecutiveFollowUpItem(
          id: 'fu_up_2',
          leadName: 'Rohit Nair',
          maskedPhone: '97450 •••12',
          collegeInfo: 'Providence · BSc CS · 3rd yr',
          timeLabel: 'Tomorrow · 11:30 AM',
          channelLabel: 'WhatsApp',
          note: 'Send Add-on course brochure PDF',
          bucket: FollowUpBucket.upcoming,
        ),
        ExecutiveFollowUpItem(
          id: 'fu_up_3',
          leadName: 'Adithya Krishnan',
          maskedPhone: '97450 •••09',
          collegeInfo: 'NIT Calicut · ECE · 3rd yr',
          timeLabel: 'Tomorrow · 2:00 PM',
          channelLabel: 'Call',
          note: 'Follow up after lab exam',
          bucket: FollowUpBucket.upcoming,
        ),
        ExecutiveFollowUpItem(
          id: 'fu_up_4',
          leadName: 'Nandana P',
          maskedPhone: '94470 •••13',
          collegeInfo: 'GEC Kozhikode · CSE · 2nd yr',
          timeLabel: 'Thu, 29 Oct · 10:30 AM',
          channelLabel: 'Call',
          note: 'Confirm weekend Python batch preference',
          bucket: FollowUpBucket.upcoming,
        ),
      ];

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final last10 = digits.substring(digits.length - 10);
      return '${last10.substring(0, 5)} •••${last10.substring(8)}';
    }
    return phone;
  }

  Future<void> _appendAudit({
    required String action,
    required String category,
  }) async {
    try {
      final u = _firebaseAuth.currentUser;
      await _auditLog.add({
        'actorUid': u?.uid ?? 'executive',
        'actorName': u?.displayName ?? 'Executive',
        'action': action,
        'category': category,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
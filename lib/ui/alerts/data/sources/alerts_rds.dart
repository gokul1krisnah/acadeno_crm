import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/alert_models.dart';

/// Remote data source for executive notifications connected to live Firestore data.
class AlertsRds {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  AlertsRds({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<List<ExecutiveAlertItem>> watchAlerts({String? executiveUid}) async* {
    final authUser = _firebaseAuth.currentUser;
    final uid = executiveUid ?? authUser?.uid ?? '';

    // Fetch the real user profile name from Firestore
    String userName = authUser?.displayName?.trim() ?? '';
    if (uid.isNotEmpty) {
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final profileName = (userDoc.data()?['name'] ?? '').toString().trim();
          if (profileName.isNotEmpty) {
            userName = profileName;
          }
        }
      } catch (_) {}
    }
    if (userName.isEmpty) {
      final email = authUser?.email?.trim() ?? '';
      userName = email.isNotEmpty ? email.split('@').first : 'Executive';
    }
    final firstName = userName.split(' ').first;

    // Stream real live leads and alerts from Firestore
    yield* _firestore.collection('leads').snapshots().asyncMap((leadSnap) async {
      final liveAlerts = <ExecutiveAlertItem>[];

      // 1. Fetch real stored alerts (lead assignments, reassignments, admin notices)
      try {
        Query<Map<String, dynamic>> query = _firestore
            .collection('alerts')
            .orderBy('createdAt', descending: true)
            .limit(30);

        final alertDocsSnap = await query.get();
        for (final doc in alertDocsSnap.docs) {
          final data = doc.data();
          final recUid = (data['recipientUid'] ?? '').toString();
          if (recUid != uid && recUid != 'all' && recUid.isNotEmpty) {
            continue; // Not for this executive
          }

          final isRead = data['isRead'] as bool? ?? false;
          final title = (data['title'] ?? 'Notification').toString();
          final subtitle = (data['subtitle'] ?? '').toString();
          final category = (data['category'] ?? '').toString();
          final dateLabel = (data['dateLabel'] ?? 'Today').toString();

          AlertIconType icon = AlertIconType.list;
          if (category == 'assignment') icon = AlertIconType.list;
          if (category == 'followup') icon = AlertIconType.clock;
          if (category == 'overdue') icon = AlertIconType.warning;

          liveAlerts.add(
            ExecutiveAlertItem(
              id: doc.id,
              title: title,
              subtitle: subtitle,
              timeLabel: dateLabel,
              iconType: icon,
              isToday: true,
              isUnread: !isRead,
              targetTabIndex: category == 'followup' ? 1 : 0,
            ),
          );
        }
      } catch (_) {}

      // 2. Filter real leads assigned to this executive
      final leads = leadSnap.docs;
      final myLeads = leads.where((d) {
        final data = d.data();
        final assignedUid = (data['assignedToUid'] ?? '').toString();
        final assignedName = (data['assignedToName'] ?? data['assignedTo'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final matchesUser = (uid.isNotEmpty && assignedUid == uid) ||
            (userName.isNotEmpty && assignedName == userName.toLowerCase());
        return uid.isEmpty || matchesUser;
      }).toList();

      final pendingLeads =
          myLeads.where((d) => (d.data()['isDone'] as bool?) != true).toList();
      final pendingCount = pendingLeads.length;

      // Real follow-ups
      final followUpLeads = myLeads.where((d) {
        final status = (d.data()['status'] ?? '').toString().toLowerCase();
        return status == 'follow-up' ||
            status == 'callback' ||
            status == 'interested';
      }).toList();

      // Real overdue leads
      final overdueLeads = myLeads.where((d) {
        final status = (d.data()['status'] ?? '').toString().toLowerCase();
        final followUpTime =
            (d.data()['followUpTime'] ?? '').toString().toLowerCase();
        return status == 'overdue' || followUpTime.contains('yesterday');
      }).toList();

      // 3. Dynamic Greeting Card: ONLY shown if there are real assigned tasks or follow-ups
      if (pendingCount > 0 || followUpLeads.isNotEmpty || overdueLeads.isNotEmpty) {
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

        liveAlerts.insert(
          0,
          ExecutiveAlertItem(
            id: 'al_greeting_${uid.isEmpty ? "me" : uid}',
            title: '$greeting, $firstName',
            subtitle:
                '$pendingCount calls assigned · ${followUpLeads.length} follow-ups today · ${overdueLeads.length} overdue',
            timeLabel: 'Today',
            iconType: AlertIconType.sun,
            isToday: true,
            isUnread: true,
            targetTabIndex: 0,
          ),
        );
      }

      // 4. Real Overdue follow-up alerts (linked to actual students)
      for (final doc in overdueLeads) {
        final data = doc.data();
        final name = (data['name'] ?? 'Student').toString();
        final timeLabel =
            (data['followUpTime'] ?? 'Was due earlier').toString();
        liveAlerts.add(
          ExecutiveAlertItem(
            id: 'al_od_${doc.id}',
            title: 'Overdue follow-up: $name',
            subtitle: '$timeLabel · Requires immediate callback',
            timeLabel: 'Overdue',
            iconType: AlertIconType.warning,
            isToday: false,
            isUnread: true,
            targetTabIndex: 1,
            targetLeadName: name,
          ),
        );
      }

      // 5. Real Scheduled Follow-ups (linked to actual students)
      for (final doc in followUpLeads) {
        final data = doc.data();
        final name = (data['name'] ?? 'Student').toString();
        final timeLabel = (data['followUpTime'] ?? 'Scheduled').toString();
        final course =
            (data['course'] ?? data['courseEnrolled'] ?? 'course inquiry')
                .toString();
        liveAlerts.add(
          ExecutiveAlertItem(
            id: 'al_fu_${doc.id}',
            title: 'Follow-up: $name',
            subtitle: '$timeLabel · Call · Follow up regarding $course',
            timeLabel: 'Today',
            iconType: AlertIconType.clock,
            isToday: true,
            isUnread: true,
            targetTabIndex: 1,
            targetLeadName: name,
          ),
        );
      }

      return liveAlerts;
    });
  }

  /// Mark all alerts as read for the user in Firestore
  Future<void> markAllAlertsRead({String? executiveUid}) async {
    final uid = executiveUid ?? _firebaseAuth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final snap = await _firestore
          .collection('alerts')
          .where('recipientUid', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (_) {}
  }

  /// Mark a single alert as read
  Future<void> markAlertRead(String alertId) async {
    if (alertId.isEmpty) return;
    try {
      await _firestore.collection('alerts').doc(alertId).update({'isRead': true});
    } catch (_) {}
  }

  /// Returns empty list initially until live Firestore data streams in.
  List<ExecutiveAlertItem> fetchAlerts() => const <ExecutiveAlertItem>[];
}

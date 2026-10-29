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
      userName = email.isNotEmpty ? email.split('@').first : 'Team Member';
    }
    final firstName = userName.split(' ').first;

    // Stream real live leads from Firestore
    yield* _firestore.collection('leads').snapshots().map((leadSnap) {
      final liveAlerts = <ExecutiveAlertItem>[];
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

      // Real Alert 1: Morning Briefing Greeting for currently authenticated user
      liveAlerts.add(
        ExecutiveAlertItem(
          id: 'al_greeting_${uid.isEmpty ? "me" : uid}',
          title: 'Good morning, $firstName',
          subtitle:
              '$pendingCount calls assigned · ${followUpLeads.length} follow-ups today · ${overdueLeads.length} overdue',
          timeLabel: '9:00',
          iconType: AlertIconType.sun,
          isToday: true,
          isUnread: true,
          targetTabIndex: 0,
        ),
      );

      // Real Alert 2: Real Active Call Queue
      if (pendingCount > 0) {
        liveAlerts.add(
          ExecutiveAlertItem(
            id: 'al_live_assigned',
            title: '$pendingCount leads in your call queue',
            subtitle:
                'Open your today call sheet to start calling student inquiries',
            timeLabel: 'Active',
            iconType: AlertIconType.list,
            isToday: true,
            isUnread: true,
            targetTabIndex: 0,
          ),
        );
      }

      // Real Alert 3: Real Overdue follow-up alerts
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

      // Real Alert 4: Real Scheduled Follow-ups
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

  /// No fake data. Returns empty list initially until real Firestore data is emitted.
  List<ExecutiveAlertItem> fetchAlerts() => const <ExecutiveAlertItem>[];
}

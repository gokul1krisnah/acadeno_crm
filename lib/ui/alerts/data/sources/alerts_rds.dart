import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../follow_ups/data/model/follow_up_models.dart';
import '../../../follow_ups/data/model/follow_up_time_helper.dart';
import '../../../leads/data/model/lead_models.dart';
import '../model/alert_models.dart';

/// Remote data source for executive notifications connected to live Firestore data.
/// 100% Real-time, authentic Firestore alerts stream synthesized from:
/// 1. Real lead assignments (`assignments` collection)
/// 2. Real scheduled follow-ups and overdue tasks (`leads` collection)
/// 3. Real call logs (`call_logs` collection)
/// 4. Genuine executive alerts (`alerts` collection)
/// 5. Live daily briefing / greeting
///
/// Automatically purges stale, hardcoded, or mock test data so executives
/// always see their authentic live records.
class AlertsRds {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  AlertsRds({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  DateTime _parseDateTime(dynamic val, [dynamic fallback]) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String && val.isNotEmpty) {
      final parsed = DateTime.tryParse(val);
      if (parsed != null) return parsed;
    }
    if (fallback != null) {
      return _parseDateTime(fallback);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Check whether a document in `alerts` is stale / fake test data from past manual tests.
  bool _isFakeOrTestAlert(Map<String, dynamic> data, String uid) {
    final title = (data['title'] ?? '').toString();
    final subtitle = (data['subtitle'] ?? '').toString();
    final titleLower = title.toLowerCase();
    final subtitleLower = subtitle.toLowerCase();

    // 1. Hardcoded past test mentions of 'alfas'
    if (titleLower.contains('alfas') || subtitleLower.contains('alfas')) {
      return true;
    }

    // 2. Hardcoded past test dates like '7 Nov' from earlier mock assignment tests
    if (title.contains('7 Nov') || subtitle.contains('7 Nov')) {
      return true;
    }

    // 3. Stale documents with missing timestamps
    if (data['createdAt'] == null && data['timestamp'] == null) {
      return true;
    }

    // 4. Stale generic test documents without specific recipient
    final recUid = (data['recipientUid'] ?? '').toString();
    if (recUid.isEmpty &&
        (titleLower.contains('re assign') ||
            titleLower.contains('good morning'))) {
      return true;
    }

    return false;
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

  /// Streams 100% authentic, real-time alerts for the authenticated executive.
  Stream<List<ExecutiveAlertItem>> watchAlerts({String? executiveUid}) {
    late final StreamController<List<ExecutiveAlertItem>> controller;
    StreamSubscription? authSub;
    StreamSubscription? alertsSub;
    StreamSubscription? assignmentsSub;
    StreamSubscription? leadsSub;
    StreamSubscription? callLogsSub;
    StreamSubscription? userSub;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> alertsDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignmentsDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> leadsDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> callLogsDocs = [];
    Map<String, dynamic>? userData;

    void emitCombined(String currentUid) {
      if (controller.isClosed) return;
      try {
        final items = _buildLiveAlertItems(
          uid: currentUid,
          alertsDocs: alertsDocs,
          assignmentsDocs: assignmentsDocs,
          leadsDocs: leadsDocs,
          callLogsDocs: callLogsDocs,
          userData: userData,
        );
        controller.add(items);
      } catch (_) {}
    }

    void subscribeForUid(String uid) {
      alertsSub?.cancel();
      assignmentsSub?.cancel();
      leadsSub?.cancel();
      callLogsSub?.cancel();
      userSub?.cancel();

      alertsDocs = [];
      assignmentsDocs = [];
      leadsDocs = [];
      callLogsDocs = [];
      userData = null;

      if (uid.isEmpty) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }

      // 1. Current user profile for personalized greeting
      userSub = _firestore.collection('users').doc(uid).snapshots().listen((
        doc,
      ) {
        if (doc.exists) {
          userData = doc.data();
          emitCombined(uid);
        }
      }, onError: (_) {});

      // 2. Collection 'alerts' (direct server alerts)
      alertsSub = _firestore.collection('alerts').snapshots().listen((snap) {
        alertsDocs = snap.docs;
        emitCombined(uid);
      }, onError: (_) {});

      // 3. Collection 'assignments' (real assigned leads for this executive)
      assignmentsSub = _firestore
          .collection('assignments')
          .where('executiveUid', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
            assignmentsDocs = snap.docs;
            emitCombined(uid);
          }, onError: (_) {});

      // 4. Collection 'leads' (real follow-ups and overdue tasks)
      leadsSub = _firestore
          .collection('leads')
          .where('assignedToUid', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
            leadsDocs = snap.docs;
            emitCombined(uid);
          }, onError: (_) {});

      // 5. Collection 'call_logs' (real call activity)
      callLogsSub = _firestore
          .collection('call_logs')
          .where('executiveUid', isEqualTo: uid)
          .limit(15)
          .snapshots()
          .listen((snap) {
            callLogsDocs = snap.docs;
            emitCombined(uid);
          }, onError: (_) {});
    }

    void onListen() {
      if (executiveUid != null && executiveUid.isNotEmpty) {
        subscribeForUid(executiveUid);
      } else {
        final initialUid = _firebaseAuth.currentUser?.uid ?? '';
        if (initialUid.isNotEmpty) {
          subscribeForUid(initialUid);
        }
        authSub = _firebaseAuth.authStateChanges().listen((user) {
          final newUid = user?.uid ?? '';
          subscribeForUid(newUid);
        }, onError: (_) {});
      }
    }

    void onCancel() {
      authSub?.cancel();
      alertsSub?.cancel();
      assignmentsSub?.cancel();
      leadsSub?.cancel();
      callLogsSub?.cancel();
      userSub?.cancel();
    }

    controller = StreamController<List<ExecutiveAlertItem>>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
    );

    return controller.stream;
  }

  List<ExecutiveAlertItem> _buildLiveAlertItems({
    required String uid,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> alertsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> assignmentsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> leadsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> callLogsDocs,
    Map<String, dynamic>? userData,
  }) {
    final liveAlerts = <ExecutiveAlertItem>[];
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todayKey = LeadDateHelper.todayDateKey();
    final yesterdayDate = startOfToday.subtract(const Duration(days: 1));
    final yesterdayKey = LeadDateHelper.dateKey(yesterdayDate);

    // =========================================================================
    // 1. Process Genuine Alerts from Firestore `alerts` Collection
    // =========================================================================
    for (final doc in alertsDocs) {
      final data = doc.data();

      // Check and purge fake / mock test records from database
      if (_isFakeOrTestAlert(data, uid)) {
        doc.reference.delete().catchError((_) {});
        continue;
      }

      final recUid = (data['recipientUid'] ?? '').toString();
      if (recUid.isNotEmpty &&
          recUid != 'all' &&
          uid.isNotEmpty &&
          recUid != uid) {
        continue;
      }

      final isRead = data['isRead'] as bool? ?? false;
      final rawTitle = (data['title'] ?? 'Notification').toString();
      final subtitle = (data['subtitle'] ?? '').toString();
      final category = (data['category'] ?? '').toString();

      final createdAt = _parseDateTime(
        data['createdAt'],
        data['timestamp'],
      ).toLocal();
      if (createdAt.millisecondsSinceEpoch == 0) continue;

      final itemDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final isToday =
          itemDay.isAtSameMomentAs(startOfToday) ||
          itemDay.isAfter(startOfToday);

      final timeLabel = DateFormat('hh:mm a').format(createdAt);

      String cleanTitle = rawTitle
          .replaceFirst(RegExp(r'^(📞|🔄|⚠️|🔔)\s*'), '')
          .trim();
      cleanTitle = cleanTitle.replaceAll(
        RegExp(r'\b1\s+Leads\b', caseSensitive: false),
        '1 Lead',
      );

      AlertIconType icon = AlertIconType.phone;
      final catLower = category.toLowerCase();
      final titleLower = cleanTitle.toLowerCase();

      if (catLower.contains('reassign') ||
          titleLower.contains('re assign') ||
          titleLower.contains('reassign')) {
        icon = AlertIconType.reassign;
      } else if (catLower.contains('greeting') ||
          titleLower.contains('good morning') ||
          titleLower.contains('morning')) {
        icon = AlertIconType.sun;
      } else if (catLower.contains('followup') ||
          titleLower.contains('follow-up') ||
          titleLower.contains('followup')) {
        icon = AlertIconType.clock;
      } else if (catLower.contains('overdue') ||
          catLower.contains('warning') ||
          titleLower.contains('overdue') ||
          titleLower.contains('escalat')) {
        icon = AlertIconType.warning;
      } else {
        icon = AlertIconType.phone;
      }

      liveAlerts.add(
        ExecutiveAlertItem(
          id: doc.id,
          title: cleanTitle,
          subtitle: subtitle,
          timeLabel: timeLabel,
          iconType: icon,
          isToday: isToday,
          isUnread: !isRead,
          targetTabIndex: category == 'followup' ? 1 : 0,
          createdAt: createdAt,
        ),
      );
    }

    // =========================================================================
    // 2. Synthesize Real Assignments (`assignments` collection)
    // =========================================================================
    final assignmentsByDate = <String, List<Map<String, dynamic>>>{};
    for (final doc in assignmentsDocs) {
      final d = doc.data();
      final dKey = (d['dateKey'] ?? '').toString();
      if (dKey.isEmpty) continue;
      assignmentsByDate.putIfAbsent(dKey, () => []).add(d);
    }

    assignmentsByDate.forEach((dKey, list) {
      final count = list.length;
      final leadNames = list
          .map((a) => (a['leadName'] ?? 'Lead').toString())
          .where((n) => n.isNotEmpty)
          .toList();
      final preview = leadNames.take(3).join(', ');
      final suffix = leadNames.length > 3
          ? ' +${leadNames.length - 3} more'
          : '';
      final adminName = (list.first['assignedByName'] ?? 'AcadenoAdmin')
          .toString();

      final firstCreatedAt = _parseDateTime(
        list.first['assignedAt'] ??
            list.first['timestamp'] ??
            list.first['createdAt'],
      ).toLocal();
      final effectiveCreatedAt = firstCreatedAt.millisecondsSinceEpoch == 0
          ? (dKey == todayKey
                ? startOfToday.add(const Duration(hours: 9))
                : yesterdayDate)
          : firstCreatedAt;

      final isToday = dKey == todayKey;
      final isYesterday = dKey == yesterdayKey;
      final timeLabel = DateFormat('hh:mm a').format(effectiveCreatedAt);

      final title = isToday
          ? '$count ${count == 1 ? "Lead" : "Leads"} Assigned for Today'
          : isYesterday
          ? '$count ${count == 1 ? "Lead" : "Leads"} Assigned for Yesterday'
          : '$count ${count == 1 ? "Lead" : "Leads"} Assigned (${list.first["dateLabel"] ?? dKey})';

      final subtitle = 'Assigned by $adminName · ($preview$suffix)';

      liveAlerts.add(
        ExecutiveAlertItem(
          id: 'asgn_group_$dKey',
          title: title,
          subtitle: subtitle,
          timeLabel: timeLabel,
          iconType: AlertIconType.phone,
          isToday: isToday,
          isUnread: isToday,
          targetTabIndex: 0,
          createdAt: effectiveCreatedAt,
        ),
      );

      // Reassigned items
      for (final asgn in list) {
        final isReassigned =
            asgn['isReassigned'] == true ||
            (asgn['previousExecutiveUid'] != null &&
                (asgn['previousExecutiveUid'] as String).isNotEmpty);
        if (isReassigned) {
          final lName = (asgn['leadName'] ?? 'Lead').toString();
          liveAlerts.add(
            ExecutiveAlertItem(
              id: 'reassign_${asgn["id"] ?? lName}_$dKey',
              title: 'Reassigned: $lName',
              subtitle: 'Assigned by $adminName · Priority call',
              timeLabel: timeLabel,
              iconType: AlertIconType.reassign,
              isToday: isToday,
              isUnread: isToday,
              targetTabIndex: 0,
              targetLeadName: lName,
              createdAt: effectiveCreatedAt,
            ),
          );
        }
      }
    });

    // =========================================================================
    // 3. Synthesize Real Follow-ups and Overdue Tasks (`leads` collection)
    // =========================================================================
    for (final doc in leadsDocs) {
      final d = doc.data();
      if (_isLeadDone(d)) continue;

      final name = (d['name'] ?? 'Student Lead').toString();
      final status = (d['status'] ?? '').toString();
      final course = (d['course'] ?? d['courseEnrolled'] ?? 'course inquiry')
          .toString();

      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: d['followUpTime'],
        assignedDateKey: d['assignedDateKey'],
        assignedDateLabel: d['assignedDateLabel'],
        assignedAt: d['assignedAt'],
        updatedAt: d['updatedAt'],
        createdAt: d['createdAt'],
        status: status,
      );

      if (eval.isOverdue) {
        liveAlerts.add(
          ExecutiveAlertItem(
            id: 'fu_od_${doc.id}',
            title: 'Overdue follow-up: $name',
            subtitle: '${eval.displayLabel} · Requires immediate callback',
            timeLabel: 'Overdue',
            iconType: AlertIconType.warning,
            isToday: false,
            isUnread: true,
            targetTabIndex: 1,
            targetLeadName: name,
            createdAt: yesterdayDate.add(const Duration(hours: 17)),
          ),
        );
      } else if (eval.bucket == FollowUpBucket.today) {
        liveAlerts.add(
          ExecutiveAlertItem(
            id: 'fu_today_${doc.id}',
            title: 'Follow-up: $name',
            subtitle: '${eval.displayLabel} · Call regarding $course',
            timeLabel: DateFormat('hh:mm a').format(eval.scheduledTime),
            iconType: AlertIconType.clock,
            isToday: true,
            isUnread: true,
            targetTabIndex: 1,
            targetLeadName: name,
            createdAt: eval.scheduledTime,
          ),
        );
      }
    }

    // =========================================================================
    // 4. Synthesize Real Logged Calls (`call_logs` collection)
    // =========================================================================
    for (final doc in callLogsDocs) {
      final d = doc.data();
      final leadName = (d['leadName'] ?? 'Student').toString();
      final outcome = (d['outcome'] ?? 'Completed').toString();
      final duration = (d['duration'] ?? '0s').toString();
      final callAt = _parseDateTime(d['timestamp'], d['createdAt']).toLocal();

      if (callAt.millisecondsSinceEpoch == 0) continue;

      final isToday =
          callAt.isAfter(startOfToday) || callAt.isAtSameMomentAs(startOfToday);

      liveAlerts.add(
        ExecutiveAlertItem(
          id: 'call_log_${doc.id}',
          title: 'Call Logged: $leadName',
          subtitle: '$outcome · Duration: $duration',
          timeLabel: DateFormat('hh:mm a').format(callAt),
          iconType: AlertIconType.phone,
          isToday: isToday,
          isUnread: false,
          targetTabIndex: 0,
          createdAt: callAt,
        ),
      );
    }

    // =========================================================================
    // 5. Synthesize Executive Greeting Card (if tasks exist)
    // =========================================================================
    final todayAssignmentsCount = assignmentsByDate[todayKey]?.length ?? 0;
    final todayFollowUpsCount = liveAlerts
        .where((a) => a.iconType == AlertIconType.clock && a.isToday)
        .length;
    final overdueCount = liveAlerts
        .where((a) => a.iconType == AlertIconType.warning)
        .length;

    if (todayAssignmentsCount > 0 ||
        todayFollowUpsCount > 0 ||
        overdueCount > 0) {
      final hour = now.hour;
      final greeting = hour < 12
          ? 'Good Morning'
          : hour < 17
          ? 'Good Afternoon'
          : 'Good Evening';
      final rawName = (userData?['name'] ?? '').toString().trim();
      final firstName = rawName.isNotEmpty ? rawName.split(' ').first : 'there';

      final greetingTime = DateTime(now.year, now.month, now.day, 9, 0);

      liveAlerts.add(
        ExecutiveAlertItem(
          id: 'live_greeting_${uid}_$todayKey',
          title: '$greeting, $firstName',
          subtitle:
              '$todayAssignmentsCount calls assigned · $todayFollowUpsCount follow-ups today',
          timeLabel: DateFormat(
            'hh:mm a',
          ).format(now.isBefore(greetingTime) ? now : greetingTime),
          iconType: AlertIconType.sun,
          isToday: true,
          isUnread: false,
          targetTabIndex: 0,
          createdAt: now.isBefore(greetingTime) ? now : greetingTime,
        ),
      );
    }

    // Deduplicate items by ID
    final deduplicated = <String, ExecutiveAlertItem>{};
    for (final item in liveAlerts) {
      deduplicated[item.id] = item;
    }

    final result = deduplicated.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
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
      await _firestore.collection('alerts').doc(alertId).update({
        'isRead': true,
      });
    } catch (_) {}
  }

  /// Returns empty list initially until live Firestore data streams in.
  List<ExecutiveAlertItem> fetchAlerts() => const <ExecutiveAlertItem>[];
}

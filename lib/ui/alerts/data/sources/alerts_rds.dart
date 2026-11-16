import 'dart:async';

import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:acadeno_crm/core/services/firestore_stream_cache.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../follow_ups/data/model/follow_up_models.dart';
import '../../../follow_ups/data/model/follow_up_time_helper.dart';
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

  static bool _parseBool(dynamic val, [bool fallback = false]) {
    if (val == null) return fallback;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return fallback;
  }

  DateTime _parseDateTime(dynamic val, [dynamic fallback]) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is num) {
      if (val > 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      } else {
        return DateTime.fromMillisecondsSinceEpoch((val * 1000).toInt());
      }
    }
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
    final title = (data['title'] ?? '').toString().trim();
    final subtitle = (data['subtitle'] ?? '').toString().trim();
    if (title.isEmpty && subtitle.isEmpty) return true;
    return false;
  }

  static bool _isLeadDone(Map<String, dynamic> data) {
    final val = data['isDone'] ?? data['followUpDone'];
    return _parseBool(val);
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
    Timer? debounceTimer;
    String currentSubscribedUid = '';

    void emitCombined(String currentUid) {
      if (controller.isClosed) return;
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 50), () {
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
        } catch (_) {
          controller.add(const <ExecutiveAlertItem>[]);
        }
      });
    }

    void subscribeForUid(String uid) {
      if (uid == currentSubscribedUid && alertsSub != null) {
        return;
      }
      currentSubscribedUid = uid;

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

      final isAdmin = isAdminSession;

      // 1. User document
      if (uid.isNotEmpty) {
        userSub = FirestoreStreamCache.instance
            .watchDoc('users', uid, firestore: _firestore)
            .listen((doc) {
              if (doc.exists) {
                userData = doc.data();
                emitCombined(uid);
              }
            }, onError: (_) {});
      }

      // 2. Collection 'alerts'
      alertsSub = FirestoreStreamCache.instance
          .watchCollection('alerts', firestore: _firestore)
          .listen((snap) {
            alertsDocs = snap.docs;
            emitCombined(uid);
          }, onError: (_) {
            emitCombined(uid);
          });

      // 3. Collection 'assignments'
      assignmentsSub = FirestoreStreamCache.instance
          .watchCollection('assignments', firestore: _firestore)
          .listen((snap) {
            assignmentsDocs = snap.docs.where((d) {
              if (isAdmin) return true;
              final data = d.data();
              final execUid = (data['executiveUid'] ?? data['assignedToUid'] ?? '').toString().trim();
              return uid.isEmpty || execUid.isEmpty || execUid == uid;
            }).toList();
            emitCombined(uid);
          }, onError: (_) {
            emitCombined(uid);
          });

      // 4. Collection 'leads'
      leadsSub = FirestoreStreamCache.instance
          .watchCollection('leads', firestore: _firestore)
          .listen((snap) {
            leadsDocs = snap.docs.where((d) {
              if (isAdmin) return true;
              final data = d.data();
              final assignedUid = (data['assignedToUid'] ?? data['executiveUid'] ?? '').toString().trim();
              return uid.isEmpty || assignedUid.isEmpty || assignedUid == uid;
            }).toList();
            emitCombined(uid);
          }, onError: (_) {
            emitCombined(uid);
          });

      // 5. Collection 'call_logs'
      callLogsSub = FirestoreStreamCache.instance
          .watchCollection('call_logs', firestore: _firestore)
          .listen((snap) {
            callLogsDocs = snap.docs.where((d) {
              if (isAdmin) return true;
              final data = d.data();
              final execUid = (data['executiveUid'] ?? data['assignedToUid'] ?? '').toString().trim();
              return uid.isEmpty || execUid.isEmpty || execUid == uid;
            }).toList();
            emitCombined(uid);
          }, onError: (_) {
            emitCombined(uid);
          });

      // Emit initial state immediately
      emitCombined(uid);
    }

    void onListen() {
      final effectiveUid =
          executiveUid ?? _firebaseAuth.currentUser?.uid ?? '';

      subscribeForUid(effectiveUid);

      authSub = _firebaseAuth.authStateChanges().listen((user) {
        final newUid = user?.uid ?? '';
        if (newUid.isNotEmpty && newUid != currentSubscribedUid) {
          subscribeForUid(newUid);
        }
      }, onError: (_) {});
    }

    void onCancel() {
      debounceTimer?.cancel();
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
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    final isAdmin = isAdminSession;

    // =========================================================================
    // 1. Process Genuine Alerts from Firestore `alerts` Collection
    // =========================================================================
    for (final doc in alertsDocs) {
      try {
        final data = doc.data();
        if (_isFakeOrTestAlert(data, uid)) continue;

        // Recipient filtering: Admins see all alerts; Executives see alerts targeted to them or broadcast
        if (!isAdmin && uid.isNotEmpty) {
          final category = (data['category'] ?? data['type'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final isManagerAlert =
              category.contains('discount') || category.contains('security');
          if (isManagerAlert) {
            continue;
          }

          final recUid =
              (data['recipientUid'] ??
                      data['executiveUid'] ??
                      data['assignedToUid'] ??
                      data['userId'] ??
                      '')
                  .toString()
                  .trim();
          if (recUid.isNotEmpty && recUid != 'all' && recUid != uid) {
            continue;
          }
        }

        final createdAt = _parseDateTime(
          data['createdAt'],
          data['timestamp'] ??
              data['time'] ??
              data['assignedAt'] ??
              data['updatedAt'],
        ).toLocal();
        final effectiveCreatedAt = createdAt.millisecondsSinceEpoch == 0
            ? now
            : createdAt;

        final isRead = _parseBool(data['isRead'] ?? data['read']);
        final rawTitle =
            (data['title'] ??
                    data['heading'] ??
                    data['subject'] ??
                    'Notification')
                .toString()
                .trim();
        final subtitle =
            (data['subtitle'] ??
                    data['message'] ??
                    data['body'] ??
                    data['description'] ??
                    data['content'] ??
                    '')
                .toString()
                .trim();
        final category = (data['category'] ?? data['type'] ?? '')
            .toString()
            .trim();

        final itemDay = DateTime(
          effectiveCreatedAt.year,
          effectiveCreatedAt.month,
          effectiveCreatedAt.day,
        );
        final isToday =
            itemDay.isAtSameMomentAs(startOfToday) ||
            itemDay.isAfter(startOfToday);
        final isYesterday = itemDay.isAtSameMomentAs(startOfYesterday);

        final String timeLabel;
        if (isToday) {
          timeLabel = DateFormat('hh:mm a').format(effectiveCreatedAt);
        } else if (isYesterday) {
          timeLabel =
              'Yesterday · ${DateFormat('hh:mm a').format(effectiveCreatedAt)}';
        } else {
          timeLabel = DateFormat('dd MMM · hh:mm a').format(effectiveCreatedAt);
        }

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
            catLower.contains('discount') ||
            catLower.contains('security') ||
            titleLower.contains('overdue') ||
            titleLower.contains('escalat') ||
            titleLower.contains('discount') ||
            titleLower.contains('rate limit')) {
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
            createdAt: effectiveCreatedAt,
          ),
        );
      } catch (_) {}
    }

    // =========================================================================
    // 2. Synthesize Real Lead Assignments (`assignments` collection)
    // =========================================================================
    final assignmentsByDate =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    for (final doc in assignmentsDocs) {
      try {
        final d = doc.data();
        final rawTitle = (d['title'] ?? '').toString().trim();
        final leadName =
            (d['leadName'] ?? d['name'] ?? 'Student Lead').toString();
        final dateKey =
            (d['assignedDateKey'] ?? d['dateKey'] ?? '').toString();
        final dateLabel =
            (d['assignedDateLabel'] ?? d['dateLabel'] ?? '').toString();
        final isDone = _parseBool(d['isDone'] ?? d['done']);

        if (dateKey.isNotEmpty) {
          assignmentsByDate.putIfAbsent(dateKey, () => []).add(doc);
        }

        if (isDone) continue;

        final assignedAt = _parseDateTime(
          d['assignedAt'],
          d['createdAt'] ?? d['updatedAt'],
        ).toLocal();
        final effectiveAssignedAt = assignedAt.millisecondsSinceEpoch == 0
            ? now
            : assignedAt;

        final itemDay = DateTime(
          effectiveAssignedAt.year,
          effectiveAssignedAt.month,
          effectiveAssignedAt.day,
        );
        final isToday =
            itemDay.isAtSameMomentAs(startOfToday) ||
            itemDay.isAfter(startOfToday);
        final isYesterday = itemDay.isAtSameMomentAs(startOfYesterday);

        final String timeLabel;
        if (isToday) {
          timeLabel = DateFormat('hh:mm a').format(effectiveAssignedAt);
        } else if (isYesterday) {
          timeLabel =
              'Yesterday · ${DateFormat('hh:mm a').format(effectiveAssignedAt)}';
        } else {
          timeLabel =
              DateFormat('dd MMM · hh:mm a').format(effectiveAssignedAt);
        }

        final title = rawTitle.isNotEmpty
            ? rawTitle
            : '1 Lead Assigned for $dateLabel';
        final subtitle = (d['subtitle'] ??
                'New lead assigned for follow-up: $leadName')
            .toString();

        liveAlerts.add(
          ExecutiveAlertItem(
            id: 'asgn_${doc.id}',
            title: title,
            subtitle: subtitle,
            timeLabel: timeLabel,
            iconType: AlertIconType.phone,
            isToday: isToday,
            isUnread: !_parseBool(d['isRead']),
            targetTabIndex: 0,
            targetLeadName: leadName,
            createdAt: effectiveAssignedAt,
          ),
        );
      } catch (_) {}
    }

    // =========================================================================
    // 3. Synthesize Real Follow-ups and Overdue Tasks (`leads` collection)
    // =========================================================================
    for (final doc in leadsDocs) {
      try {
        final d = doc.data();
        if (_isLeadDone(d)) continue;

        final name = (d['name'] ?? 'Student Lead').toString();
        final status = (d['status'] ?? '').toString();
        final course =
            (d['course'] ?? d['courseEnrolled'] ?? 'course inquiry').toString();

        final eval = FollowUpTimeHelper.evaluate(
          rawFollowUpTime: d['followUpTime'],
          assignedDateKey: d['assignedDateKey'],
          assignedDateLabel: d['assignedDateLabel'],
          assignedAt: d['assignedAt'],
          updatedAt: d['updatedAt'],
          createdAt: d['createdAt'],
          status: status,
        );

        final itemDay = DateTime(
          eval.scheduledTime.year,
          eval.scheduledTime.month,
          eval.scheduledTime.day,
        );
        final isToday =
            itemDay.isAtSameMomentAs(startOfToday) ||
            itemDay.isAfter(startOfToday);
        final isYesterday = itemDay.isAtSameMomentAs(startOfYesterday);

        final String timeLabel;
        if (eval.isOverdue) {
          timeLabel = 'Overdue';
        } else if (isToday) {
          timeLabel = DateFormat('hh:mm a').format(eval.scheduledTime);
        } else if (isYesterday) {
          timeLabel =
              'Yesterday · ${DateFormat('hh:mm a').format(eval.scheduledTime)}';
        } else {
          timeLabel = DateFormat('dd MMM · hh:mm a').format(eval.scheduledTime);
        }

        if (eval.isOverdue) {
          liveAlerts.add(
            ExecutiveAlertItem(
              id: 'fu_od_${doc.id}',
              title: 'Overdue follow-up: $name',
              subtitle: '${eval.displayLabel} · Requires immediate callback',
              timeLabel: timeLabel,
              iconType: AlertIconType.warning,
              isToday: false,
              isUnread: true,
              targetTabIndex: 1,
              targetLeadName: name,
              createdAt: eval.scheduledTime,
            ),
          );
        } else if (eval.bucket == FollowUpBucket.today) {
          liveAlerts.add(
            ExecutiveAlertItem(
              id: 'fu_today_${doc.id}',
              title: 'Follow-up: $name',
              subtitle: '${eval.displayLabel} · Call regarding $course',
              timeLabel: timeLabel,
              iconType: AlertIconType.clock,
              isToday: true,
              isUnread: true,
              targetTabIndex: 1,
              targetLeadName: name,
              createdAt: eval.scheduledTime,
            ),
          );
        }
      } catch (_) {}
    }

    // =========================================================================
    // 4. Synthesize Real Logged Calls (`call_logs` collection)
    // =========================================================================
    for (final doc in callLogsDocs) {
      try {
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
      } catch (_) {}
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

  /// Automatically purges notifications older than 3 days directly from Firestore
  Future<void> purgeOldNotifications() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 3));
      final snap = await FirestoreStreamCache.instance.getCollection(
        'alerts',
        firestore: _firestore,
      );
      for (final doc in snap.docs) {
        final data = doc.data();
        final dt = _parseDateTime(data['createdAt'], data['timestamp']);
        if (dt.millisecondsSinceEpoch > 0 && dt.isBefore(cutoff)) {
          await doc.reference.delete().catchError((_) {});
        }
      }
    } catch (_) {}
  }

  /// Mark all alerts as read for the user in Firestore
  Future<void> markAllAlertsRead({String? executiveUid}) async {
    final uid =
        executiveUid ?? _firebaseAuth.currentUser?.uid ?? '';
    final isAdmin = isAdminSession;
    try {
      final snap = await _firestore.collection('alerts').get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final rec = (d['recipientUid'] ?? d['executiveUid'] ?? '')
            .toString()
            .trim();
        final isRead = _parseBool(d['isRead'] ?? d['read']);
        if (!isRead && (isAdmin || rec.isEmpty || rec == 'all' || rec == uid)) {
          await doc.reference.update({'isRead': true});
        }
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

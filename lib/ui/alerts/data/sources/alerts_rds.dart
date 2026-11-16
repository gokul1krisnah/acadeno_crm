import 'dart:async';

import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:acadeno_crm/core/services/firestore_stream_cache.dart';
import 'package:acadeno_crm/ui/auth/data/sources/auth_session_local_ds.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../follow_ups/data/model/follow_up_models.dart';
import '../../../follow_ups/data/model/follow_up_time_helper.dart';
import '../model/alert_models.dart';

/// Remote data source for real-time CRM notifications and alerts.
/// Streams 100% authentic, real-time alerts from Firestore:
/// 1. Authoritative Firestore `alerts` collection (Lead assignments, discount requests, security & system notices)
/// 2. Active scheduled follow-ups & overdue tasks from `leads` collection
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

  /// Streams 100% authentic, real-time alerts for the active user.
  Stream<List<ExecutiveAlertItem>> watchAlerts({String? executiveUid}) {
    late final StreamController<List<ExecutiveAlertItem>> controller;
    StreamSubscription? authSub;
    StreamSubscription? alertsSub;
    StreamSubscription? leadsSub;
    StreamSubscription? userSub;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> alertsDocs = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> leadsDocs = [];
    Map<String, dynamic>? userData;
    Timer? debounceTimer;

    void emitCombined(String currentUid, bool isAdmin) {
      if (controller.isClosed) return;
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 60), () {
        if (controller.isClosed) return;
        try {
          final items = _buildLiveAlertItems(
            uid: currentUid,
            isAdmin: isAdmin,
            alertsDocs: alertsDocs,
            leadsDocs: leadsDocs,
            userData: userData,
          );
          controller.add(items);
        } catch (_) {}
      });
    }

    void subscribeForUid(String uid, bool isAdmin) {
      alertsSub?.cancel();
      leadsSub?.cancel();
      userSub?.cancel();

      alertsDocs = [];
      leadsDocs = [];
      userData = null;

      // 1. Current user profile for greeting/context
      if (uid.isNotEmpty) {
        userSub = FirestoreStreamCache.instance
            .watchDoc('users', uid, firestore: _firestore)
            .listen((doc) {
              if (doc.exists) {
                userData = doc.data();
                emitCombined(uid, isAdmin);
              }
            }, onError: (_) {});
      }

      // 2. Collection 'alerts' (direct server alerts)
      alertsSub = FirestoreStreamCache.instance
          .watchCollection('alerts', firestore: _firestore)
          .listen((snap) {
            alertsDocs = snap.docs;
            emitCombined(uid, isAdmin);
          }, onError: (_) {});

      // 3. Collection 'leads' (real follow-ups and overdue tasks for executive)
      if (uid.isNotEmpty && !isAdmin) {
        leadsSub = FirestoreStreamCache.instance
            .watchQuery(
              'leads:assignedToUid:$uid',
              () => _firestore
                  .collection('leads')
                  .where('assignedToUid', isEqualTo: uid),
            )
            .listen((snap) {
              leadsDocs = snap.docs;
              emitCombined(uid, isAdmin);
            }, onError: (_) {});
      }
    }

    void onListen() {
      final saved = AuthSessionLocalDs().read();
      final effectiveUid = executiveUid ?? _firebaseAuth.currentUser?.uid ?? saved?.uid ?? '';
      final isAdmin = isAdminSession || (saved?.isAdmin ?? false);

      subscribeForUid(effectiveUid, isAdmin);

      authSub = _firebaseAuth.authStateChanges().listen((user) {
        final newUid = user?.uid ?? saved?.uid ?? '';
        subscribeForUid(newUid, isAdmin);
      }, onError: (_) {});
    }

    void onCancel() {
      debounceTimer?.cancel();
      authSub?.cancel();
      alertsSub?.cancel();
      leadsSub?.cancel();
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
    required bool isAdmin,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> alertsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> leadsDocs,
    Map<String, dynamic>? userData,
  }) {
    final liveAlerts = <ExecutiveAlertItem>[];
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    // =========================================================================
    // 1. Process Genuine Alerts from Firestore `alerts` Collection
    // =========================================================================
    for (final doc in alertsDocs) {
      final data = doc.data();

      // Recipient filtering: Admins see all alerts; Executives see alerts targeted to them or broadcast
      if (!isAdmin && uid.isNotEmpty) {
        final recUid = (data['recipientUid'] ??
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
        data['timestamp'] ?? data['time'] ?? data['assignedAt'] ?? data['updatedAt'],
      ).toLocal();
      final effectiveCreatedAt =
          createdAt.millisecondsSinceEpoch == 0 ? now : createdAt;

      final isRead = (data['isRead'] as bool?) ?? (data['read'] as bool?) ?? false;
      final rawTitle = (data['title'] ?? data['heading'] ?? data['subject'] ?? 'Notification').toString().trim();
      final subtitle = (data['subtitle'] ?? data['message'] ?? data['body'] ?? data['description'] ?? data['content'] ?? '').toString().trim();
      final category = (data['category'] ?? data['type'] ?? '').toString().trim();

      final itemDay = DateTime(effectiveCreatedAt.year, effectiveCreatedAt.month, effectiveCreatedAt.day);
      final isToday = itemDay.isAtSameMomentAs(startOfToday) || itemDay.isAfter(startOfToday);
      final isYesterday = itemDay.isAtSameMomentAs(startOfYesterday);

      final String timeLabel;
      if (isToday) {
        timeLabel = DateFormat('hh:mm a').format(effectiveCreatedAt);
      } else if (isYesterday) {
        timeLabel = 'Yesterday · ${DateFormat('hh:mm a').format(effectiveCreatedAt)}';
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
    }

    // =========================================================================
    // 2. Synthesize Real Follow-ups and Overdue Tasks from `leads` (if not already present in alerts)
    // =========================================================================
    for (final doc in leadsDocs) {
      final d = doc.data();
      if (_isLeadDone(d)) continue;

      final name = (d['name'] ?? 'Student Lead').toString();
      final status = (d['status'] ?? '').toString();
      final course = (d['course'] ?? d['courseEnrolled'] ?? 'course inquiry').toString();

      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: d['followUpTime'],
        assignedDateKey: d['assignedDateKey'],
        assignedDateLabel: d['assignedDateLabel'],
        assignedAt: d['assignedAt'],
        updatedAt: d['updatedAt'],
        createdAt: d['createdAt'],
        status: status,
      );

      final itemDay = DateTime(eval.scheduledTime.year, eval.scheduledTime.month, eval.scheduledTime.day);
      final isToday = itemDay.isAtSameMomentAs(startOfToday) || itemDay.isAfter(startOfToday);
      final isYesterday = itemDay.isAtSameMomentAs(startOfYesterday);

      final String timeLabel;
      if (eval.isOverdue) {
        timeLabel = 'Overdue';
      } else if (isToday) {
        timeLabel = DateFormat('hh:mm a').format(eval.scheduledTime);
      } else if (isYesterday) {
        timeLabel = 'Yesterday · ${DateFormat('hh:mm a').format(eval.scheduledTime)}';
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
    final saved = AuthSessionLocalDs().read();
    final uid = executiveUid ?? _firebaseAuth.currentUser?.uid ?? saved?.uid;
    final isAdmin = isAdminSession || (saved?.isAdmin ?? false);
    try {
      final query = isAdmin
          ? _firestore.collection('alerts').where('isRead', isEqualTo: false)
          : (uid != null && uid.isNotEmpty)
              ? _firestore
                  .collection('alerts')
                  .where('recipientUid', isEqualTo: uid)
                  .where('isRead', isEqualTo: false)
              : _firestore.collection('alerts').where('isRead', isEqualTo: false);
      final snap = await query.get();
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

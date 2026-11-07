import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../model/alert_models.dart';

/// Remote data source for executive notifications connected to live Firestore data.
/// 100% Real-time, authentic Firestore alerts stream with real timestamps.
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
    return DateTime.now();
  }

  /// Streams real-time alerts from Firestore `alerts` collection.
  Stream<List<ExecutiveAlertItem>> watchAlerts({String? executiveUid}) {
    final authUser = _firebaseAuth.currentUser;
    final uid = executiveUid ?? authUser?.uid ?? '';

    return _firestore
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          final liveAlerts = <ExecutiveAlertItem>[];
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);

          for (final doc in snap.docs) {
            final data = doc.data();
            final recUid = (data['recipientUid'] ?? '').toString();
            // Check recipient permission: this executive, or broadcast 'all', or empty
            if (recUid.isNotEmpty &&
                recUid != 'all' &&
                uid.isNotEmpty &&
                recUid != uid) {
              continue; // Not for this user
            }

            final isRead = data['isRead'] as bool? ?? false;
            final title = (data['title'] ?? 'Notification').toString();
            final subtitle = (data['subtitle'] ?? '').toString();
            final category = (data['category'] ?? '').toString();

            final createdAt = _parseDateTime(
              data['createdAt'],
              data['timestamp'],
            ).toLocal();
            final itemDay = DateTime(
              createdAt.year,
              createdAt.month,
              createdAt.day,
            );
            final isToday =
                itemDay.isAtSameMomentAs(startOfToday) ||
                itemDay.isAfter(startOfToday);

            final timeStr = DateFormat('hh:mm a').format(createdAt);
            final timeLabel = timeStr;

            String cleanTitle = title
                .replaceFirst(RegExp(r'^(📞|🔄|⚠️|🔔)\s*'), '')
                .trim();
            // Fix grammar: '1 Leads Assigned' -> '1 Lead Assigned'
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
      await _firestore.collection('alerts').doc(alertId).update({
        'isRead': true,
      });
    } catch (_) {}
  }

  /// Returns empty list initially until live Firestore data streams in.
  List<ExecutiveAlertItem> fetchAlerts() => const <ExecutiveAlertItem>[];
}

import 'package:intl/intl.dart';
import 'package:acadeno_crm/core/services/firestore_stream_cache.dart';
import 'package:acadeno_crm/core/services/offline_queue_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/visit_models.dart';

/// Remote data source for college visits connected directly to Cloud Firestore.
/// Guarantees live real-time sync between Admin Dashboard and Executive Home.
/// 100% Real-time, authentic Firestore college visits stream.
class VisitsRds {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  VisitsRds({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _visits =>
      _firestore.collection('college_visits');

  /// Streams real-time college visits from Firestore.
  Stream<List<ExecutiveCollegeVisit>> watchVisits({String? executiveUid}) {
    return FirestoreStreamCache.instance
        .watchCollection('college_visits', firestore: _firestore)
        .map((snap) {
      if (snap.docs.isEmpty) {
        return const <ExecutiveCollegeVisit>[];
      }
      return snap.docs.map((doc) {
        final data = doc.data();
        final status = (data['status'] ?? data['statusLabel'] ?? 'Planned')
            .toString();
        final rawInitials = data['staffInitials'];
        final staffNames = (data['staffNames'] ?? data['assignedStaff'] ?? '')
            .toString()
            .trim();

        List<String> staffInitials = rawInitials is List
            ? rawInitials
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : const [];

        if (staffInitials.isEmpty) {
          if (staffNames.isNotEmpty) {
            final parts = staffNames.split(RegExp(r'[,&]|\band\b'));
            final derived = <String>[];
            for (final part in parts) {
              final trimmed = part.trim();
              if (trimmed.isEmpty) continue;
              final words = trimmed.split(' ').where((w) => w.isNotEmpty).toList();
              if (words.length >= 2) {
                derived.add('${words.first[0]}${words.last[0]}'.toUpperCase());
              } else if (words.isNotEmpty && words.first.isNotEmpty) {
                derived.add(words.first[0].toUpperCase());
              }
            }
            staffInitials = derived.isNotEmpty ? derived : const ['EX'];
          } else {
            staffInitials = const ['EX'];
          }
        }

        final cancelReason =
            (data['cancelReason'] ?? data['outcomeNotes'] ?? '').toString();
        final isUpcoming = status.toLowerCase() != 'completed' &&
            status.toLowerCase() != 'cancelled' &&
            status.toLowerCase() != 'canceled';

        var dNum = (data['dayNumber'] ?? '').toString().trim();
        var mShort = (data['monthShort'] ?? '').toString().trim().toUpperCase();
        if (dNum.isEmpty || mShort.isEmpty) {
          final dl = (data['dateLabel'] ?? '').toString().trim();
          if (dl.isNotEmpty) {
            try {
              final parsed = DateFormat('d MMM yyyy').parse(dl);
              dNum = DateFormat('dd').format(parsed);
              mShort = DateFormat('MMM').format(parsed).toUpperCase();
            } catch (_) {
              final parts = dl.split(' ');
              if (parts.isNotEmpty) dNum = parts[0];
              if (parts.length > 1) mShort = parts[1].toUpperCase();
            }
          }
        }
        if (dNum.isEmpty) dNum = DateFormat('dd').format(DateTime.now());
        if (mShort.isEmpty) mShort = DateFormat('MMM').format(DateTime.now()).toUpperCase();

        return ExecutiveCollegeVisit(
          id: doc.id,
          monthShort: mShort,
          dayNumber: dNum,
          collegeName: (data['collegeName'] ?? '').toString(),
          subtitle: (data['subtitle'] ?? '').toString(),
          statusLabel: status,
          purpose: (data['purpose'] ?? '').toString(),
          sourceEvent:
              (data['sourceEvent'] ?? data['source'] ?? '').toString(),
          content:
              (data['content'] ?? data['eventContent'] ?? '').toString(),
          staffInitials: staffInitials,
          staffNames: staffNames.isNotEmpty ? staffNames : 'Assigned Staff',
          leadsCollected: (data['leadsCollected'] as num?)?.toInt() ?? 0,
          interestedCount: (data['interestedCount'] as num?)?.toInt() ?? 0,
          metSummary: (data['metSummary'] ?? data['outcomeNotes'] ?? '')
              .toString(),
          nextActionSummary: (data['nextActionSummary'] ?? '').toString(),
          cancelReason: cancelReason,
          isUpcoming: isUpcoming,
        );
      }).toList();
    });
  }

  /// Initial fallback visits: empty list so no fake data is displayed.
  List<ExecutiveCollegeVisit> fetchVisits() => const <ExecutiveCollegeVisit>[];

  /// Plans a new college visit in Firestore.
  Future<void> addCollegeVisit({
    required String collegeName,
    required String dayNumber,
    required String monthShort,
    required String subtitle,
    required String purpose,
    String sourceEvent = '',
    String content = '',
    String assignedStaff = '',
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    await _visits.add({
      'collegeName': collegeName.trim(),
      'dayNumber': dayNumber.trim(),
      'monthShort': monthShort.trim().toUpperCase(),
      'dateLabel': '${dayNumber.trim()} ${monthShort.trim().toUpperCase()}',
      'subtitle': subtitle.trim(),
      'purpose': purpose.trim(),
      'sourceEvent': sourceEvent.trim(),
      'content': content.trim(),
      'status': 'Planned',
      'statusLabel': 'Planned',
      'assignedStaff': assignedStaff.trim(),
      'staffNames': assignedStaff.trim(),
      'staffInitials': assignedStaff
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map(
            (s) => s
                .split(' ')
                .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                .join(),
          )
          .toList(),
      'leadsCollected': 0,
      'interestedCount': 0,
      'metSummary': '',
      'outcomeNotes': '',
      'nextActionSummary': '',
      'createdByUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Records outcome of an assigned college visit in Firestore.
  Future<void> recordVisitOutcome({
    required String visitId,
    required String metPeople,
    required String nextAction,
    required int leadsCollected,
    required int interestedCount,
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    try {
      await _visits.doc(visitId).set({
        'status': 'Completed',
        'statusLabel': 'Completed',
        'metSummary': metPeople.trim(),
        'outcomeNotes': metPeople.trim(),
        'nextActionSummary': nextAction.trim(),
        'leadsCollected': leadsCollected,
        'interestedCount': interestedCount,
        'updatedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      await OfflineQueueService.instance.enqueueVisitOutcome(
        visitId: visitId,
        metPeople: metPeople,
        nextAction: nextAction,
        leadsCollected: leadsCollected,
        interestedCount: interestedCount,
        executiveUid: uid,
      );
    }
  }

  /// Cancels an assigned college visit in Firestore.
  Future<void> cancelCollegeVisit({
    required String visitId,
    String reason = '',
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    await _visits.doc(visitId).set({
      'status': 'Cancelled',
      'statusLabel': 'Cancelled',
      'outcomeNotes': reason.trim().isNotEmpty
          ? reason.trim()
          : 'Visit cancelled',
      'cancelReason': reason.trim(),
      'updatedByUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Updates the status of an assigned college visit (e.g. Planned, Completed, Cancelled).
  Future<void> updateVisitStatus({
    required String visitId,
    required String status,
    String? reason,
    String? dayNumber,
    String? monthShort,
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    final Map<String, dynamic> updateData = {
      'status': status.trim(),
      'statusLabel': status.trim(),
      'updatedByUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (dayNumber != null && dayNumber.isNotEmpty) {
      updateData['dayNumber'] = dayNumber.trim();
    }
    if (monthShort != null && monthShort.isNotEmpty) {
      updateData['monthShort'] = monthShort.trim().toUpperCase();
    }
    if (status.trim().toLowerCase() == 'cancelled') {
      updateData['cancelReason'] =
          (reason != null && reason.trim().isNotEmpty) ? reason.trim() : 'Visit cancelled';
      updateData['outcomeNotes'] = updateData['cancelReason'];
    } else if (status.trim().toLowerCase() == 'planned') {
      updateData['cancelReason'] = '';
    }
    await _visits.doc(visitId).set(updateData, SetOptions(merge: true));
  }

  /// Permanently deletes a college visit from Firestore.
  Future<void> deleteCollegeVisit(String visitId) async {
    await _visits.doc(visitId).delete();
  }
}

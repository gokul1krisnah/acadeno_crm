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
    return _visits.snapshots().map((snap) {
      if (snap.docs.isEmpty) {
        return const <ExecutiveCollegeVisit>[];
      }
      return snap.docs.map((doc) {
        final data = doc.data();
        final status =
            (data['status'] ?? data['statusLabel'] ?? 'Planned').toString();
        final rawInitials = data['staffInitials'];
        final List<String> staffInitials = rawInitials is List
            ? rawInitials.map((e) => e.toString()).toList()
            : const [];

        return ExecutiveCollegeVisit(
          id: doc.id,
          monthShort: (data['monthShort'] ?? 'OCT').toString(),
          dayNumber: (data['dayNumber'] ?? '29').toString(),
          collegeName: (data['collegeName'] ?? '').toString(),
          subtitle: (data['subtitle'] ?? '').toString(),
          statusLabel: status,
          purpose: (data['purpose'] ?? '').toString(),
          staffInitials: staffInitials,
          staffNames: (data['staffNames'] ?? data['assignedStaff'] ?? '')
              .toString(),
          leadsCollected: (data['leadsCollected'] as num?)?.toInt() ?? 0,
          interestedCount: (data['interestedCount'] as num?)?.toInt() ?? 0,
          metSummary:
              (data['metSummary'] ?? data['outcomeNotes'] ?? '').toString(),
          nextActionSummary: (data['nextActionSummary'] ?? '').toString(),
          isUpcoming: status != 'Completed' && status != 'Cancelled',
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
    String assignedStaff = '',
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    await _visits.add({
      'collegeName': collegeName.trim(),
      'dayNumber': dayNumber.trim(),
      'monthShort': monthShort.trim().toUpperCase(),
      'subtitle': subtitle.trim(),
      'purpose': purpose.trim(),
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
      'outcomeNotes':
          reason.trim().isNotEmpty ? reason.trim() : 'Visit cancelled',
      'cancelReason': reason.trim(),
      'updatedByUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Permanently deletes a college visit from Firestore.
  Future<void> deleteCollegeVisit(String visitId) async {
    await _visits.doc(visitId).delete();
  }
}

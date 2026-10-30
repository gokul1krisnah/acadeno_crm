import 'package:acadeno_crm/core/services/offline_queue_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/visit_models.dart';

/// Remote data source for college visits connected directly to Cloud Firestore.
/// Guarantees live real-time sync between Admin Dashboard and Executive Home.
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
        return fetchVisits();
      }
      return snap.docs.map((doc) {
        final data = doc.data();
        final status = (data['status'] ?? data['statusLabel'] ?? 'Planned').toString();
        final rawInitials = data['staffInitials'];
        final List<String> staffInitials = rawInitials is List
            ? rawInitials.map((e) => e.toString()).toList()
            : const ['AR', 'RM'];

        return ExecutiveCollegeVisit(
          id: doc.id,
          monthShort: (data['monthShort'] ?? 'OCT').toString(),
          dayNumber: (data['dayNumber'] ?? '29').toString(),
          collegeName: (data['collegeName'] ?? '').toString(),
          subtitle: (data['subtitle'] ?? '').toString(),
          statusLabel: status,
          purpose: (data['purpose'] ?? '').toString(),
          staffInitials: staffInitials,
          staffNames: (data['staffNames'] ?? data['assignedStaff'] ?? 'Anjali R, Rahul M').toString(),
          leadsCollected: (data['leadsCollected'] as num?)?.toInt() ?? 0,
          interestedCount: (data['interestedCount'] as num?)?.toInt() ?? 0,
          metSummary: (data['metSummary'] ?? data['outcomeNotes'] ?? '').toString(),
          nextActionSummary: (data['nextActionSummary'] ?? '').toString(),
          isUpcoming: status != 'Completed' && status != 'Cancelled',
        );
      }).toList();
    });
  }

  /// Initial fallback visits if Firestore collection is newly created.
  List<ExecutiveCollegeVisit> fetchVisits() => [
        ExecutiveCollegeVisit(
          id: 'cv1',
          monthShort: 'OCT',
          dayNumber: '29',
          collegeName: 'NIT Calicut',
          subtitle: 'Thu · 10:00 AM · CSE department',
          statusLabel: 'Planned',
          purpose: 'Promote AI & ML workshop · meet placement officer',
          staffInitials: const ['AR', 'RM'],
          staffNames: 'Anjali R, Rahul M',
          isUpcoming: true,
        ),
        ExecutiveCollegeVisit(
          id: 'cv2',
          monthShort: 'OCT',
          dayNumber: '22',
          collegeName: 'GEC Kozhikode',
          subtitle: 'Industrial visit briefing · ECE',
          statusLabel: 'Completed',
          leadsCollected: 46,
          interestedCount: 9,
          metSummary: 'HOD ECE, Placement officer',
          nextActionSummary: 'Send MoU draft by 5 Nov',
          isUpcoming: false,
        ),
        ExecutiveCollegeVisit(
          id: 'cv3',
          monthShort: 'OCT',
          dayNumber: '17',
          collegeName: 'Farook College',
          subtitle: 'Rescheduled by college',
          statusLabel: 'Cancelled',
          isUpcoming: false,
        ),
      ];

  /// Plans a new college visit in Firestore.
  Future<void> addCollegeVisit({
    required String collegeName,
    required String dayNumber,
    required String monthShort,
    required String subtitle,
    required String purpose,
    String assignedStaff = 'Anjali R, Rahul M',
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
          .map((s) => s.split(' ').map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join())
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
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/build_context_extension.dart';
import '../../../../shared/utilities/link_launcher.dart';

class _CollegeVisit {
  final String id;

  final String collegeName;

  final String dateLabel;

  final String purpose;

  final String assignedStaff;

  String status;

  String outcomeNotes;

  int leadsCollected;

  int conversions;

  _CollegeVisit({
    required this.id,

    required this.collegeName,

    required this.dateLabel,

    required this.purpose,

    required this.assignedStaff,

    required this.status,

    required this.outcomeNotes,

    required this.leadsCollected,

    required this.conversions,
  });
}

class CollegeVisitsView extends StatefulWidget {
  const CollegeVisitsView({super.key});

  @override
  State<CollegeVisitsView> createState() => _CollegeVisitsViewState();
}

class _CollegeVisitsViewState extends State<CollegeVisitsView> {
  final _visitsCollection = FirebaseFirestore.instance.collection(
    'college_visits',
  );

  static final List<_CollegeVisit> _defaultVisits = [
    _CollegeVisit(
      id: 'cv_default_1',

      collegeName: 'NIT Calicut · CSE & ECE Dept',

      dateLabel: '24 Oct 2026',

      purpose: 'AI & ML Workshop seminar + HOD placement pitch',

      assignedStaff: 'Anjali R, Rahul M',

      status: 'Completed',

      outcomeNotes:
          'Met Dr. Suresh (CSE HOD). Approved 2-day workshop slot for 14 Nov.',

      leadsCollected: 312,

      conversions: 19,
    ),

    _CollegeVisit(
      id: 'cv_default_2',

      collegeName: 'GEC Kozhikode',

      dateLabel: '26 Oct 2026',

      purpose: 'Industrial Visit registration drive',

      assignedStaff: 'Shilpa K, Ajmal P',

      status: 'Completed',

      outcomeNotes: 'Met placement coordinator & IEEE student branch leads.',

      leadsCollected: 218,

      conversions: 12,
    ),

    _CollegeVisit(
      id: 'cv_default_3',

      collegeName: 'MES College of Engineering, Kuttippuram',

      dateLabel: DateFormat('d MMM yyyy').format(DateTime.now()),

      purpose: 'Python & Full Stack orientation for 3rd yr CSE/IT',

      assignedStaff: 'Anjali R, Neethu S',

      status: 'Planned',

      outcomeNotes: 'Seminar hall booked at 10:30 AM.',

      leadsCollected: 0,

      conversions: 0,
    ),

    _CollegeVisit(
      id: 'cv_default_4',

      collegeName: 'KMCT College of Engineering',

      dateLabel: '03 Nov 2026',

      purpose: 'Add-on course MOU follow-up',

      assignedStaff: 'Rahul M',

      status: 'Planned',

      outcomeNotes: 'Awaiting Principal confirmation for final-year batch.',

      leadsCollected: 0,

      conversions: 0,
    ),
  ];

  void _showPlanVisitDialog() {
    final collegeCtrl = TextEditingController();

    final dateCtrl = TextEditingController(text: '06 Nov 2026');

    final purposeCtrl = TextEditingController();

    final staffCtrl = TextEditingController(text: 'Anjali R, Rahul M');

    showDialog(
      context: context,

      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        title: const Text(
          'Plan College Visit (FR-8.1)',

          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),

        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),

          child: SingleChildScrollView(
            padding: EdgeInsets.all(ctx.devicePadding),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                TextField(
                  controller: collegeCtrl,

                  decoration: const InputDecoration(
                    labelText: 'College & Department *',

                    hintText: 'e.g. Farook College · BCA Dept',
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: dateCtrl,

                  decoration: const InputDecoration(labelText: 'Visit Date'),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: purposeCtrl,

                  decoration: const InputDecoration(
                    labelText: 'Purpose / Event',

                    hintText: 'e.g. Seminar + student registration drive',
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: staffCtrl,

                  decoration: const InputDecoration(
                    labelText: 'Assigned Staff',
                  ),
                ),
              ],
            ),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),

            child: const Text('Cancel'),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),

              foregroundColor: Colors.white,
            ),

            onPressed: () async {
              if (collegeCtrl.text.trim().isEmpty) return;

              final dText = dateCtrl.text.trim();

              final dayNum = RegExp(r'\d+').firstMatch(dText)?.group(0) ?? '29';

              final month = dText.contains('Nov')
                  ? 'NOV'
                  : (dText.contains('Dec') ? 'DEC' : 'OCT');

              await _visitsCollection.add({
                'collegeName': collegeCtrl.text.trim(),

                'dateLabel': dText,

                'dayNumber': dayNum,

                'monthShort': month,

                'purpose': purposeCtrl.text.trim().isEmpty
                    ? 'Campus outreach & seminar'
                    : purposeCtrl.text.trim(),

                'assignedStaff': staffCtrl.text.trim(),

                'staffNames': staffCtrl.text.trim(),

                'status': 'Planned',

                'statusLabel': 'Planned',

                'outcomeNotes': 'Scheduled campus visit.',

                'leadsCollected': 0,

                'conversions': 0,

                'createdByUid': FirebaseAuth.instance.currentUser?.uid,

                'createdAt': FieldValue.serverTimestamp(),

                'updatedAt': FieldValue.serverTimestamp(),
              });

              if (ctx.mounted) Navigator.pop(ctx);
            },

            child: const Text('Save Visit'),
          ),
        ],
      ),
    );
  }

  void _showLogOutcomeDialog(_CollegeVisit visit) {
    final messenger = ScaffoldMessenger.of(context);
    final notesCtrl = TextEditingController(text: visit.outcomeNotes);
    final leadsCtrl = TextEditingController(
      text: visit.leadsCollected > 0 ? '' : '0',
    );
    bool isCancelled = visit.status == 'Cancelled';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Log Visit Outcome · ',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(ctx.devicePadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tick option for Cancelled / Not Completed
                  Container(
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCancelled
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      value: isCancelled,
                      activeColor: const Color(0xFFDC2626),
                      checkColor: Colors.white,
                      title: Text(
                        isCancelled
                            ? 'Not Completed · Cancelled'
                            : 'Visit Completed Successfully',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isCancelled
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF166534),
                        ),
                      ),
                      subtitle: Text(
                        isCancelled
                            ? 'Tick to log this visit as not completed / cancelled'
                            : 'Tick if this visit was cancelled or could not be conducted',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isCancelled
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF15803D),
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      onChanged: isSaving
                          ? null
                          : (val) {
                              setDialogState(() {
                                isCancelled = val ?? false;
                              });
                            },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: isCancelled
                          ? 'Cancellation reason & notes'
                          : 'People met, agreements & notes',
                      hintText: isCancelled
                          ? 'e.g. Principal unavailable, postponed due to exams'
                          : 'e.g. Met placement coordinator, agreed to workshop',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (!isCancelled) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: leadsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Student leads collected from visit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCancelled
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF15803D),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final newNotes = notesCtrl.text.trim();
                      final newLeads = isCancelled
                          ? 0
                          : (int.tryParse(leadsCtrl.text.trim()) ?? 0);

                      try {
                        if (isCancelled) {
                          await _visitsCollection.doc(visit.id).set({
                            'status': 'Cancelled',
                            'statusLabel': 'Cancelled',
                            'outcomeNotes': newNotes.isNotEmpty
                                ? newNotes
                                : 'Visit cancelled',
                            'cancelReason': newNotes,
                            'leadsCollected': 0,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Visit to \ saved as Cancelled.'),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                        } else {
                          await _visitsCollection.doc(visit.id).set({
                            'status': 'Completed',
                            'statusLabel': 'Completed',
                            'outcomeNotes': newNotes,
                            'metSummary': newNotes,
                            'leadsCollected': newLeads,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Visit to \ marked as Completed!',
                                ),
                                backgroundColor: const Color(0xFF15803D),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (ctx.mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to update visit: '),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isCancelled ? 'Save as Cancelled' : 'Mark Completed'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _visitsCollection.snapshots(),

      builder: (context, snapshot) {
        final List<_CollegeVisit> visits;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          visits = snapshot.data!.docs.map((doc) {
            final d = doc.data();

            return _CollegeVisit(
              id: doc.id,

              collegeName: (d['collegeName'] ?? 'College').toString(),

              dateLabel:
                  (d['dateLabel'] ??
                          DateFormat('d MMM yyyy').format(DateTime.now()))
                      .toString(),

              purpose: (d['purpose'] ?? '').toString(),

              assignedStaff: (d['assignedStaff'] ?? d['staffNames'] ?? 'Team')
                  .toString(),

              status: (d['status'] ?? d['statusLabel'] ?? 'Planned').toString(),

              outcomeNotes: (d['outcomeNotes'] ?? d['metSummary'] ?? '')
                  .toString(),

              leadsCollected: (d['leadsCollected'] as num?)?.toInt() ?? 0,

              conversions: (d['conversions'] as num?)?.toInt() ?? 0,
            );
          }).toList();
        } else {
          visits = const [];
        }

        final totalLeads = visits.fold<int>(
          0,
          (acc, v) => acc + v.leadsCollected,
        );

        final totalConversions = visits.fold<int>(
          0,
          (acc, v) => acc + v.conversions,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Wrap(
              spacing: 16,

              runSpacing: 12,

              alignment: WrapAlignment.spaceBetween,

              crossAxisAlignment: WrapCrossAlignment.center,

              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'College visits',

                      style: TextStyle(
                        fontSize: 26,

                        fontWeight: FontWeight.w800,

                        color: Color(0xFF0F172A),

                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Plan campus outreach, log HOD/faculty meetings, and track $totalLeads leads ($totalConversions conversions) generated',

                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height: 40,

                  child: ElevatedButton.icon(
                    onPressed: _showPlanVisitDialog,

                    icon: const Icon(Icons.add, size: 16),

                    label: const Text('Plan college visit'),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4338CA),

                      foregroundColor: Colors.white,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            ...visits.map((visit) {
              final isCompleted = visit.status == 'Completed';

              return Container(
                width: double.infinity,

                margin: const EdgeInsets.only(bottom: 12),

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(14),

                  border: Border.all(color: const Color(0xFFE8EAF0)),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Wrap(
                      spacing: 10,

                      runSpacing: 8,

                      alignment: WrapAlignment.spaceBetween,

                      crossAxisAlignment: WrapCrossAlignment.center,

                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Flexible(
                              child: Text(
                                visit.collegeName,

                                style: const TextStyle(
                                  fontSize: 16,

                                  fontWeight: FontWeight.w700,

                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),

                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? const Color(0xFFE6F4EA)
                                    : const Color(0xFFFEF0E6),

                                borderRadius: BorderRadius.circular(12),
                              ),

                              child: Text(
                                '${visit.status} · ${visit.dateLabel}',

                                style: TextStyle(
                                  fontSize: 11.5,

                                  fontWeight: FontWeight.w700,

                                  color: isCompleted
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF9A3412),
                                ),
                              ),
                            ),
                          ],
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  LinkLauncher.launchCollegeMapsDirections(
                                    visit.collegeName,
                                  ),
                              icon: const Icon(
                                Icons.directions_outlined,
                                size: 15,
                                color: Color(0xFF4338CA),
                              ),
                              label: const Text(
                                'Directions',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(
                                  color: Color(0xFFD0D5DD),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _showLogOutcomeDialog(visit),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(
                                  color: Color(0xFFD0D5DD),
                                ),
                              ),
                              child: Text(
                                isCompleted ? 'Update outcome' : 'Log outcome',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Purpose: ${visit.purpose} · Staff: ${visit.assignedStaff}',

                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF344054),
                      ),
                    ),

                    if (visit.outcomeNotes.isNotEmpty) ...[
                      const SizedBox(height: 6),

                      Text(
                        visit.outcomeNotes,

                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],

                    if (visit.leadsCollected > 0 || visit.conversions > 0) ...[
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,

                        runSpacing: 8,

                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),

                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FD),

                              borderRadius: BorderRadius.circular(6),
                            ),

                            child: Text(
                              '${visit.leadsCollected} leads collected',

                              style: const TextStyle(
                                fontSize: 12,

                                fontWeight: FontWeight.w700,

                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),

                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4EA),

                              borderRadius: BorderRadius.circular(6),
                            ),

                            child: Text(
                              '${visit.conversions} enrollments / conversions',

                              style: const TextStyle(
                                fontSize: 12,

                                fontWeight: FontWeight.w700,

                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

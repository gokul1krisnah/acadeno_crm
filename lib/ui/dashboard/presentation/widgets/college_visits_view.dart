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

  void _showPlanVisitDialog() {
    final collegeCtrl = TextEditingController();

    final dateCtrl = TextEditingController(
      text: DateFormat('dd MMM yyyy').format(DateTime.now()),
    );

    final purposeCtrl = TextEditingController();

    final staffCtrl = TextEditingController();

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
                  readOnly: true,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: now,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF4338CA),
                              onPrimary: Colors.white,
                              onSurface: Color(0xFF0F172A),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      dateCtrl.text = DateFormat('dd MMM yyyy').format(picked);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Visit Date',
                    suffixIcon: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: Color(0xFF4338CA),
                    ),
                  ),
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
            'Log Visit Outcome · ${visit.collegeName}',
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
                                content: Text(
                                  'Visit to ${visit.collegeName} saved as Cancelled.',
                                ),
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
                                  'Visit to ${visit.collegeName} marked as Completed!',
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
                              content: Text('Failed to update visit: $e'),
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
                        SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'College visits',
                          style: TextStyle(
                            fontSize: 28,
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
                  ),
                  const SizedBox(width: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            ...visits.map((visit) {
              final isCompleted = visit.status == 'Completed';

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 620;

                          final statusBadge = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '• ${visit.status} • ${visit.dateLabel}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isCompleted
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFEA580C),
                              ),
                            ),
                          );

                          final actionButtons = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    LinkLauncher.launchCollegeMapsDirections(
                                      visit.collegeName,
                                    ),
                                icon: const Icon(
                                  Icons.near_me_rounded,
                                  size: 14,
                                  color: Color(0xFF4F46E5),
                                ),
                                label: const Text(
                                  'Directions',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => _showLogOutcomeDialog(visit),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                child: Text(
                                  isCompleted ? 'Update outcome' : 'Log outcome',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475467),
                                  ),
                                ),
                              ),
                            ],
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        visit.collegeName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    statusBadge,
                                  ],
                                ),
                                const SizedBox(height: 12),
                                actionButtons,
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        visit.collegeName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    statusBadge,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              actionButtons,
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF475467),
                        ),
                        children: [
                          const TextSpan(
                            text: 'Purpose: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                          TextSpan(
                            text: visit.purpose.isEmpty
                                ? 'Campus outreach'
                                : visit.purpose,
                          ),
                          const TextSpan(
                            text: '  •  ',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                            text: 'Staff: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                          TextSpan(
                            text: visit.assignedStaff.isEmpty
                                ? 'Team'
                                : visit.assignedStaff,
                          ),
                          if (visit.outcomeNotes.isNotEmpty) ...[
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: visit.outcomeNotes,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (visit.leadsCollected > 0 || visit.conversions > 0) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (visit.leadsCollected > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
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
                          if (visit.conversions > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${visit.conversions} conversions',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
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

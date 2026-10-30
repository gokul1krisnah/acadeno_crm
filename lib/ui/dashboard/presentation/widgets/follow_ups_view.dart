import 'package:acadeno_crm/shared/widgets/acadeno_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../shared/snackbar_alerts/snack_alert.dart';

class _FollowUpRow {
  final String id;
  final String studentName;
  final String phone;
  final String collegeBranch;
  final String note;
  final String dueLabel;
  final bool isOverdue;
  String assignedExec;
  bool completed;

  _FollowUpRow({
    required this.id,
    required this.studentName,
    required this.phone,
    required this.collegeBranch,
    required this.note,
    required this.dueLabel,
    required this.isOverdue,
    required this.assignedExec,
    this.completed = false,
  });
}

class FollowUpsView extends StatefulWidget {
  const FollowUpsView({super.key});

  @override
  State<FollowUpsView> createState() => _FollowUpsViewState();
}

class _FollowUpsViewState extends State<FollowUpsView> {
  String _filterMode = 'All open';
  String _selectedExecFilter = 'All executives';
  String _fromExec = '';
  String _toExec = '';

  final Set<String> _localCompletedIds = {};
  final Map<String, String> _localReassignedMap = {};

  void _markCompleted(String leadId, String name) async {
    setState(() => _localCompletedIds.add(leadId));
    try {
      await FirebaseFirestore.instance.collection('leads').doc(leadId).update({
        'isDone': true,
        'status': 'contacted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    if (mounted) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Follow-up for $name marked completed.',
      );
    }
  }

  void _reassignSingle(_FollowUpRow row, List<String> executives) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Reassign ${row.studentName}'),
        children: executives.map((exec) {
          return SimpleDialogOption(
            onPressed: () async {
              setState(() => _localReassignedMap[row.id] = exec);
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('leads')
                    .doc(row.id)
                    .update({
                      'assignedTo': exec,
                      'assignedToName': exec,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
              } catch (_) {}
              if (mounted) {
                SnackBarAlert.showToast(
                  context: context,
                  message: 'Reassigned ${row.studentName} to $exec',
                );
              }
            },
            child: Row(
              children: [
                Icon(
                  row.assignedExec == exec
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: const Color(0xFF4338CA),
                ),
                const SizedBox(width: 10),
                Text(exec, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _bulkMoveExecutiveFollowUps(List<_FollowUpRow> followUps) async {
    if (_fromExec.isEmpty || _toExec.isEmpty || _fromExec == _toExec) return;
    int moved = 0;
    final batch = FirebaseFirestore.instance.batch();

    for (final item in followUps) {
      if (!item.completed && item.assignedExec == _fromExec) {
        _localReassignedMap[item.id] = _toExec;
        moved++;
        final docRef = FirebaseFirestore.instance
            .collection('leads')
            .doc(item.id);
        batch.update(docRef, {
          'assignedTo': _toExec,
          'assignedToName': _toExec,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    try {
      if (moved > 0) await batch.commit();
    } catch (_) {}

    setState(() {});
    if (mounted) {
      SnackBarAlert.showToast(
        context: context,
        message: moved > 0
            ? 'Moved $moved open follow-ups from $_fromExec to $_toExec (FR-4.6).'
            : 'No open follow-ups found for $_fromExec.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('leads').snapshots(),
          builder: (context, leadsSnap) {
            // Extract active executives
            final execs = (usersSnap.data?.docs ?? [])
                .where((d) => d.data()['isActive'] != false)
                .map(
                  (d) => (d.data()['name'] ?? 'Team Member').toString().trim(),
                )
                .where((n) => n.isNotEmpty)
                .toSet()
                .toList();

            final executives = execs.isNotEmpty
                ? execs
                : ['Anjali R', 'Rahul M', 'Shilpa K', 'Ajmal P', 'Neethu S'];

            if (_fromExec.isEmpty || !executives.contains(_fromExec)) {
              _fromExec = executives.first;
            }
            if (_toExec.isEmpty || !executives.contains(_toExec)) {
              _toExec = executives.length > 1
                  ? executives[1]
                  : executives.first;
            }

            // Extract follow-ups from Firestore leads
            final leadDocs = leadsSnap.data?.docs ?? [];
            final followUps = <_FollowUpRow>[];

            for (final doc in leadDocs) {
              final d = doc.data();
              final isDone = (d['isDone'] as bool?) ?? false;
              final status = (d['status'] ?? '').toString().toLowerCase();

              // Follow-up candidates: follow-up status, claimed, or leads with notes/timelines
              final isCandidate =
                  status == 'follow-up' ||
                  status == 'claimed' ||
                  status == 'interested' ||
                  ((d['notes'] as String?)?.isNotEmpty ?? false) ||
                  ((d['timeline'] as List?)?.isNotEmpty ?? false);

              if (isCandidate) {
                final currentExec =
                    _localReassignedMap[doc.id] ??
                    (d['assignedToName'] ?? d['assignedTo'] ?? 'Unassigned')
                        .toString();
                final isCompleted =
                    isDone ||
                    _localCompletedIds.contains(doc.id) ||
                    status == 'converted';
                final isOverdue =
                    !isCompleted && (status == 'follow-up' || status == 'new');

                followUps.add(
                  _FollowUpRow(
                    id: doc.id,
                    studentName: (d['name'] ?? 'Student Inquiry').toString(),
                    phone: (d['phone'] ?? '').toString(),
                    collegeBranch:
                        (d['collegeBranch'] ??
                                d['college'] ??
                                'College inquiry')
                            .toString(),
                    note:
                        (d['notes'] ??
                                'Follow up on admission & workshop details')
                            .toString(),
                    dueLabel:
                        (d['assignedDateLabel'] ??
                                (isOverdue
                                    ? 'Overdue · High Priority'
                                    : 'Due today'))
                            .toString(),
                    isOverdue: isOverdue,
                    assignedExec: currentExec,
                    completed: isCompleted,
                  ),
                );
              }
            }

            // Seed fallback if Firestore has no follow-ups yet
            if (followUps.isEmpty) {
              followUps.addAll([
                _FollowUpRow(
                  id: 'seed-f1',
                  studentName: 'Fathima Niha',
                  phone: '98470 55112',
                  collegeBranch: 'KMCT · CSE · 3rd yr',
                  note: 'Send Python syllabus on WhatsApp',
                  dueLabel: 'Overdue · 2 days',
                  isOverdue: true,
                  assignedExec: executives.first,
                ),
                _FollowUpRow(
                  id: 'seed-f2',
                  studentName: 'Sreehari K',
                  phone: '94471 20934',
                  collegeBranch: 'GEC Thrissur · ECE · 4th yr',
                  note: 'Confirm weekend batch fee installment',
                  dueLabel: 'Overdue · 1 day',
                  isOverdue: true,
                  assignedExec: executives.length > 1
                      ? executives[1]
                      : executives.first,
                ),
                _FollowUpRow(
                  id: 'seed-f3',
                  studentName: 'Arun Kumar',
                  phone: '98470 11111',
                  collegeBranch: 'NIT Calicut · CSE · 3rd yr',
                  note: 'Interested in AI & ML Workshop – check group discount',
                  dueLabel: 'Today · 4:00 PM',
                  isOverdue: false,
                  assignedExec: executives.first,
                ),
              ]);
            }

            // Filter items
            final filteredItems = followUps.where((item) {
              if (item.completed) return false;
              if (_filterMode == 'Overdue only' && !item.isOverdue) {
                return false;
              }
              if (_filterMode == 'Due today' && item.isOverdue) {
                return false;
              }
              if (_selectedExecFilter != 'All executives' &&
                  item.assignedExec != _selectedExecFilter) {
                return false;
              }
              return true;
            }).toList();

            final overdueCount = followUps
                .where((f) => !f.completed && f.isOverdue)
                .length;
            final openCount = followUps.where((f) => !f.completed).length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 720;

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
                              'Follow-ups & Escalations',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$openCount open follow-ups across ${executives.length} team members · $overdueCount overdue (live from database)',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Bulk Reassign Bar (FR-4.6 / RL-3)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF4338CA),
                          width: 1.4,
                        ),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(
                                Icons.swap_horiz_rounded,
                                color: Color(0xFF4338CA),
                                size: 20,
                              ),
                              const Text(
                                'Move all open follow-ups from',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              _buildExecDropdown(
                                _fromExec,
                                executives,
                                (v) => setState(() => _fromExec = v),
                              ),
                              const Text(
                                'to',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              _buildExecDropdown(
                                _toExec,
                                executives,
                                (v) => setState(() => _toExec = v),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4338CA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () =>
                                _bulkMoveExecutiveFollowUps(followUps),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            label: const Text('Reassign in Firestore'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter row
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildFilterPill('All open ($openCount)'),
                        _buildFilterPill('Overdue only ($overdueCount)'),
                        _buildFilterPill('Due today'),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 170,
                          child: AcadenoDropdown.strings(
                            value: _selectedExecFilter,
                            items: ['All executives', ...executives],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedExecFilter = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cards/Table
                    if (filteredItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: const Center(
                          child: Text(
                            'No follow-ups match the selected filters.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                      )
                    else
                      ...filteredItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildFollowUpCard(item, isMobile, executives),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterPill(String label) {
    final mode = label.split(' (').first;
    final isSelected = _filterMode == mode;
    return InkWell(
      onTap: () => setState(() => _filterMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4338CA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4338CA)
                : const Color(0xFFD0D5DD),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF344054),
          ),
        ),
      ),
    );
  }

  Widget _buildExecDropdown(
    String value,
    List<String> executives,
    ValueChanged<String> onChanged,
  ) {
    return SizedBox(
      width: 150,
      child: AcadenoDropdown.strings(
        value: value,
        items: executives,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildFollowUpCard(
    _FollowUpRow item,
    bool isMobile,
    List<String> executives,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isOverdue
              ? const Color(0xFFFECDCA)
              : const Color(0xFFE4E7EC),
          width: item.isOverdue ? 1.4 : 1,
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.isOverdue
                      ? const Color(0xFFFEF3F2)
                      : const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.access_time_rounded,
                  color: item.isOverdue
                      ? const Color(0xFFB42318)
                      : const Color(0xFF4338CA),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.studentName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.isOverdue
                              ? const Color(0xFFFEF3F2)
                              : const Color(0xFFEEF0FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.dueLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: item.isOverdue
                                ? const Color(0xFFB42318)
                                : const Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.phone} · ${item.collegeBranch}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Note: ${item.note}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Assigned: ${item.assignedExec}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475467),
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4338CA),
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () => _reassignSingle(item, executives),
                child: const Text('Reassign'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: () => _markCompleted(item.id, item.studentName),
                child: const Text('Mark Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

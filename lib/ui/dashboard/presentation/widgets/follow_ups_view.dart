import 'package:flutter/cupertino.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_time_helper.dart';
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
            ? 'Moved $moved open follow-ups from $_fromExec to $_toExec.'
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

              // Follow-up candidates: leads with followUpTime, or follow-up status, callback, overdue, claimed, interested, or with notes/timelines
              final hasFollowUpTime =
                  (d['followUpTime'] != null &&
                  d['followUpTime'].toString().trim().isNotEmpty);
              final isCandidate =
                  hasFollowUpTime ||
                  d['isOverdue'] == true ||
                  status == 'follow-up' ||
                  status == 'callback' ||
                  status == 'overdue' ||
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
                final eval = FollowUpTimeHelper.evaluate(
                  rawFollowUpTime: d['followUpTime'],
                  assignedDateKey: d['assignedDateKey'],
                  assignedDateLabel: d['assignedDateLabel'],
                  assignedAt: d['assignedAt'],
                  updatedAt: d['updatedAt'],
                  createdAt: d['createdAt'],
                  status: status,
                );
                final isOverdue = !isCompleted && eval.isOverdue;

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
                    dueLabel: eval.displayLabel,
                    isOverdue: isOverdue,
                    assignedExec: currentExec,
                    completed: isCompleted,
                  ),
                );
              }
            }

            // Follow-ups matching executive filter
            final execFollowUps = followUps.where((item) {
              if (item.completed) return false;
              if (_selectedExecFilter != 'All executives' &&
                  item.assignedExec != _selectedExecFilter) {
                return false;
              }
              return true;
            }).toList();

            final openCount = execFollowUps.length;
            final overdueCount = execFollowUps.where((f) => f.isOverdue).length;
            final dueTodayCount = execFollowUps
                .where((f) => !f.isOverdue)
                .length;

            final totalOpenAll = followUps.where((f) => !f.completed).length;
            final totalOverdueAll = followUps
                .where((f) => !f.completed && f.isOverdue)
                .length;

            // Filter items based on active pill
            final filteredItems = execFollowUps.where((item) {
              if (_filterMode == 'Overdue only' && !item.isOverdue) {
                return false;
              }
              if (_filterMode == 'Due today' && item.isOverdue) {
                return false;
              }
              return true;
            }).toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile =
                    MediaQuery.of(context).size.width < 768 ||
                    constraints.maxWidth < 720;

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
                              '$totalOpenAll open follow-ups across ${executives.length} team members · $totalOverdueAll overdue (live from database)',
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

                    // Bulk Reassign Bar
                    // Bulk Reassign Bar (Responsive)
                    LayoutBuilder(
                      builder: (context, c) {
                        final isMobile = c.maxWidth < 640;
                        if (isMobile) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF4338CA),
                                width: 1.4,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.shuffle,
                                      color: Color(0xFF4338CA),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Move all open follow-ups',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildExecDropdown(
                                        _fromExec,
                                        executives,
                                        (v) => setState(() => _fromExec = v),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        'to',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildExecDropdown(
                                        _toExec,
                                        executives,
                                        (v) => setState(() => _toExec = v),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF8144),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _bulkMoveExecutiveFollowUps(followUps),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Re Assign in Fire Store',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
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
                                    CupertinoIcons.shuffle,
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
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF8144),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () =>
                                    _bulkMoveExecutiveFollowUps(followUps),
                                child: const Text(
                                  'Re Assign in Fire Store',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
                        _buildFilterPill('Due today ($dueTodayCount)'),
                        const SizedBox(width: 4),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedExecFilter,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              icon: const Icon(
                                CupertinoIcons.chevron_down,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475467),
                              ),
                              items: ['All executives', ...executives].map((s) {
                                return DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475467),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedExecFilter = v);
                                }
                              },
                            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3F37C9) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3F37C9)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475467),
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
    final isOverdue = item.isOverdue;

    final assignedBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        'Assigned: ${item.assignedExec}',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475467),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final reassignBtn = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF4338CA),
        side: const BorderSide(color: Color(0xFF4338CA), width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: const StadiumBorder(),
      ),
      onPressed: () => _reassignSingle(item, executives),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Reassign',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );

    final markDoneBtn = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: const StadiumBorder(),
      ),
      onPressed: () => _markCompleted(item.id, item.studentName),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Mark Done',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );

    final iconWidget = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(
        isOverdue ? Icons.warning_rounded : CupertinoIcons.clock,
        color: isOverdue ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
        size: 21,
      ),
    );

    final studentInfoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.studentName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isOverdue
                    ? const Color(0xFFFFEDD5)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.dueLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isOverdue
                      ? const Color(0xFFC2410C)
                      : const Color(0xFF2563EB),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${item.phone} · ${item.collegeBranch}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475467)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (item.note.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            'Note: ${item.note}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    if (isMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOverdue
                ? const Color(0xFFFED7AA)
                : const Color(0xFFE2E8F0),
            width: isOverdue ? 1.2 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconWidget,
                const SizedBox(width: 12),
                Expanded(child: studentInfoWidget),
              ],
            ),
            const SizedBox(height: 14),
            Row(children: [Flexible(child: assignedBadge)]),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: SizedBox(height: 34, child: reassignBtn)),
                const SizedBox(width: 10),
                Expanded(child: SizedBox(height: 34, child: markDoneBtn)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
          width: isOverdue ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: 14),
          Expanded(child: studentInfoWidget),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              assignedBadge,
              const SizedBox(width: 8),
              SizedBox(width: 102, height: 34, child: reassignBtn),
              const SizedBox(width: 8),
              SizedBox(height: 34, child: markDoneBtn),
            ],
          ),
        ],
      ),
    );
  }
}

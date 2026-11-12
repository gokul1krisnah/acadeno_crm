import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/url_dialer_helper.dart';
import '../../../../shared/snackbar_alerts/snack_alert.dart';
import '../../../follow_ups/data/model/follow_up_time_helper.dart';

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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reassign ${row.studentName}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: executives.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
            itemBuilder: (ctx, i) {
              final exec = executives[i];
              final isSelected = row.assignedExec == exec;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: isSelected ? const Color(0xFF3B3FB1) : const Color(0xFF9CA3AF),
                ),
                title: Text(
                  exec,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF111827),
                  ),
                ),
                onTap: () async {
                  setState(() => _localReassignedMap[row.id] = exec);
                  Navigator.pop(ctx);
                  try {
                    await FirebaseFirestore.instance.collection('leads').doc(row.id).update({
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
              );
            },
          ),
        ),
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
        final docRef = FirebaseFirestore.instance.collection('leads').doc(item.id);
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
                .map((d) => (d.data()['name'] ?? 'Team Member').toString().trim())
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
              _toExec = executives.length > 1 ? executives[1] : executives.first;
            }

            // Extract follow-ups from Firestore leads
            final leadDocs = leadsSnap.data?.docs ?? [];
            final followUps = <_FollowUpRow>[];

            for (final doc in leadDocs) {
              final d = doc.data();
              final isDone = (d['isDone'] as bool?) ?? false;
              final status = (d['status'] ?? '').toString().toLowerCase();

              final hasFollowUpTime =
                  (d['followUpTime'] != null && d['followUpTime'].toString().trim().isNotEmpty);
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
                    (d['assignedToName'] ?? d['assignedTo'] ?? 'Unassigned').toString();
                final isCompleted =
                    isDone || _localCompletedIds.contains(doc.id) || status == 'converted';
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
                        (d['collegeBranch'] ?? d['college'] ?? 'College Inquiry').toString(),
                    note: (d['notes'] ?? 'Follow up on admission & workshop details').toString(),
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
            final dueTodayCount = execFollowUps.where((f) => !f.isOverdue).length;

            final totalOpenAll = followUps.where((f) => !f.completed).length;
            final totalOverdueAll = followUps.where((f) => !f.completed && f.isOverdue).length;

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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Heading 1 + Live Subtitle
                    Text(
                      'Follow-ups & Escalations',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        height: 36 / 30,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      '$totalOpenAll open follow-ups across ${executives.length} team members · $totalOverdueAll overdue (live from database)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF71717A),
                        height: 20 / 14,
                      ),
                    ),
                    const Gap(32),

                    // Bulk Move Action Bar (Figma Node 1363:1601)
                    _buildBulkReassignBar(constraints.maxWidth, followUps, executives),
                    const Gap(32),

                    // Filter Row (Figma Node 1363:1631)
                    _buildFilterRow(
                      constraints.maxWidth,
                      openCount,
                      overdueCount,
                      dueTodayCount,
                      executives,
                    ),
                    const Gap(16),

                    // Follow-Up Cards List (Figma Node 1363:1646)
                    if (filteredItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: Center(
                          child: Text(
                            'No follow-ups match the selected filters.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF71717A),
                            ),
                          ),
                        ),
                      )
                    else
                      ...filteredItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildFollowUpCard(item, constraints.maxWidth, executives),
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

  // ===========================================================================
  // BULK REASSIGN BAR (Figma: White bg, 2px solid #3B3FB1, 16px radius)
  // ===========================================================================
  Widget _buildBulkReassignBar(
    double maxWidth,
    List<_FollowUpRow> followUps,
    List<String> executives,
  ) {
    final isCompact = maxWidth < 880;

    final reassignButton = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEF8144),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE0E7FF),
            blurRadius: 15,
            offset: Offset(0, 10),
            spreadRadius: -3,
          ),
          BoxShadow(
            color: Color(0xFFE0E7FF),
            blurRadius: 6,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _bulkMoveExecutiveFollowUps(followUps),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              'Re Assign in Fire Store',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 24 / 14,
              ),
            ),
          ),
        ),
      ),
    );

    if (isCompact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3B3FB1), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.shuffle,
                  color: Color(0xFF3B3FB1),
                  size: 18,
                ),
                const Gap(8),
                Expanded(
                  child: Text(
                    'Move all open follow-ups from',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildExecDropdown(
                  value: _fromExec,
                  items: executives,
                  textColor: const Color(0xFF6B7280),
                  onChanged: (v) => setState(() => _fromExec = v),
                ),
                Text(
                  'to',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                _buildExecDropdown(
                  value: _toExec,
                  items: executives,
                  textColor: const Color(0xFF111827),
                  onChanged: (v) => setState(() => _toExec = v),
                ),
              ],
            ),
            const Gap(14),
            reassignButton,
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B3FB1), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.shuffle,
                color: Color(0xFF3B3FB1),
                size: 18,
              ),
              const Gap(8),
              Text(
                'Move all open follow-ups from',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const Gap(12),
              _buildExecDropdown(
                value: _fromExec,
                items: executives,
                textColor: const Color(0xFF6B7280),
                onChanged: (v) => setState(() => _fromExec = v),
              ),
              const Gap(12),
              Text(
                'to',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const Gap(12),
              _buildExecDropdown(
                value: _toExec,
                items: executives,
                textColor: const Color(0xFF111827),
                onChanged: (v) => setState(() => _toExec = v),
              ),
            ],
          ),
          reassignButton,
        ],
      ),
    );
  }

  // ===========================================================================
  // FILTER ROW (Figma: All open, Overdue only, Due today + All executives)
  // ===========================================================================
  Widget _buildFilterRow(
    double maxWidth,
    int openCount,
    int overdueCount,
    int dueTodayCount,
    List<String> executives,
  ) {
    final filterTabs = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterPill(
          label: 'All open ($openCount)',
          mode: 'All open',
          isSelected: _filterMode == 'All open',
          onTap: () => setState(() => _filterMode = 'All open'),
        ),
        _buildFilterPill(
          label: 'Overdue only ($overdueCount)',
          mode: 'Overdue only',
          isSelected: _filterMode == 'Overdue only',
          onTap: () => setState(() => _filterMode = 'Overdue only'),
        ),
        _buildFilterPill(
          label: 'Due today',
          mode: 'Due today',
          isSelected: _filterMode == 'Due today',
          onTap: () => setState(() => _filterMode = 'Due today'),
        ),
      ],
    );

    final execDropdown = _buildExecFilterDropdown(
      value: _selectedExecFilter,
      items: executives,
      onChanged: (v) => setState(() => _selectedExecFilter = v),
    );

    if (maxWidth < 680) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          filterTabs,
          execDropdown,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        filterTabs,
        execDropdown,
      ],
    );
  }

  Widget _buildFilterPill({
    required String label,
    required String mode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: isSelected ? 9 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B3FB1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B3FB1) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            height: 20 / 14,
          ),
        ),
      ),
    );
  }

  Widget _buildExecFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    final allItems = ['All executives', ...items];
    return Container(
      height: 40,
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: allItems.contains(value) ? value : allItems.first,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(
            CupertinoIcons.chevron_down,
            size: 12,
            color: Color(0xFF6B7280),
          ),
          isDense: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
          items: allItems.map((name) {
            return DropdownMenuItem<String>(
              value: name,
              child: Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4B5563),
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildExecDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    Color textColor = const Color(0xFF111827),
  }) {
    return Container(
      height: 40,
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x80F9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(
            CupertinoIcons.chevron_down,
            size: 12,
            color: Color(0xFF6B7280),
          ),
          isDense: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
          items: items.map((name) {
            return DropdownMenuItem<String>(
              value: name,
              child: Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF111827),
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // FOLLOW-UP CARD (Figma Node 1363:1675, 1363:1704)
  // ===========================================================================
  Widget _buildFollowUpCard(
    _FollowUpRow item,
    double maxWidth,
    List<String> executives,
  ) {
    final isOverdue = item.isOverdue;
    final isCompact = maxWidth < 820;

    // Left Icon Container (48x48, rounded 12)
    final iconWidget = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFFF5F2) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        isOverdue ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.clock,
        color: isOverdue ? const Color(0xFFE9522C) : const Color(0xFF3B3FB1),
        size: 18,
      ),
    );

    // Status Badge text: TODAY · 6:00 PM or OVERDUE · MISSED (...)
    final badgeText = isOverdue
        ? (item.dueLabel.toLowerCase().contains('overdue')
            ? item.dueLabel.toUpperCase()
            : 'OVERDUE · ${item.dueLabel.toUpperCase()}')
        : (item.dueLabel.toLowerCase().contains('today')
            ? item.dueLabel.toUpperCase()
            : 'TODAY · ${item.dueLabel.toUpperCase()}');

    // Details Column (Name, Badge, Phone, College/Branch, Note)
    final detailsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.studentName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
                height: 28 / 18,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isOverdue ? const Color(0xFFFFEBE5) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isOverdue ? const Color(0xFFE9522C) : const Color(0xFF3B3FB1),
                  letterSpacing: 0.3,
                  height: 15 / 10,
                ),
              ),
            ),
          ],
        ),
        const Gap(4),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: () {
                if (item.phone.isNotEmpty) {
                  UrlDialerHelper.openDialer(item.phone);
                }
              },
              child: Text(
                item.phone,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF71717A),
                  height: 20 / 14,
                ),
              ),
            ),
            Text(
              '·',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFD1D5DB),
              ),
            ),
            Text(
              item.collegeBranch,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF71717A),
                height: 20 / 14,
              ),
            ),
          ],
        ),
        const Gap(8),
        Text.rich(
          TextSpan(
            text: 'Note:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2D3142),
              height: 22.75 / 14,
            ),
            children: [
              if (item.note.isNotEmpty)
                TextSpan(
                  text: ' ${item.note}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF2D3142),
                    height: 22.75 / 14,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    // Actions: Assigned pill, Reassign button, Mark Done button
    final assignedPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Text(
        'Assigned: ${item.assignedExec}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4B5563),
          height: 20 / 14,
        ),
      ),
    );

    final reassignBtn = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B3FB1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _reassignSingle(item, executives),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Reassign',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3B3FB1),
                height: 20 / 14,
              ),
            ),
          ),
        ),
      ),
    );

    final markDoneBtn = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markCompleted(item.id, item.studentName),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Mark Done',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 20 / 14,
              ),
            ),
          ),
        ),
      ),
    );

    final actionsRow = Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        assignedPill,
        reassignBtn,
        markDoneBtn,
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFFD0C1) : const Color(0xFFF3F4F6),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconWidget,
                    const Gap(16),
                    Expanded(child: detailsWidget),
                  ],
                ),
                const Gap(16),
                actionsRow,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                iconWidget,
                const Gap(16),
                Expanded(child: detailsWidget),
                const Gap(16),
                actionsRow,
              ],
            ),
    );
  }
}

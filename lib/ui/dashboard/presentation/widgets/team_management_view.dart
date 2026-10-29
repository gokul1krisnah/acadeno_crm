import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../application/dashboard_cubit.dart';
import '../../application/dashboard_state.dart';
import '../../data/model/dashboard_user_model.dart';

class TeamManagementView extends StatefulWidget {
  const TeamManagementView({super.key});

  @override
  State<TeamManagementView> createState() => _TeamManagementViewState();
}

class _TeamManagementViewState extends State<TeamManagementView> {
  String _selectedDateRange = 'All Time';

  static const _tblHdr = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF667085),
    letterSpacing: 0.4,
  );

  static const _tblCell = TextStyle(fontSize: 13, color: Color(0xFF344054));

  void _showWatermarkedExportModal(
    List<DashboardUserModel> users,
    List<Map<String, dynamic>> leads,
  ) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final screenWidth = mq.size.width;
        final screenHeight = mq.size.height;
        final dialogWidth = (screenWidth - 48).clamp(280.0, 460.0);
        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: (screenHeight * 0.04).clamp(12.0, 24.0).toDouble(),
          ),
          title: const Text(
            'Super Admin Watermarked Export (PR-4.2)',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Only Super Admin may export lead data. The exported report is watermarked with your identity and timestamp, and your typed reason is recorded in the append-only audit log.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475467),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason for export (required) *',
                    hintText:
                        'e.g. Monthly team conversion audit & reconciliation',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;
                context.read<DashboardCubit>().recordAudit(
                  action: 'Exported watermarked report · Reason: $reason',
                  target:
                      '${users.length} team members · ${leads.length} leads',
                  category: 'export',
                  toastMessage:
                      'Generated watermarked team report. Logged in security audit trail (PR-4.2).',
                );
                Navigator.pop(ctx);
              },
              child: const Text('Generate Watermarked CSV'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterLeadsByDate(
    List<Map<String, dynamic>> allLeads,
  ) {
    if (_selectedDateRange == 'All Time') return allLeads;

    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    if (_selectedDateRange == 'Today') {
      return allLeads.where((l) {
        if (l['assignedDateKey'] == todayKey) return true;
        final ca = l['createdAt'];
        if (ca is Timestamp) {
          return DateFormat('yyyy-MM-dd').format(ca.toDate()) == todayKey;
        }
        return false;
      }).toList();
    }

    if (_selectedDateRange == 'This week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startMidnight = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      return allLeads.where((l) {
        final ca = l['createdAt'];
        if (ca is Timestamp) {
          return ca.toDate().isAfter(startMidnight);
        }
        final aa = l['assignedAt'];
        if (aa is Timestamp) {
          return aa.toDate().isAfter(startMidnight);
        }
        return true;
      }).toList();
    }

    if (_selectedDateRange == 'This month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      return allLeads.where((l) {
        final ca = l['createdAt'];
        if (ca is Timestamp) {
          return ca.toDate().isAfter(startOfMonth);
        }
        return true;
      }).toList();
    }

    return allLeads;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();

    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: cubit.watchAllUsers(),
          builder: (context, usersSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: cubit.watchAllLeads(),
              builder: (context, leadsSnap) {
                final allUsers = cubit.mapAndSortUsers(usersSnap.data);
                final activeUsers = allUsers.where((u) => u.isActive).toList();
                final rawLeads =
                    leadsSnap.data?.docs.map((d) => d.data()).toList() ??
                    <Map<String, dynamic>>[];
                final filteredLeads = _filterLeadsByDate(rawLeads);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Team Management',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Real-time team analytics, live conversion tracking, and member performance (FR-6.3)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showWatermarkedExportModal(
                            activeUsers,
                            filteredLeads,
                          ),
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: const Text('Watermarked Export (Super Admin)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFD0D5DD)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick Stats Row (Computed from actual live Firestore leads)
                    _buildTeamSummaryStats(filteredLeads),
                    const SizedBox(height: 20),

                    // Team Performance Comparison Table (Live data per user)
                    _buildTeamPerformanceCard(activeUsers, filteredLeads),
                    const SizedBox(height: 20),

                    // Active Executives Snapshot
                    _buildActiveExecutivesSnapshot(activeUsers),
                    const SizedBox(height: 20),

                    // Append-Only Security & Admin Audit Log (PR-7.1)
                    _buildAuditLogCard(cubit),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTeamSummaryStats(List<Map<String, dynamic>> leads) {
    final totalAssigned = leads.where((l) {
      final uid = l['assignedToUid'];
      final name = l['assignedToName'] ?? l['assignedTo'];
      return (uid != null && uid.toString().trim().isNotEmpty) ||
          (name != null && name.toString().trim().isNotEmpty && name != '—');
    }).length;

    final contactedCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      final isDone = (l['isDone'] as bool?) ?? false;
      return status != 'new' && status != 'unassigned' || isDone;
    }).length;

    final contactedPct = totalAssigned > 0
        ? (contactedCount / totalAssigned * 100).round()
        : (leads.isNotEmpty
              ? (contactedCount / leads.length * 100).round()
              : 0);

    final convertedCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      return status.contains('convert');
    }).length;

    final conversionPct = totalAssigned > 0
        ? (convertedCount / totalAssigned * 100).toStringAsFixed(1)
        : (leads.isNotEmpty
              ? (convertedCount / leads.length * 100).toStringAsFixed(1)
              : '0.0');

    final pendingCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      final isDone = (l['isDone'] as bool?) ?? false;
      return !isDone &&
          (status == 'new' ||
              status == 'claimed' ||
              status == 'follow-up' ||
              status.contains('pending'));
    }).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final stats = [
          (
            'Total Assigned',
            totalAssigned > 0
                ? '$totalAssigned leads'
                : '${leads.length} total',
            Icons.assignment_ind_outlined,
            const Color(0xFF4338CA),
            '${leads.length} total in pool',
          ),
          (
            'Contacted',
            '$contactedCount ($contactedPct%)',
            Icons.phone_in_talk_outlined,
            const Color(0xFF0284C7),
            'Goal: >80%',
          ),
          (
            'Conversions',
            '$convertedCount ($conversionPct%)',
            Icons.verified_outlined,
            const Color(0xFF16A34A),
            'Live conversions',
          ),
          (
            'Pending Follow-ups',
            '$pendingCount',
            Icons.warning_amber_rounded,
            const Color(0xFFDC2626),
            pendingCount > 0 ? 'Requires attention' : 'All clear',
          ),
        ];

        if (isMobile) {
          return Column(
            children: stats
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _statCard(s.$1, s.$2, s.$3, s.$4, s.$5),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: stats.map((s) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _statCard(s.$1, s.$2, s.$3, s.$4, s.$5),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtext,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamPerformanceCard(
    List<DashboardUserModel> activeUsers,
    List<Map<String, dynamic>> leads,
  ) {
    return Container(
      width: double.infinity,
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
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive Performance Comparison (FR-6.3)',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Assigned vs Contacted, Interested, Completed, Converted, and Pending',
                    style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                  ),
                ],
              ),
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDateRange,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
                      DropdownMenuItem(
                        value: 'This week',
                        child: Text('This week'),
                      ),
                      DropdownMenuItem(
                        value: 'This month',
                        child: Text('This month'),
                      ),
                      DropdownMenuItem(
                        value: 'All Time',
                        child: Text('All Time'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedDateRange = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (activeUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No active team members registered yet. Add team accounts in User Management.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 700),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFEAECF0)),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 160,
                            child: Text('TEAM MEMBER', style: _tblHdr),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text('ASSIGNED', style: _tblHdr),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text('CONTACTED', style: _tblHdr),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text('INTERESTED', style: _tblHdr),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text('ACTIONS DONE', style: _tblHdr),
                          ),
                          SizedBox(
                            width: 95,
                            child: Text('CONVERTED', style: _tblHdr),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text('PENDING', style: _tblHdr),
                          ),
                        ],
                      ),
                    ),
                    ...activeUsers.map((user) {
                      // Live computation for this specific user
                      final userLeads = leads.where((l) {
                        final assignedUid = l['assignedToUid'];
                        final assignedName =
                            l['assignedToName'] ?? l['assignedTo'];
                        final ownerUid = l['ownerUid'];
                        return assignedUid == user.uid ||
                            ownerUid == user.uid ||
                            (assignedName != null &&
                                assignedName.toString().trim().toLowerCase() ==
                                    user.name.trim().toLowerCase());
                      }).toList();

                      final assignedCount = userLeads.length;
                      final contactedCount = userLeads.where((l) {
                        final status = (l['status'] ?? '')
                            .toString()
                            .toLowerCase();
                        final isDone = (l['isDone'] as bool?) ?? false;
                        return status != 'new' && status != 'unassigned' ||
                            isDone;
                      }).length;
                      final contactedPct = assignedCount > 0
                          ? (contactedCount / assignedCount * 100).round()
                          : 0;
                      final interestedCount = userLeads.where((l) {
                        final status = (l['status'] ?? '')
                            .toString()
                            .toLowerCase();
                        return status == 'interested';
                      }).length;
                      final actionsDone = userLeads.where((l) {
                        final isDone = (l['isDone'] as bool?) ?? false;
                        final timeline = l['timeline'] as List?;
                        return isDone ||
                            (timeline != null && timeline.isNotEmpty);
                      }).length;
                      final convertedCount = userLeads.where((l) {
                        final status = (l['status'] ?? '')
                            .toString()
                            .toLowerCase();
                        return status.contains('convert');
                      }).length;
                      final pendingCount = userLeads.where((l) {
                        final isDone = (l['isDone'] as bool?) ?? false;
                        final status = (l['status'] ?? '')
                            .toString()
                            .toLowerCase();
                        return !isDone &&
                            (status == 'new' ||
                                status == 'claimed' ||
                                status == 'follow-up' ||
                                status.contains('pending'));
                      }).length;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFF2F4F7)),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 160,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    user.roleLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: user.isAdminRole
                                          ? const Color(0xFF4338CA)
                                          : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text('$assignedCount', style: _tblCell),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                assignedCount > 0
                                    ? '$contactedCount ($contactedPct%)'
                                    : '—',
                                style: _tblCell,
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text('$interestedCount', style: _tblCell),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text('$actionsDone', style: _tblCell),
                            ),
                            SizedBox(
                              width: 95,
                              child: Text(
                                '$convertedCount',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '$pendingCount',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: pendingCount == 0
                                      ? const Color(0xFF667085)
                                      : const Color(0xFFB42318),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveExecutivesSnapshot(List<DashboardUserModel> activeUsers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Team Members & Role Distribution',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Real-time status of Admins and HR & Operation Managers currently active',
            style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 14),
          if (activeUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No active team members found.',
                style: TextStyle(color: Color(0xFF667085), fontSize: 13),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 640;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: activeUsers.map((user) {
                    return Container(
                      width: isNarrow ? double.infinity : (c.maxWidth - 24) / 3,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEAECF0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFEEF0FF),
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4338CA),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.roleLabel.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: user.isAdminRole
                                        ? const Color(0xFF4338CA)
                                        : const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAuditLogCard(DashboardCubit cubit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Append-Only Security & Admin Audit Log (PR-7.1)',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Every sign-in, import, bulk assignment, role change, device reset, and watermarked export is permanently recorded.',
            style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 12),
          if (cubit.auditEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No audit entries logged yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
            )
          else
            ...cubit.auditEntries.take(8).map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF2F4F7))),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF0FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${entry.action} — ${entry.target}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF344054),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${entry.actor} · ${entry.timestamp}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

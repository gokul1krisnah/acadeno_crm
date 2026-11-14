import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_time_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
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
  Stream<QuerySnapshot<Map<String, dynamic>>>? _usersStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _leadsStream;

  static bool _leadIsDone(dynamic val) {
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  static bool _leadHasTimeline(dynamic val) {
    if (val is Iterable) return val.isNotEmpty;
    if (val is String) return val.trim().isNotEmpty;
    return false;
  }

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
          title: Text(
            'Super Admin Watermarked Export',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only Super Admin may export lead data. The exported report is watermarked with your identity and timestamp, and your typed reason is recorded in the append-only audit log.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF475467),
                    height: 1.4,
                  ),
                ),
                const Gap(14),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 14),
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
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF8144),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                      'Generated watermarked team report. Logged in security audit trail.',
                );
                Navigator.pop(ctx);
              },
              child: Text(
                'Generate Watermarked CSV',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
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
          stream: _usersStream ??= cubit.watchAllUsers(),
          builder: (context, usersSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _leadsStream ??= cubit.watchAllLeads(),
              builder: (context, leadsSnap) {
                if ((usersSnap.connectionState == ConnectionState.waiting &&
                        !usersSnap.hasData) ||
                    (leadsSnap.connectionState == ConnectionState.waiting &&
                        !leadsSnap.hasData)) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFEF8144)),
                          Gap(16),
                          Text(
                            'Loading team analytics and performance...',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final hasError = (usersSnap.hasError && !usersSnap.hasData) ||
                    (leadsSnap.hasError && !leadsSnap.hasData);

                if (hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFDC2626),
                            size: 36,
                          ),
                          const Gap(12),
                          Text(
                            'Could not load team data: ${usersSnap.error ?? leadsSnap.error}',
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 13.5,
                            ),
                          ),
                          const Gap(12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _usersStream = cubit.watchAllUsers();
                                _leadsStream = cubit.watchAllLeads();
                              });
                            },
                            icon: const Icon(CupertinoIcons.refresh, size: 16),
                            label: const Text('Retry Loading Team'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allUsers = cubit.mapAndSortUsers(usersSnap.data);
                final activeUsers = allUsers.where((u) => u.isActive).toList();
                final rawLeads =
                    leadsSnap.data?.docs.map((d) => d.data()).toList() ??
                    <Map<String, dynamic>>[];
                final filteredLeads = _filterLeadsByDate(rawLeads);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section (Figma Node 1363:2004)
                        _buildHeader(maxWidth, activeUsers, filteredLeads),
                        const Gap(32),

                        // 5 KPI Summary Cards (Matching Dashboard Page)
                        _buildStatCards(maxWidth, filteredLeads, activeUsers),
                        const Gap(32),

                        // Executive Performance Comparison Table (Figma Node 1363:2068)
                        _buildTeamPerformanceCard(maxWidth, activeUsers, filteredLeads),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // HEADER (Figma Node 1363:2004)
  // ===========================================================================
  Widget _buildHeader(
    double maxWidth,
    List<DashboardUserModel> activeUsers,
    List<Map<String, dynamic>> filteredLeads,
  ) {
    final titleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Management',
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.75,
            height: 36 / 30,
          ),
        ),
        const Gap(4),
        Text(
          'Real-time team analytics, live conversion tracking, and member performance (FR-6.3)',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
            height: 20 / 14,
          ),
        ),
      ],
    );

    final exportBtn = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showWatermarkedExportModal(activeUsers, filteredLeads),
            borderRadius: BorderRadius.circular(9999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.download_rounded,
                    size: 14,
                    color: Color(0xFF475569),
                  ),
                  const Gap(8),
                  Flexible(
                    child: Text(
                      maxWidth < 360
                          ? 'Export Report'
                          : (maxWidth < 420
                              ? 'Watermarked Export'
                              : 'Watermarked Export (Super Admin)'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                        letterSpacing: -0.0137,
                        height: 20 / 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (maxWidth < 780) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleCol,
          const Gap(14),
          exportBtn,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleCol),
        const Gap(16),
        exportBtn,
      ],
    );
  }

  // ===========================================================================
  // 5 KPI SUMMARY CARDS (Exact match to Dashboard Page boxes, width & height)
  // ===========================================================================
  Widget _buildStatCards(
    double maxWidth,
    List<Map<String, dynamic>> leads,
    List<DashboardUserModel> activeUsers,
  ) {
    final totalLeads = leads.length;
    final totalAssigned = leads.where((l) {
      final uid = l['assignedToUid'];
      final name = l['assignedToName'] ?? l['assignedTo'];
      return (uid != null && uid.toString().trim().isNotEmpty) ||
          (name != null && name.toString().trim().isNotEmpty && name != '—');
    }).length;

    final contactedCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      final isDone = _leadIsDone(l['isDone']);
      return status != 'new' && status != 'unassigned' || isDone;
    }).length;

    final contactedPct = totalAssigned > 0
        ? (contactedCount / totalAssigned * 100).round()
        : (totalLeads > 0 ? (contactedCount / totalLeads * 100).round() : 0);

    final evaluatedFollowUps = leads
        .where((l) => !_leadIsDone(l['isDone']))
        .map((l) {
          final eval = FollowUpTimeHelper.evaluate(
            rawFollowUpTime: l['followUpTime'],
            assignedDateKey: l['assignedDateKey'],
            assignedDateLabel: l['assignedDateLabel'],
            assignedAt: l['assignedAt'],
            updatedAt: l['updatedAt'],
            createdAt: l['createdAt'],
            status: (l['status'] ?? '').toString(),
          );
          return (lead: l, eval: eval);
        })
        .toList();

    final followUpsCount = evaluatedFollowUps.where((e) {
      final s = (e.lead['status'] ?? '').toString().toLowerCase();
      return e.eval.bucket == FollowUpBucket.today ||
          s == 'follow-up' ||
          s == 'claimed';
    }).length;

    final overdueCount = evaluatedFollowUps
        .where((e) => e.eval.isOverdue)
        .length;

    final convertedCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      return status.contains('convert');
    }).length;

    final conversionPct = totalLeads > 0
        ? (convertedCount / totalLeads * 100).round()
        : 0;

    final cards = [
      _TeamStatCard(
        label: 'Total Leads',
        valueText: '$totalLeads',
        sub: '$totalAssigned assigned to team',
        color: const Color(0xFF4338CA),
        svgAsset: 'assets/svgs/stat_total_leads.svg',
        isSolidHero: true,
      ),
      _TeamStatCard(
        label: 'Calls / Contacted',
        valueText: '$contactedCount/$totalAssigned',
        sub: '$contactedPct% of assigned',
        color: const Color(0xFF3F3FB4),
        svgAsset: 'assets/svgs/stat_phone.svg',
      ),
      _TeamStatCard(
        label: 'Follow-ups Due',
        valueText: '$followUpsCount',
        sub: 'Across ${activeUsers.length} active members',
        color: const Color(0xFFE96849),
        svgAsset: 'assets/svgs/stat_calendar_check.svg',
      ),
      _TeamStatCard(
        label: 'Overdue / Pending',
        valueText: '$overdueCount',
        sub: 'Requires team attention',
        color: const Color(0xFF4C0CBF),
        svgAsset: 'assets/svgs/stat_hourglass.svg',
      ),
      _TeamStatCard(
        label: 'Converted Leads',
        valueText: '$convertedCount',
        sub: '$conversionPct% conversion rate',
        color: const Color(0xFF22C55E),
        svgAsset: 'assets/svgs/stat_star.svg',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // From Tablet (768px -> w >= 520) through Laptop (1024px) to Laptop Large (1440px+),
        // keep all 5 KPI cards in a single horizontal row matching the 1440px layout.
        if (w >= 520) {
          final gap = w >= 1000 ? 16.0 : (w >= 700 ? 12.0 : 8.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) Gap(gap),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        if (w >= 480) {
          final cardW = ((w - 12) / 2).floorToDouble() - 1;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < cards.length; i++)
                SizedBox(
                  width: i == cards.length - 1 ? w : cardW,
                  child: cards[i],
                ),
            ],
          );
        }

        final cardW = ((w - 10) / 2).floorToDouble() - 1;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < cards.length; i++)
              SizedBox(
                width: i == cards.length - 1 ? w : (w < 320 ? w : cardW),
                child: cards[i],
              ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // EXECUTIVE PERFORMANCE COMPARISON TABLE (Figma Node 1363:2068)
  // ===========================================================================
  Widget _buildTeamPerformanceCard(
    double maxWidth,
    List<DashboardUserModel> activeUsers,
    List<Map<String, dynamic>> leads,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Title & Date Range Dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Executive Performance Comparison (FR-6.3)',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.0195,
                        height: 28 / 20,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      'Assigned vs Contacted, Interested, Completed, Converted, and Pending',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                        letterSpacing: -0.0137,
                        height: 20 / 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDateRange,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(
                        CupertinoIcons.chevron_down,
                        size: 12,
                        color: Color(0xFF64748B),
                      ),
                      isDense: true,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
                        height: 20 / 14,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'All Time',
                          child: Text('All Time'),
                        ),
                        DropdownMenuItem(value: 'Today', child: Text('Today')),
                        DropdownMenuItem(
                          value: 'This week',
                          child: Text('This week'),
                        ),
                        DropdownMenuItem(
                          value: 'This month',
                          child: Text('This month'),
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
          ),

          if (activeUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Text(
                  'No active team members registered yet. Add team accounts in User Management.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: maxWidth > 1050 ? maxWidth : 1050.0,
                child: Column(
                  children: [
                    // Table Header Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          top: BorderSide(color: Color(0xFFF1F5F9)),
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildTableHeaderCell('TEAM MEMBER', flex: 26, isCenter: false),
                          _buildTableHeaderCell('ASSIGNED', flex: 14, isCenter: false),
                          _buildTableHeaderCell('CONTACTED', flex: 16, isCenter: false),
                          _buildTableHeaderCell('INTERESTED', flex: 14, isCenter: true),
                          _buildTableHeaderCell('ACTIONS DONE', flex: 16, isCenter: true),
                          _buildTableHeaderCell('CONVERTED', flex: 14, isCenter: true),
                          _buildTableHeaderCell('PENDING', flex: 14, isCenter: true),
                        ],
                      ),
                    ),

                    // Table Body Rows
                    ...activeUsers.map((user) {
                      final isLast = user == activeUsers.last;

                      final userLeads = leads.where((l) {
                        final assignedUid = l['assignedToUid'];
                        final assignedName =
                            l['assignedToName'] ?? l['assignedTo'];
                        final ownerUid = l['ownerUid'];
                        return assignedUid == user.uid ||
                            ownerUid == user.uid ||
                            (assignedName != null &&
                                assignedName
                                        .toString()
                                        .trim()
                                        .toLowerCase() ==
                                    user.name.trim().toLowerCase());
                      }).toList();

                      final assignedCount = userLeads.length;
                      final contactedCount = userLeads.where((l) {
                        final status = (l['status'] ?? '')
                            .toString()
                            .toLowerCase();
                        final isDone = _leadIsDone(l['isDone']);
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
                        final isDone = _leadIsDone(l['isDone']);
                        final hasTl = _leadHasTimeline(l['timeline']);
                        return isDone || hasTl;
                      }).length;
                      final convertedCount = userLeads.where((l) {
                        final status = (l['status'] ?? '')
                            .toString()
                            .toLowerCase();
                        return status.contains('convert');
                      }).length;
                      final pendingCount = userLeads.where((l) {
                        final isDone = _leadIsDone(l['isDone']);
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
                          horizontal: 32,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFF1F5F9),
                                  ),
                                ),
                        ),
                        child: Row(
                          children: [
                            // Team Member Name + Role
                            Expanded(
                              flex: 26,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                      height: 24 / 16,
                                    ),
                                  ),
                                  const Gap(2),
                                  Text(
                                    user.isAdminRole
                                        ? 'ADMIN'
                                        : 'HR & OPERATION MANAGER',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: user.isAdminRole
                                          ? const Color(0xFF6366F1)
                                          : const Color(0xFF3B82F6),
                                      height: 16 / 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Assigned
                            Expanded(
                              flex: 14,
                              child: Text(
                                '$assignedCount',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1E293B),
                                  height: 20 / 14,
                                ),
                              ),
                            ),

                            // Contacted
                            Expanded(
                              flex: 16,
                              child: Text(
                                assignedCount > 0
                                    ? '$contactedCount ($contactedPct%)'
                                    : 'None',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1E293B),
                                  height: 20 / 14,
                                ),
                              ),
                            ),

                            // Interested
                            Expanded(
                              flex: 14,
                              child: Text(
                                '$interestedCount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1E293B),
                                  height: 20 / 14,
                                ),
                              ),
                            ),

                            // Actions Done
                            Expanded(
                              flex: 16,
                              child: Text(
                                '$actionsDone',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1E293B),
                                  height: 20 / 14,
                                ),
                              ),
                            ),

                            // Converted
                            Expanded(
                              flex: 14,
                              child: Text(
                                '$convertedCount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF16A34A),
                                  height: 20 / 14,
                                ),
                              ),
                            ),

                            // Pending
                            Expanded(
                              flex: 14,
                              child: Text(
                                '$pendingCount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1E293B),
                                  height: 20 / 14,
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

  Widget _buildTableHeaderCell(
    String label, {
    required int flex,
    required bool isCenter,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: isCenter ? TextAlign.center : TextAlign.left,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.6,
          height: 16 / 12,
        ),
      ),
    );
  }
}

class _TeamStatCard extends StatefulWidget {
  final String label;
  final String valueText;
  final String sub;
  final Color color;
  final String svgAsset;
  final bool isSolidHero;

  const _TeamStatCard({
    required this.label,
    required this.valueText,
    required this.sub,
    required this.color,
    required this.svgAsset,
    this.isSolidHero = false,
  });

  @override
  State<_TeamStatCard> createState() => _TeamStatCardState();
}

class _TeamStatCardState extends State<_TeamStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final isCompact = cardW < 130;
        final isMedium = cardW >= 130 && cardW < 180;

        final cardPadding = isCompact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
            : (isMedium
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 16)
                  : const EdgeInsets.all(20));
        final minCardHeight = isCompact ? 96.0 : (isMedium ? 112.0 : 125.0);
        final labelFontSize = isCompact ? 11.0 : (isMedium ? 12.5 : 14.0);
        final valueFontSize = isCompact ? 22.0 : (isMedium ? 28.0 : 34.0);
        final subFontSize = isCompact ? 8.5 : (isMedium ? 9.5 : 10.0);
        final svgSize = isCompact ? 13.0 : (isMedium ? 15.0 : 18.0);

        if (widget.isSolidHero) {
          return MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
              constraints: BoxConstraints(minHeight: minCardHeight),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.38),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -48,
                    top: -48,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: _isHovered ? 1.15 : 1.0,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x0DFFFFFF),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xE6FFFFFF),
                                    fontSize: labelFontSize,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.5195,
                                  ),
                                ),
                              ),
                            ),
                            const Gap(4),
                            AnimatedScale(
                              duration: const Duration(milliseconds: 200),
                              scale: _isHovered ? 1.12 : 1.0,
                              curve: Curves.easeOutBack,
                              child: SvgPicture.asset(
                                widget.svgAsset,
                                width: svgSize,
                                height: svgSize,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Gap(isCompact ? 6 : 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.valueText,
                                style: GoogleFonts.inter(
                                  fontSize: valueFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Gap(4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.sub,
                                maxLines: 1,
                                style: GoogleFonts.inter(
                                  color: const Color(0xCCFFFFFF),
                                  fontSize: subFontSize,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.2344,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
            constraints: BoxConstraints(minHeight: minCardHeight),
            padding: cardPadding,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered
                    ? widget.color.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8E5),
                width: _isHovered ? 1.2 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                      const BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x05000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          style: GoogleFonts.inter(
                            color: _isHovered
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF718096),
                            fontSize: labelFontSize,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const Gap(4),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: _isHovered ? 1.12 : 1.0,
                      curve: Curves.easeOutBack,
                      child: SvgPicture.asset(
                        widget.svgAsset,
                        width: svgSize,
                        height: svgSize,
                      ),
                    ),
                  ],
                ),
                Gap(isCompact ? 6 : 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.valueText,
                        style: GoogleFonts.inter(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w700,
                          color: widget.color,
                        ),
                      ),
                    ),
                    const Gap(4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.sub,
                        maxLines: 1,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFA0AEC0),
                          fontSize: subFontSize,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

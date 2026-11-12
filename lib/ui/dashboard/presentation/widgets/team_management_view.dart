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

                        // 4 KPI Summary Cards (Figma Node 1363:2236)
                        _buildStatCards(maxWidth, filteredLeads),
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

    final exportBtn = Container(
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
                Text(
                  'Watermarked Export (Super Admin)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                    letterSpacing: -0.0137,
                    height: 20 / 14,
                  ),
                ),
              ],
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
  // 4 KPI SUMMARY CARDS (Figma Node 1363:2236)
  // ===========================================================================
  Widget _buildStatCards(double maxWidth, List<Map<String, dynamic>> leads) {
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
        : (leads.isNotEmpty
              ? (contactedCount / leads.length * 100).round()
              : 0);

    final convertedCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      return status.contains('convert');
    }).length;

    final conversionPct = totalAssigned > 0
        ? (convertedCount / totalAssigned * 100).round()
        : (leads.isNotEmpty
              ? (convertedCount / leads.length * 100).round()
              : 0);

    final pendingCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      final isDone = _leadIsDone(l['isDone']);
      return !isDone &&
          (status == 'new' ||
              status == 'claimed' ||
              status == 'follow-up' ||
              status.contains('pending'));
    }).length;

    final card1 = _buildTotalAssignedCard(
      assignedCount: totalAssigned > 0 ? totalAssigned : leads.length,
      totalPool: leads.length,
    );

    final card2 = _buildContactedCard(
      contactedCount: contactedCount,
      contactedPct: contactedPct,
    );

    final card3 = _buildPendingCard(pendingCount: pendingCount);

    final card4 = _buildConvertedCard(
      convertedCount: convertedCount,
      conversionPct: conversionPct,
    );

    if (maxWidth >= 1080) {
      return Row(
        children: [
          Expanded(child: card1),
          const Gap(24),
          Expanded(child: card2),
          const Gap(24),
          Expanded(child: card3),
          const Gap(24),
          Expanded(child: card4),
        ],
      );
    }

    if (maxWidth >= 640) {
      final cardWidth = ((maxWidth - 24) / 2).floorToDouble();
      return Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          SizedBox(width: cardWidth, child: card1),
          SizedBox(width: cardWidth, child: card2),
          SizedBox(width: cardWidth, child: card3),
          SizedBox(width: cardWidth, child: card4),
        ],
      );
    }

    return Column(
      children: [
        card1,
        const Gap(16),
        card2,
        const Gap(16),
        card3,
        const Gap(16),
        card4,
      ],
    );
  }

  // Card 1: Total Assigned (Hero Indigo, Node 1363:2237)
  Widget _buildTotalAssignedCard({
    required int assignedCount,
    required int totalPool,
  }) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF4338CA),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -48,
            top: -48,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Assigned',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: -0.5195,
                        height: 20 / 14,
                      ),
                    ),
                    const Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$assignedCount Leads',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 40 / 36,
                        ),
                      ),
                    ),
                    const Gap(4),
                    Text(
                      '$totalPool total in pool',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: -0.2344,
                        height: 15 / 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 2: Contacted (Node 1363:2249)
  Widget _buildContactedCard({
    required int contactedCount,
    required int contactedPct,
  }) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contacted',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF718096),
                  letterSpacing: -0.5469,
                  height: 20 / 14,
                ),
              ),
              const Icon(
                CupertinoIcons.phone_fill,
                size: 16,
                color: Color(0xFF3F3FB4),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$contactedCount ',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3F3FB4),
                          height: 40 / 36,
                        ),
                      ),
                      TextSpan(
                        text: '($contactedPct%)',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3F3FB4),
                          height: 40 / 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(4),
              Text(
                'Goal: >80%',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFA0AEC0),
                  letterSpacing: -0.3125,
                  height: 15 / 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 3: Pending follow-ups (Node 1363:2271)
  Widget _buildPendingCard({required int pendingCount}) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pending follow-ups',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF718096),
                  letterSpacing: -0.4648,
                  height: 20 / 14,
                ),
              ),
              const Icon(
                CupertinoIcons.hourglass,
                size: 16,
                color: Color(0xFF4C0CBF),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$pendingCount',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4C0CBF),
                    height: 40 / 36,
                  ),
                ),
              ),
              const Gap(4),
              Text(
                pendingCount > 0 ? 'Requires attention' : 'All clear',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFA0AEC0),
                  letterSpacing: -0.2637,
                  height: 15 / 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 4: Converted Leads (Node 1363:2282)
  Widget _buildConvertedCard({
    required int convertedCount,
    required int conversionPct,
  }) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Converted Leads',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF718096),
                  letterSpacing: -0.5605,
                  height: 20 / 14,
                ),
              ),
              const Icon(
                CupertinoIcons.star_fill,
                size: 16,
                color: Color(0xFF22C55E),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$convertedCount',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF22C55E),
                    height: 40 / 36,
                  ),
                ),
              ),
              const Gap(4),
              Text(
                '$conversionPct% conversion rate',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFA0AEC0),
                  height: 15 / 10,
                ),
              ),
            ],
          ),
        ],
      ),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: maxWidth > 1050 ? maxWidth : 1050,
                ),
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
                                    : '—',
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

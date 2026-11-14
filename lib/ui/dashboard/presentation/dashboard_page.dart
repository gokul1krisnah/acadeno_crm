import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/core/services/firestore_stream_cache.dart';
import 'package:gap/gap.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_time_helper.dart';
import 'package:acadeno_crm/core/utils/url_dialer_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:acadeno_crm/shared/utilities/link_launcher.dart';
import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:acadeno_crm/shared/theme/app_typography.dart';
import 'package:acadeno_crm/shared/widgets/staff_watermark_overlay.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/dashboard_cubit.dart';
import '../application/dashboard_state.dart';
import '../data/model/dashboard_user_model.dart';
import '../data/repository/dashboard_repo.dart';
import '../data/sources/dashboard_rds.dart';

import 'package:acadeno_crm/ui/leads/application/admin_leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';
import 'package:acadeno_crm/ui/leads/data/repository/leads_repo.dart';
import 'package:acadeno_crm/ui/leads/data/sources/leads_rds.dart';

import 'widgets/campaigns_view.dart';
import 'widgets/figma_calendar_dialog.dart';
import 'widgets/college_visits_view.dart';
import 'widgets/follow_ups_view.dart';
import 'widgets/import_leads_view.dart';
import 'widgets/leads_assign_view.dart';
import 'widgets/team_management_view.dart';
import 'widgets/user_management_view.dart';
import 'widgets/settings_view.dart';

const _primary = Color(0xFF3F37C9);
const _orangeAccent = Color(0xFFEF8144);
const _bg = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _muted = Color(0xFF64748B);
const _text = Color(0xFF0F172A);

@RoutePage()
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final rds = DashboardRds();
    final repository = DashboardRepository(rds);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DashboardCubit(repository)),
        BlocProvider(
          create: (_) => AdminLeadsCubit(LeadsRepository(LeadsRds())),
        ),
      ],
      child: const StaffWatermarkOverlay(child: _DashboardView()),
    );
  }
}

class _NavItem {
  final String svgAsset;
  final IconData fallbackIcon;
  final String label;

  const _NavItem({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.label,
  });
}

class _FigmaRightBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  const _FigmaRightBorderPainter({
    required this.color,
    this.radius = 12.0,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent || color.a == 0.0 || strokeWidth <= 0) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    final r = radius;
    final t = strokeWidth;

    final path = Path();
    // Start at top tangent of outer arc
    path.moveTo(w - r, 0);

    // Outer top-right arc (circular radius r)
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);

    // Outer straight right vertical line
    path.lineTo(w, h - r);

    // Outer bottom-right arc (circular radius r)
    path.arcToPoint(
      Offset(w - r, h),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // Inner bottom-right elliptical arc (Rx = r - t, Ry = r)
    path.arcToPoint(
      Offset(w - t, h - r),
      radius: Radius.elliptical(r - t, r),
      clockwise: false,
    );

    // Inner straight right vertical line
    path.lineTo(w - t, r);

    // Inner top-right elliptical arc (Rx = r - t, Ry = r)
    path.arcToPoint(
      Offset(w - r, 0),
      radius: Radius.elliptical(r - t, r),
      clockwise: false,
    );

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FigmaRightBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _SidebarNavItem extends StatefulWidget {
  final _NavItem item;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  const _SidebarNavItem({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final item = widget.item;
    final compact = widget.compact;

    // Hover & selected background fill; no click splash on nav bar items
    final Color bgColor = isSelected
        ? const Color(0xFFFFEDE2)
        : (_isHovered ? const Color(0xFFFFF6F0) : Colors.transparent);

    final Color contentColor = isSelected
        ? _orangeAccent
        : (_isHovered ? _orangeAccent : const Color(0xFF475569));

    final Color iconColor = isSelected
        ? _orangeAccent
        : (_isHovered ? _orangeAccent : const Color(0xFF64748B));

    // Exact Figma Specs:
    // width: 223 (in 240px sidebar: 8.5px horizontal margin on each side)
    // height: 44
    // border-radius: 12px
    // border-right-width: 4px
    // padding: 12px vertical, 16px horizontal
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.0 : 8.5,
        vertical: 2.0,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: compact ? 40 : 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              foregroundPainter: _FigmaRightBorderPainter(
                color: isSelected ? _orangeAccent : Colors.transparent,
                radius: 12.0,
                strokeWidth: 4.0,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16,
                  compact ? 10 : 12,
                  compact ? 10 : 16,
                  compact ? 10 : 12,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: compact ? 18 : 20,
                      height: compact ? 18 : 20,
                      child: Center(
                        child: SvgPicture.asset(
                          item.svgAsset,
                          width: compact ? 16 : 18,
                          height: compact ? 16 : 18,
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            iconColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    Gap(compact ? 9 : 12),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: compact ? 13 : 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : (_isHovered
                                    ? FontWeight.w600
                                    : FontWeight.w500),
                          color: contentColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasAutoHealedRole = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _primaryNav = [
    _NavItem(
      svgAsset: 'assets/svgs/dashboard.svg',
      fallbackIcon: Icons.tag_rounded,
      label: 'Dashboard',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/leads.svg',
      fallbackIcon: Icons.format_list_bulleted_rounded,
      label: 'Leads & Assign',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/campaigns.svg',
      fallbackIcon: Icons.view_agenda_outlined,
      label: 'Campaigns',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/followups.svg',
      fallbackIcon: Icons.subdirectory_arrow_right_rounded,
      label: 'Follow-ups',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/collegevisits.svg',
      fallbackIcon: Icons.people_alt_outlined,
      label: 'College Visits',
    ),
  ];

  static const _generalNav = [
    _NavItem(
      svgAsset: 'assets/svgs/import.svg',
      fallbackIcon: Icons.file_upload_outlined,
      label: 'Import',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/teammanagement.svg',
      fallbackIcon: Icons.help_outline_rounded,
      label: 'Team Management',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/usermanagement.svg',
      fallbackIcon: Icons.badge_outlined,
      label: 'User Management',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/settings.svg',
      fallbackIcon: Icons.settings_outlined,
      label: 'Settings',
    ),
  ];

  DateTime? _selectedDashboardDate;

  DateTime get _effectiveDashboardDate {
    final n = _selectedDashboardDate ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String get _today {
    return DateFormat('EEEE, d MMMM').format(_effectiveDashboardDate);
  }

  Future<void> _pickDashboardDate() async {
    final now = DateTime.now();
    final picked = await showFigmaCalendarDialog(
      context: context,
      initialDate: _selectedDashboardDate ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final normalizedPicked = DateTime(picked.year, picked.month, picked.day);
      final normalizedToday = DateTime(now.year, now.month, now.day);
      setState(() {
        _selectedDashboardDate = normalizedPicked == normalizedToday
            ? null
            : normalizedPicked;
      });
      if (mounted && !normalizedPicked.isBefore(normalizedToday)) {
        context.read<AdminLeadsCubit>().selectCustomAssignmentDate(
          normalizedPicked,
        );
      }
    }
  }

  static String? _extractDateKey(dynamic val, {DateTime? now}) {
    if (val == null) return null;
    if (val is Timestamp) {
      return LeadDateHelper.dateKey(val.toDate());
    }
    if (val is DateTime) {
      return LeadDateHelper.dateKey(val);
    }
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty || s == '—' || s.toLowerCase() == 'never') return null;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
        return s.substring(0, 10);
      }
      final iso = DateTime.tryParse(s);
      if (iso != null) {
        return LeadDateHelper.dateKey(iso);
      }
      final parsed = LeadDateHelper.parseStamp(s, now: now);
      if (parsed != null) {
        return LeadDateHelper.dateKey(parsed.dt);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _filterLeadsForDashboardDate({
    required List<Map<String, dynamic>> rawLeads,
    required List<Map<String, dynamic>> rawAssignments,
    required List<Map<String, dynamic>> rawCallLogs,
    required DateTime targetDate,
  }) {
    final now = DateTime.now();
    final todayDay = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final targetKey = LeadDateHelper.dateKey(targetDay);
    final todayKey = LeadDateHelper.dateKey(todayDay);

    final assignmentsOnTarget = <String, Map<String, dynamic>>{};
    for (final a in rawAssignments) {
      final aKey =
          _extractDateKey(a['dateKey'], now: now) ??
          _extractDateKey(a['assignedAt'], now: now);
      final leadId = (a['leadId'] ?? '').toString().trim();
      if (aKey == targetKey && leadId.isNotEmpty) {
        assignmentsOnTarget[leadId] = a;
      }
    }

    final callLogsOnTargetByLeadId = <String, Map<String, dynamic>>{};
    final callLogsOnTargetByName = <String, Map<String, dynamic>>{};
    for (final c in rawCallLogs) {
      final cKey = _extractDateKey(c['createdAt'] ?? c['timestamp'], now: now);
      if (cKey == targetKey) {
        final leadId = (c['leadId'] ?? '').toString().trim();
        final leadName = (c['leadName'] ?? '').toString().trim().toLowerCase();
        if (leadId.isNotEmpty) {
          callLogsOnTargetByLeadId.putIfAbsent(leadId, () => c);
        }
        if (leadName.isNotEmpty) {
          callLogsOnTargetByName.putIfAbsent(leadName, () => c);
        }
      }
    }

    final result = <Map<String, dynamic>>[];
    final includedLeadIds = <String>{};

    for (final l in rawLeads) {
      final leadId = (l['id'] ?? '').toString().trim();
      final leadNameLower = (l['name'] ?? l['studentName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final assignedDateKey =
          _extractDateKey(l['assignedDateKey'], now: now) ??
          _extractDateKey(l['assignedDateLabel'], now: now);
      final assignedAtKey = _extractDateKey(l['assignedAt'], now: now);
      final createdAtKey = _extractDateKey(l['createdAt'], now: now);
      final lastCalledKey =
          _extractDateKey(l['lastCalledAt'], now: now) ??
          _extractDateKey(l['lastContactAt'], now: now);
      final updatedAtKey = _extractDateKey(l['updatedAt'], now: now);

      String? timelineOutcomeOnTarget;
      String? timelineCallExecOnTarget;
      String? timelineAssignedExecOnTarget;
      bool wasAssignedOnTargetInTimeline = false;
      bool hasTimelineEntryOnTarget = false;
      bool hasAnyTimelineDate = false;

      final rawTimeline = l['timeline'];
      if (rawTimeline is Iterable) {
        for (final item in rawTimeline) {
          final entryStr = item.toString().trim();
          if (entryStr.isEmpty) continue;
          final parts = entryStr.split('·').map((s) => s.trim()).toList();
          final stampPart = parts.first;
          final actionPart = parts.length > 1
              ? parts.sublist(1).join(' · ')
              : '';

          final entryKey = _extractDateKey(stampPart, now: now);
          if (entryKey != null) hasAnyTimelineDate = true;

          final forMatch = RegExp(
            r'\(For\s+([^\)]+)\)',
            caseSensitive: false,
          ).firstMatch(actionPart);
          final forKey = forMatch != null
              ? _extractDateKey(forMatch.group(1), now: now)
              : null;
          if (forKey != null) hasAnyTimelineDate = true;

          if (entryKey == targetKey) {
            hasTimelineEntryOnTarget = true;
            final logMatch = RegExp(
              r'^(.+?)\s+logged by\s+([^\(]+)',
              caseSensitive: false,
            ).firstMatch(actionPart);
            if (logMatch != null) {
              timelineOutcomeOnTarget ??= logMatch.group(1)!.trim();
              timelineCallExecOnTarget ??= logMatch.group(2)!.trim();
            }
            final claimMatch = RegExp(
              r'Walk-in claimed by\s+([^\(]+)',
              caseSensitive: false,
            ).firstMatch(actionPart);
            if (claimMatch != null) {
              wasAssignedOnTargetInTimeline = true;
              timelineAssignedExecOnTarget ??= claimMatch.group(1)!.trim();
            }
          }

          if (forKey == targetKey ||
              (entryKey == targetKey &&
                  (actionPart.toLowerCase().startsWith('assigned to ') ||
                      actionPart.toLowerCase().startsWith('reassigned ')))) {
            wasAssignedOnTargetInTimeline = true;
            final assignMatch = RegExp(
              r'(?:Assigned to|to)\s+(.+?)\s+by\s+',
              caseSensitive: false,
            ).firstMatch(actionPart);
            if (assignMatch != null) {
              timelineAssignedExecOnTarget ??= assignMatch.group(1)!.trim();
            }
          }
        }
      }

      final matchingAssign = leadId.isNotEmpty
          ? assignmentsOnTarget[leadId]
          : null;
      final matchingCallLog =
          (leadId.isNotEmpty ? callLogsOnTargetByLeadId[leadId] : null) ??
          (leadNameLower.isNotEmpty
              ? callLogsOnTargetByName[leadNameLower]
              : null);

      final hasAssignedMatch =
          (assignedDateKey == targetKey) ||
          (assignedDateKey == null && assignedAtKey == targetKey) ||
          wasAssignedOnTargetInTimeline ||
          matchingAssign != null;
      final hasCallMatch =
          (lastCalledKey == targetKey) ||
          (timelineOutcomeOnTarget != null) ||
          (matchingCallLog != null);
      final hasCreatedMatch =
          (createdAtKey == targetKey) &&
          (assignedDateKey == null || assignedDateKey == targetKey);
      final hasUpdatedMatch =
          (updatedAtKey == targetKey) &&
          (assignedDateKey == null || assignedDateKey == targetKey);
      final hasNoDatesAtAll =
          assignedDateKey == null &&
          assignedAtKey == null &&
          createdAtKey == null &&
          lastCalledKey == null &&
          updatedAtKey == null &&
          !hasAnyTimelineDate;

      final includeLead =
          hasAssignedMatch ||
          hasCallMatch ||
          hasCreatedMatch ||
          hasUpdatedMatch ||
          hasTimelineEntryOnTarget ||
          (hasNoDatesAtAll && targetKey == todayKey);

      if (!includeLead) continue;

      final projected = Map<String, dynamic>.from(l);

      if (matchingAssign != null) {
        projected['assignedToUid'] =
            matchingAssign['executiveUid'] ?? projected['assignedToUid'];
        projected['assignedToName'] =
            matchingAssign['executiveName'] ?? projected['assignedToName'];
        projected['assignedTo'] = projected['assignedToName'];
        projected['assignedDateKey'] = targetKey;
      } else if (timelineAssignedExecOnTarget != null &&
          assignedDateKey != targetKey) {
        projected['assignedToName'] = timelineAssignedExecOnTarget;
        projected['assignedTo'] = timelineAssignedExecOnTarget;
        projected['assignedDateKey'] = targetKey;
      } else if (!hasAssignedMatch &&
          !hasCallMatch &&
          assignedDateKey != null &&
          assignedDateKey != targetKey) {
        // Lead was only created on targetKey and assigned on a different date
        projected['assignedToUid'] = null;
        projected['assignedToName'] = '—';
        projected['assignedTo'] = '—';
      }

      if (matchingCallLog != null) {
        projected['status'] =
            (matchingCallLog['outcome'] ?? projected['status']).toString();
        projected['isDone'] = true;
        final curExec = (projected['assignedToName'] ?? '').toString().trim();
        if ((curExec.isEmpty || curExec == '—') &&
            matchingCallLog['executiveName'] != null) {
          projected['assignedToUid'] = matchingCallLog['executiveUid'];
          projected['assignedToName'] = matchingCallLog['executiveName'];
          projected['assignedTo'] = matchingCallLog['executiveName'];
        }
      } else if (timelineOutcomeOnTarget != null) {
        projected['status'] = timelineOutcomeOnTarget;
        projected['isDone'] = true;
        final curExec = (projected['assignedToName'] ?? '').toString().trim();
        if ((curExec.isEmpty || curExec == '—') &&
            timelineCallExecOnTarget != null) {
          projected['assignedToName'] = timelineCallExecOnTarget;
          projected['assignedTo'] = timelineCallExecOnTarget;
        }
      } else if (matchingAssign != null &&
          (matchingAssign['isDone'] == true ||
              matchingAssign['lastOutcome'] != null)) {
        projected['status'] =
            (matchingAssign['lastOutcome'] ??
                    matchingAssign['leadStatus'] ??
                    projected['status'])
                .toString();
        projected['isDone'] = matchingAssign['isDone'] == true;
      } else if (lastCalledKey != null && lastCalledKey != targetKey) {
        // Called on another date, not on targetKey
        final isAssignedOnTarget =
            (projected['assignedToUid'] != null &&
                projected['assignedToUid'].toString().trim().isNotEmpty) ||
            (projected['assignedToName'] != null &&
                projected['assignedToName'].toString().trim().isNotEmpty &&
                projected['assignedToName'] != '—');
        projected['status'] = isAssignedOnTarget ? 'Assigned' : 'New';
        projected['isDone'] = false;
      }

      if (leadId.isNotEmpty) {
        includedLeadIds.add(leadId);
      }
      result.add(projected);
    }

    // Include any assignments on targetKey whose lead doc was not in rawLeads
    for (final entry in assignmentsOnTarget.entries) {
      if (!includedLeadIds.contains(entry.key)) {
        final a = entry.value;
        final c = callLogsOnTargetByLeadId[entry.key];
        final isCalled = c != null || a['isDone'] == true;
        result.add({
          'id': entry.key,
          'name': a['leadName'] ?? 'Lead',
          'phone': a['leadPhone'] ?? '',
          'collegeBranch': a['collegeBranch'] ?? '—',
          'source': a['source'] ?? 'Direct Visit',
          'assignedToUid': a['executiveUid'],
          'assignedToName': a['executiveName'] ?? '—',
          'assignedTo': a['executiveName'] ?? '—',
          'assignedDateKey': targetKey,
          'status': c != null
              ? (c['outcome'] ?? 'Contacted')
              : (a['lastOutcome'] ??
                    (isCalled ? 'Contacted' : (a['leadStatus'] ?? 'Assigned'))),
          'isDone': isCalled,
        });
        includedLeadIds.add(entry.key);
      }
    }

    // Include any call logs on targetKey whose lead doc was not in rawLeads
    for (final entry in callLogsOnTargetByLeadId.entries) {
      if (!includedLeadIds.contains(entry.key)) {
        final c = entry.value;
        result.add({
          'id': entry.key,
          'name': c['leadName'] ?? 'Lead',
          'phone': '',
          'collegeBranch': c['collegeInfo'] ?? '—',
          'source': c['campaign'] ?? 'Direct Visit',
          'assignedToUid': c['executiveUid'],
          'assignedToName': c['executiveName'] ?? '—',
          'assignedTo': c['executiveName'] ?? '—',
          'assignedDateKey': targetKey,
          'status': c['outcome'] ?? 'Contacted',
          'isDone': true,
        });
        includedLeadIds.add(entry.key);
      }
    }

    return result;
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    SnackBarAlert.showToast(context: context, message: msg, isWarning: error);
  }

  void _logout() {
    final cubit = context.read<DashboardCubit>();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 22,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                const Text(
                  'Sign out of Dashboard?',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Gap(6),
                const Text(
                  'Are you sure you want to end your current dashboard administrative session?',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const Gap(24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            textAlign: TextAlign.center,
                            style: AppTypography.figmaButton(
                              color: const Color(0xFF475467),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await cubit.signOut();
                          },
                          child: Text(
                            'Sign out',
                            textAlign: TextAlign.center,
                            style: AppTypography.figmaButton(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return BlocConsumer<DashboardCubit, DashboardState>(
      listener: (context, state) {
        if (state is DashboardActionSuccess) {
          _toast(state.message);
        } else if (state is DashboardActionFailure) {
          _toast(state.message, error: true);
        } else if (state is DashboardSignedOut) {
          context.router.replaceAll([const LoginRoute()]);
        }
      },
      builder: (context, state) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: cubit.watchCurrentUserDoc(),
          builder: (context, snap) {
            final me = snap.data?.data() ?? {};
            return LayoutBuilder(
              builder: (context, c) {
                final showSidebar = c.maxWidth >= 768;
                final sidebarWidth = c.maxWidth >= 1200
                    ? 240.0
                    : (c.maxWidth >= 960 ? 216.0 : 185.0);
                final pad = context.devicePadding;
                final horizontalPad = c.maxWidth >= 1280
                    ? 32.0
                    : (c.maxWidth >= 960
                          ? 20.0
                          : (c.maxWidth >= 768 ? 16.0 : pad.clamp(16.0, 24.0)));
                final verticalPad = c.maxWidth >= 1280
                    ? 32.0
                    : (c.maxWidth >= 960
                          ? 24.0
                          : (c.maxWidth >= 768 ? 20.0 : pad.clamp(16.0, 24.0)));

                return Scaffold(
                  key: _scaffoldKey,
                  backgroundColor: _bg,
                  drawer: showSidebar
                      ? null
                      : Drawer(
                          width: 240,
                          backgroundColor: Colors.white,
                          child: SafeArea(
                            child: _sidebar(
                              me,
                              state.selectedNavIndex,
                              inDrawer: true,
                            ),
                          ),
                        ),
                  body: SafeArea(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showSidebar)
                          _sidebar(
                            me,
                            state.selectedNavIndex,
                            sidebarWidth: sidebarWidth,
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                              vertical: verticalPad,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!showSidebar &&
                                    state.selectedNavIndex != 0) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      onTap: () => _scaffoldKey.currentState
                                          ?.openDrawer(),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(color: _border),
                                        ),
                                        child: const Icon(
                                          Icons.menu_rounded,
                                          color: _text,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Gap(14),
                                ],
                                if (state.selectedNavIndex == 0) ...[
                                  StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: cubit.watchAllUsers(),
                                    builder: (context, usersSnap) {
                                      return StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >(
                                        stream: cubit.watchAllLeads(),
                                        builder: (context, leadsSnap) {
                                          return StreamBuilder<
                                            QuerySnapshot<Map<String, dynamic>>
                                          >(
                                            stream: FirestoreStreamCache
                                                .instance
                                                .watchCollection('assignments'),
                                            builder: (context, assignSnap) {
                                              return StreamBuilder<
                                                QuerySnapshot<
                                                  Map<String, dynamic>
                                                >
                                              >(
                                                stream: FirestoreStreamCache
                                                    .instance
                                                    .watchCollection(
                                                      'call_logs',
                                                    ),
                                                builder: (context, logsSnap) {
                                                  final allUsers = cubit
                                                      .mapAndSortUsers(
                                                        usersSnap.data,
                                                      );
                                                  final activeUsers = allUsers
                                                      .where((u) => u.isActive)
                                                      .toList();
                                                  final rawLeads =
                                                      leadsSnap.data?.docs
                                                          .map(
                                                            (d) =>
                                                                <
                                                                  String,
                                                                  dynamic
                                                                >{
                                                                  'id': d.id,
                                                                  ...d.data(),
                                                                },
                                                          )
                                                          .toList() ??
                                                      <Map<String, dynamic>>[];
                                                  final rawAssignments =
                                                      assignSnap.data?.docs
                                                          .map(
                                                            (d) =>
                                                                <
                                                                  String,
                                                                  dynamic
                                                                >{
                                                                  'id': d.id,
                                                                  ...d.data(),
                                                                },
                                                          )
                                                          .toList() ??
                                                      <Map<String, dynamic>>[];
                                                  final rawCallLogs =
                                                      logsSnap.data?.docs
                                                          .map(
                                                            (d) =>
                                                                <
                                                                  String,
                                                                  dynamic
                                                                >{
                                                                  'id': d.id,
                                                                  ...d.data(),
                                                                },
                                                          )
                                                          .toList() ??
                                                      <Map<String, dynamic>>[];
                                                  final dashboardLeads =
                                                      _filterLeadsForDashboardDate(
                                                        rawLeads: rawLeads,
                                                        rawAssignments:
                                                            rawAssignments,
                                                        rawCallLogs:
                                                            rawCallLogs,
                                                        targetDate:
                                                            _effectiveDashboardDate,
                                                      );

                                                  return LayoutBuilder(
                                                    builder: (context, contentBox) {
                                                      final contentWidth =
                                                          contentBox.maxWidth;
                                                      // Tablet (768px) to Laptop (1024px) to Laptop Large (1440px+)
                                                      // all share the same 1440px screen structure and 2-column alignment
                                                      final isWideContent =
                                                          contentWidth >= 520;
                                                      final sectionGap =
                                                          contentWidth >= 1000
                                                          ? 24.0
                                                          : (contentWidth >= 700
                                                                ? 18.0
                                                                : 14.0);

                                                      return Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          _header(
                                                            me: me,
                                                            contentWidth:
                                                                contentWidth,
                                                            showMenuButton:
                                                                !showSidebar,
                                                          ),
                                                          Gap(sectionGap),
                                                          if (_searchQuery
                                                              .trim()
                                                              .isNotEmpty) ...[
                                                            _buildLiveSearchResults(
                                                              query:
                                                                  _searchQuery
                                                                      .trim(),
                                                              leads: rawLeads,
                                                              users: allUsers,
                                                              onClear: () {
                                                                setState(() {
                                                                  _searchCtrl
                                                                      .clear();
                                                                  _searchQuery =
                                                                      '';
                                                                });
                                                                context
                                                                    .read<
                                                                      AdminLeadsCubit
                                                                    >()
                                                                    .setSearchQuery(
                                                                      '',
                                                                    );
                                                              },
                                                            ),
                                                            Gap(sectionGap),
                                                          ],
                                                          _stats(
                                                            dashboardLeads,
                                                            activeUsers,
                                                          ),
                                                          Gap(sectionGap),
                                                          if (isWideContent)
                                                            Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Expanded(
                                                                  flex: 58,
                                                                  child: Column(
                                                                    children: [
                                                                      _TeamToday(
                                                                        activeUsers:
                                                                            activeUsers,
                                                                        leads:
                                                                            dashboardLeads,
                                                                      ),
                                                                      Gap(
                                                                        sectionGap,
                                                                      ),
                                                                      _OverdueFollowUps(
                                                                        leads:
                                                                            dashboardLeads,
                                                                        referenceDate:
                                                                            _effectiveDashboardDate,
                                                                        onReassign: () => cubit.selectNav(
                                                                          1,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Gap(sectionGap),
                                                                Expanded(
                                                                  flex: 42,
                                                                  child: Column(
                                                                    children: [
                                                                      _Conversions(
                                                                        leads:
                                                                            dashboardLeads,
                                                                      ),
                                                                      Gap(
                                                                        sectionGap,
                                                                      ),
                                                                      _CollegeVisits(
                                                                        onPlanVisit: () => cubit.selectNav(
                                                                          4,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          else
                                                            Column(
                                                              children: [
                                                                _TeamToday(
                                                                  activeUsers:
                                                                      activeUsers,
                                                                  leads:
                                                                      dashboardLeads,
                                                                ),
                                                                const Gap(16),
                                                                _Conversions(
                                                                  leads:
                                                                      dashboardLeads,
                                                                ),
                                                                const Gap(16),
                                                                _OverdueFollowUps(
                                                                  leads:
                                                                      dashboardLeads,
                                                                  referenceDate:
                                                                      _effectiveDashboardDate,
                                                                  onReassign: () =>
                                                                      cubit.selectNav(
                                                                        1,
                                                                      ),
                                                                ),
                                                                const Gap(16),
                                                                _CollegeVisits(
                                                                  onPlanVisit: () =>
                                                                      cubit.selectNav(
                                                                        4,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
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
                                    },
                                  ),
                                ] else if (state.selectedNavIndex == 1)
                                  const LeadsAssignView()
                                else if (state.selectedNavIndex == 2)
                                  const CampaignsView()
                                else if (state.selectedNavIndex == 3)
                                  const FollowUpsView()
                                else if (state.selectedNavIndex == 4)
                                  const CollegeVisitsView()
                                else if (state.selectedNavIndex == 5)
                                  const ImportLeadsView()
                                else if (state.selectedNavIndex == 6)
                                  const TeamManagementView()
                                else if (state.selectedNavIndex == 7)
                                  UserManagementView(
                                    onOpenSettings: () => cubit.selectNav(8),
                                  )
                                else if (state.selectedNavIndex == 8)
                                  SettingsView(onLogout: _logout),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sidebar(
    Map<String, dynamic> me,
    int selectedIndex, {
    bool inDrawer = false,
    double sidebarWidth = 240,
  }) {
    final cubit = context.read<DashboardCubit>();
    final user = cubit.currentUser;
    final rawName = (me['name'] ?? user?.displayName ?? '').toString().trim();
    final name = rawName.isNotEmpty
        ? rawName
        : (user?.email?.split('@').first ?? 'Admin');

    if (me.isNotEmpty &&
        !_hasAutoHealedRole &&
        (me['role'] != 'admin' || me['email'] == null) &&
        cubit.currentUserId != null) {
      _hasAutoHealedRole = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(cubit.currentUserId)
            .set({
              'role': 'admin',
              'name': name,
              if (user?.email != null) 'email': user!.email,
              'isActive': true,
            }, SetOptions(merge: true));
      });
    }

    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((e) => e.isEmpty ? '' : e[0].toUpperCase())
        .join();
    final compactSidebar = !inDrawer && sidebarWidth < 210;

    return Container(
      width: inDrawer ? double.infinity : sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: inDrawer
            ? null
            : const Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compactSidebar ? 12 : 16,
              12,
              compactSidebar ? 12 : 16,
              8,
            ),
            child: SizedBox(
              height: compactSidebar ? 60 : 72,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  AppImages.logo,
                  height: compactSidebar ? 60 : 72,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (_, _, _) => const Text(
                    'ACADENO',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                // Dynamically scale vertical gaps between items based on viewport height:
                // Taller screens get generous 10-12px gaps so items breathe and don't leave a huge void below.
                final itemGap = h > 900
                    ? 12.0
                    : (h > 760 ? 8.0 : (h > 640 ? 5.0 : 2.0));
                final sectionGap = h > 900 ? 32.0 : (h > 760 ? 24.0 : 16.0);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _primaryNav.length; i++) ...[
                        if (i > 0) Gap(itemGap),
                        _buildNavItem(
                          item: _primaryNav[i],
                          index: i,
                          selectedIndex: selectedIndex,
                          inDrawer: inDrawer,
                          compact: compactSidebar,
                        ),
                      ],
                      Gap(sectionGap),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compactSidebar ? 14 : 20,
                          0,
                          16,
                          10,
                        ),
                        child: const Text(
                          'GENERAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      for (var i = 0; i < _generalNav.length; i++) ...[
                        if (i > 0) Gap(itemGap),
                        _buildNavItem(
                          item: _generalNav[i],
                          index: i + 5,
                          selectedIndex: selectedIndex,
                          inDrawer: inDrawer,
                          compact: compactSidebar,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compactSidebar ? 12 : 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: compactSidebar ? 30 : 34,
                  height: compactSidebar ? 30 : 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials.isNotEmpty ? initials[0] : 'U',
                    style: TextStyle(
                      color: const Color(0xFF475569),
                      fontSize: compactSidebar ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Gap(compactSidebar ? 8 : 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.center,
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: const StadiumBorder(),
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: compactSidebar ? 10 : 14,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Center(
                      child: Text(
                        'Logout',
                        textAlign: TextAlign.center,
                        style: AppTypography.figmaButton(
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required int index,
    required int selectedIndex,
    required bool inDrawer,
    bool compact = false,
  }) {
    final cubit = context.read<DashboardCubit>();
    return _SidebarNavItem(
      item: item,
      index: index,
      isSelected: selectedIndex == index,
      compact: compact,
      onTap: () {
        if (index == 0 && _selectedDashboardDate != null) {
          setState(() {
            _selectedDashboardDate = null;
          });
        }
        cubit.selectNav(index);
        if (inDrawer) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Widget _header({
    required Map<String, dynamic> me,
    required double contentWidth,
    required bool showMenuButton,
  }) {
    if (contentWidth < 520) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showMenuButton) ...[
                InkWell(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: _text,
                      size: 22,
                    ),
                  ),
                ),
                const Gap(10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D312E),
                        letterSpacing: -0.4102,
                      ),
                    ),
                    const Gap(2),
                    InkWell(
                      onTap: _pickDashboardDate,
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        _today,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF718096),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.3418,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),
          _buildFigmaSearchBar(),
          const Gap(12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                alignment: Alignment.center,
                backgroundColor: const Color(0xFFEF8144),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.read<DashboardCubit>().selectNav(1),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 16, color: Colors.white),
                    const Gap(8),
                    Text(
                      "Assign Today's Leads",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isCompactHeader = contentWidth < 700;
    final isMediumHeader = contentWidth >= 700 && contentWidth < 1000;
    final titleFontSize = isCompactHeader
        ? 22.0
        : (isMediumHeader ? 26.0 : 30.0);
    final dateFontSize = isCompactHeader ? 12.0 : 14.0;
    final searchMaxWidth = isCompactHeader
        ? 185.0
        : (isMediumHeader ? 260.0 : 360.0);
    final searchMinWidth = isCompactHeader
        ? 130.0
        : (isMediumHeader ? 180.0 : 220.0);
    final controlHeight = isCompactHeader
        ? 42.0
        : (isMediumHeader ? 46.0 : 52.0);
    final buttonHorizontalPad = isCompactHeader
        ? 14.0
        : (isMediumHeader ? 16.0 : 20.0);
    final buttonFontSize = isCompactHeader
        ? 12.5
        : (isMediumHeader ? 13.5 : 14.0);
    final headerGap = isCompactHeader ? 10.0 : (isMediumHeader ? 12.0 : 16.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showMenuButton) ...[
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: _text),
          ),
          const Gap(8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D312E),
                  letterSpacing: -0.4102,
                  height: 36 / 30,
                ),
              ),
              const Gap(4),
              InkWell(
                onTap: _pickDashboardDate,
                borderRadius: BorderRadius.circular(6),
                child: Text(
                  _today,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF718096),
                    fontSize: dateFontSize,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.3418,
                    height: 20 / 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Gap(headerGap),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: searchMaxWidth,
            minWidth: searchMinWidth,
          ),
          child: _buildFigmaSearchBar(height: controlHeight),
        ),
        Gap(headerGap),
        SizedBox(
          height: controlHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              alignment: Alignment.center,
              backgroundColor: const Color(0xFFEF8144),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: buttonHorizontalPad),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => context.read<DashboardCubit>().selectNav(1),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    size: isCompactHeader ? 14 : 16,
                    color: Colors.white,
                  ),
                  Gap(isCompactHeader ? 6 : 8),
                  Text(
                    "Assign Today's Leads",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaSearchBar({double? width, double height = 48}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8E5), width: 1),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _searchCtrl,
        textAlignVertical: TextAlignVertical.center,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
          context.read<AdminLeadsCubit>().setSearchQuery(val.trim());
        },
        style: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF111827),
          fontWeight: FontWeight.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.search_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 46,
            minHeight: height,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _searchQuery = '';
                    });
                    context.read<AdminLeadsCubit>().setSearchQuery('');
                  },
                )
              : null,
          suffixIconConstraints: BoxConstraints(
            minWidth: 42,
            minHeight: height,
          ),
          hintText: 'Search',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w400,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSearchResults({
    required String query,
    required List<Map<String, dynamic>> leads,
    required List<DashboardUserModel> users,
    required VoidCallback onClear,
  }) {
    final q = query.toLowerCase();

    // 1. Matched Leads
    final matchedLeads = leads.where((l) {
      final name = (l['name'] ?? l['studentName'] ?? l['candidateName'] ?? '')
          .toString()
          .toLowerCase();
      final phone = (l['phone'] ?? l['phoneNumber'] ?? '')
          .toString()
          .toLowerCase();
      final college = (l['college'] ?? l['collegeName'] ?? '')
          .toString()
          .toLowerCase();
      final course = (l['course'] ?? l['program'] ?? '')
          .toString()
          .toLowerCase();
      final assigned = (l['assignedName'] ?? l['assignedTo'] ?? '')
          .toString()
          .toLowerCase();
      final status = (l['status'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          phone.contains(q) ||
          college.contains(q) ||
          course.contains(q) ||
          assigned.contains(q) ||
          status.contains(q);
    }).toList();

    // 2. Matched Team Members
    final matchedUsers = users.where((u) {
      final name = u.name.toLowerCase();
      final email = u.email.toLowerCase();
      final role = u.role.toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q);
    }).toList();

    // 3. Matched College Visits
    final matchedVisits = <Map<String, dynamic>>[];

    final totalMatches =
        matchedLeads.length + matchedUsers.length + matchedVisits.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: _orangeAccent,
                  size: 20,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Search results for "$query"',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                        ),
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$totalMatches ${totalMatches == 1 ? 'match' : 'matches'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    const Text(
                      'Live lookup across Leads, Team Directory, and Campus Visits',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const Gap(16),
          if (totalMatches == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: Color(0xFFCBD5E1),
                    ),
                    const Gap(10),
                    Text(
                      'No results found matching "$query"',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Gap(4),
                    const Text(
                      'Try searching by student name, mobile number, college, or team member name.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // LEADS SECTION
            if (matchedLeads.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LEADS (${matchedLeads.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      context.read<AdminLeadsCubit>().setSearchQuery(query);
                      context.read<DashboardCubit>().selectNav(1);
                    },
                    child: const Text(
                      'View all in Leads & Assign →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              ...matchedLeads.take(5).map((l) {
                final name = (l['name'] ?? l['studentName'] ?? 'Lead')
                    .toString();
                final phone = (l['phone'] ?? l['phoneNumber'] ?? '').toString();
                final college = (l['college'] ?? l['collegeName'] ?? 'Campus')
                    .toString();
                final course = (l['course'] ?? l['program'] ?? '').toString();
                final assigned =
                    (l['assignedName'] ?? l['assignedTo'] ?? 'Unassigned')
                        .toString();
                final status = (l['status'] ?? 'New').toString();

                Color badgeBg = const Color(0xFFEEF2FF);
                Color badgeFg = _primary;
                if (status.toLowerCase().contains('convert')) {
                  badgeBg = const Color(0xFFDCFCE7);
                  badgeFg = const Color(0xFF15803D);
                } else if (status.toLowerCase().contains('interest')) {
                  badgeBg = const Color(0xFFEFF6FF);
                  badgeFg = const Color(0xFF2563EB);
                } else if (status.toLowerCase().contains('overdue')) {
                  badgeBg = const Color(0xFFFEE2E2);
                  badgeFg = const Color(0xFFB91C1C);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'L',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _text,
                                    ),
                                  ),
                                ),
                                const Gap(8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: badgeFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(2),
                            Text(
                              '$college${course.isNotEmpty ? ' · $course' : ''} · Assigned: $assigned',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(10),
                      if (phone.isNotEmpty)
                        IconButton(
                          tooltip: 'Call $name',
                          icon: const Icon(
                            Icons.phone_outlined,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                          onPressed: () => UrlDialerHelper.openDialer(phone),
                        ),
                      OutlinedButton(
                        onPressed: () {
                          context.read<AdminLeadsCubit>().setSearchQuery(name);
                          context.read<DashboardCubit>().selectNav(1);
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // TEAM SECTION
            if (matchedUsers.isNotEmpty) ...[
              const Gap(12),
              Text(
                'TEAM MEMBERS (${matchedUsers.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const Gap(8),
              ...matchedUsers.take(3).map((u) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFDBEAFE),
                        child: Text(
                          u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                            Text(
                              '${u.email} · ${u.role}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            context.read<DashboardCubit>().selectNav(7),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'View User',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // COLLEGE VISITS SECTION
            if (matchedVisits.isNotEmpty) ...[
              const Gap(12),
              Text(
                'CAMPUS VISITS (${matchedVisits.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const Gap(8),
              ...matchedVisits.map((v) {
                final name = (v['collegeName'] ?? 'College').toString();
                final purpose = (v['purpose'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 20,
                        color: _primary,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                            Text(
                              purpose,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            LinkLauncher.launchCollegeMapsDirections(name),
                        icon: const Icon(Icons.directions_outlined, size: 14),
                        label: const Text('Directions'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stats(
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
      final isDone = (l['isDone'] as bool?) ?? false;
      return status != 'new' && status != 'unassigned' || isDone;
    }).length;
    final contactedPct = totalAssigned > 0
        ? (contactedCount / totalAssigned * 100).round()
        : (totalLeads > 0 ? (contactedCount / totalLeads * 100).round() : 0);

    final evaluatedFollowUps = leads
        .where((l) {
          final isDone = (l['isDone'] as bool?) ?? false;
          return !isDone;
        })
        .map((l) {
          final eval = FollowUpTimeHelper.evaluate(
            rawFollowUpTime: l['followUpTime'],
            assignedDateKey: l['assignedDateKey'],
            assignedDateLabel: l['assignedDateLabel'],
            assignedAt: l['assignedAt'],
            updatedAt: l['updatedAt'],
            createdAt: l['createdAt'],
            status: (l['status'] ?? '').toString(),
            currentTime: _effectiveDashboardDate,
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
      _StatCard(
        label: 'Total Leads',
        value: '$totalLeads',
        sub: '$totalAssigned assigned to team',
        color: const Color(0xFF4338CA),
        valueColor: Colors.white,
        svgAsset: 'assets/svgs/stat_total_leads.svg',
        icon: Icons.groups_rounded,
        isSolidHero: true,
      ),
      _StatCard(
        label: 'Calls / Contacted',
        value: '$contactedCount/$totalAssigned',
        sub: '$contactedPct% of assigned',
        color: const Color(0xFF3F3FB4),
        valueColor: const Color(0xFF3F3FB4),
        svgAsset: 'assets/svgs/stat_phone.svg',
        icon: Icons.phone_rounded,
      ),
      _StatCard(
        label: 'Follow-ups Due',
        value: '$followUpsCount',
        sub: 'Across ${activeUsers.length} active members',
        color: const Color(0xFFE96849),
        valueColor: const Color(0xFFE96849),
        svgAsset: 'assets/svgs/stat_calendar_check.svg',
        icon: Icons.calendar_today_rounded,
      ),
      _StatCard(
        label: 'Overdue / Pending',
        value: '$overdueCount',
        sub: 'Requires team attention',
        color: const Color(0xFF4C0CBF),
        valueColor: const Color(0xFF4C0CBF),
        svgAsset: 'assets/svgs/stat_hourglass.svg',
        icon: Icons.hourglass_full_rounded,
      ),
      _StatCard(
        label: 'Converted Leads',
        value: '$convertedCount',
        sub: '$conversionPct% conversion rate',
        color: const Color(0xFF22C55E),
        valueColor: const Color(0xFF22C55E),
        svgAsset: 'assets/svgs/stat_star.svg',
        icon: Icons.star_rounded,
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
}

class _StatCard extends StatefulWidget {
  final String label, value, sub;
  final Color color;
  final Color? valueColor;
  final IconData? icon;
  final String? svgAsset;
  final bool isSolidHero;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.valueColor,
    this.icon,
    this.svgAsset,
    this.isSolidHero = false,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
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
        final iconSize = isCompact ? 12.0 : (isMedium ? 14.0 : 16.0);

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
                              child: widget.svgAsset != null
                                  ? SvgPicture.asset(
                                      widget.svgAsset!,
                                      width: svgSize,
                                      height: svgSize,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    )
                                  : (widget.icon != null
                                        ? Icon(
                                            widget.icon,
                                            color: Colors.white,
                                            size: iconSize,
                                          )
                                        : const SizedBox.shrink()),
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
                                widget.value,
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
                      child: widget.svgAsset != null
                          ? SvgPicture.asset(
                              widget.svgAsset!,
                              width: svgSize,
                              height: svgSize,
                            )
                          : (widget.icon != null
                                ? Icon(
                                    widget.icon,
                                    color: widget.color,
                                    size: iconSize,
                                  )
                                : const SizedBox.shrink()),
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
                        widget.value,
                        style: GoogleFonts.inter(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w700,
                          color: widget.valueColor ?? widget.color,
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

// ============================================================================
// Main Cards
// ============================================================================

class _TeamToday extends StatelessWidget {
  final List<DashboardUserModel> activeUsers;
  final List<Map<String, dynamic>> leads;

  const _TeamToday({required this.activeUsers, required this.leads});

  @override
  Widget build(BuildContext context) {
    final rows = activeUsers.map((user) {
      final userLeads = leads.where((l) {
        final assignedUid = l['assignedToUid'];
        final assignedName = l['assignedToName'] ?? l['assignedTo'];
        final ownerUid = l['ownerUid'];
        return assignedUid == user.uid ||
            ownerUid == user.uid ||
            (assignedName != null &&
                assignedName.toString().trim().toLowerCase() ==
                    user.name.trim().toLowerCase());
      }).toList();

      final assigned = userLeads.length;
      final called = userLeads.where((l) {
        final status = (l['status'] ?? '').toString().toLowerCase();
        final isDone = (l['isDone'] as bool?) ?? false;
        return status != 'new' && status != 'unassigned' || isDone;
      }).length;
      final interested = userLeads.where((l) {
        return (l['status'] ?? '').toString().toLowerCase() == 'interested';
      }).length;
      final converted = userLeads.where((l) {
        return (l['status'] ?? '').toString().toLowerCase().contains('convert');
      }).length;
      final overdue = userLeads.where((l) {
        final isDone = (l['isDone'] as bool?) ?? false;
        final status = (l['status'] ?? '').toString().toLowerCase();
        return !isDone &&
            (status == 'new' || status == 'claimed' || status == 'follow-up');
      }).length;

      return (
        name: user.name,
        role: user.roleLabel,
        called: called,
        assigned: assigned,
        interested: interested,
        converted: converted,
        overdue: overdue,
      );
    }).toList();

    final screenW = MediaQuery.of(context).size.width;
    final cardPad = screenW < 960
        ? const EdgeInsets.all(16)
        : (screenW < 1280
              ? const EdgeInsets.all(20)
              : const EdgeInsets.all(24));
    final titleSize = screenW < 960 ? 15.5 : (screenW < 1280 ? 16.5 : 18.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: cardPad,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF9FAFB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Team Today',
                  style: GoogleFonts.inter(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    letterSpacing: 0.0527,
                    height: 28 / 18,
                  ),
                ),
                const Gap(12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const Gap(6),
                      Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF15803D),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3027,
                          height: 15 / 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: cardPad,
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No active team members registered yet.',
                        style: GoogleFonts.inter(color: _muted, fontSize: 13),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Gap(32),
                        Builder(
                          builder: (_) {
                            final r = rows[i];
                            final progress = r.assigned > 0
                                ? (r.called / r.assigned).clamp(0.0, 1.0)
                                : 0.0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: const Color(0xFF111827),
                                          letterSpacing: 0.0156,
                                        ),
                                      ),
                                    ),
                                    const Gap(8),
                                    Text(
                                      '${r.called} / ${r.assigned} leads',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF3F3FB4),
                                        letterSpacing: -0.0957,
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(9999),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    color: const Color(0xFF3F3FB4),
                                    backgroundColor: const Color(0xFFF3F4F6),
                                  ),
                                ),
                                const Gap(8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFDBEAFE),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'INTERESTED: ${r.interested}',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF2563EB),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          height: 16.5 / 11,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFDCFCE7),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'CONVERTED: ${r.converted}',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF16A34A),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          height: 16.5 / 11,
                                        ),
                                      ),
                                    ),
                                    if (r.overdue > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFEDD5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'OVERDUE: ${r.overdue}',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFEA580C),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            height: 16.5 / 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Conversions extends StatelessWidget {
  final List<Map<String, dynamic>> leads;

  const _Conversions({required this.leads});

  static String _normalizeSource(dynamic raw) {
    if (raw == null) return 'Direct Visit';
    final trimmed = raw.toString().trim();
    if (trimmed.isEmpty) return 'Direct Visit';
    final lower = trimmed.toLowerCase();
    if (lower == 'direct visit' ||
        lower == 'direct_visit' ||
        lower == 'direct' ||
        lower == 'walk-in' ||
        lower == 'direct walk-in') {
      return 'Direct Visit';
    }
    // Clean capitalized title
    return trimmed
        .split(RegExp(r'[\s_]+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static bool _isConverted(dynamic statusVal) {
    final s = (statusVal ?? '').toString().toLowerCase();
    return s.contains('convert') ||
        s.contains('enrolled') ||
        s.contains('admission');
  }

  @override
  Widget build(BuildContext context) {
    final sourcesMap = <String, (int converted, int total)>{};
    for (final l in leads) {
      final rawSource =
          l['source'] ??
          l['sourceEvent'] ??
          l['campaign'] ??
          l['campaignTag'] ??
          l['lead_source'] ??
          'Direct Visit';
      final src = _normalizeSource(rawSource);
      final statusVal = l['status'] ?? l['leadStatus'] ?? l['outcome'];
      final isConverted = _isConverted(statusVal);
      final curr = sourcesMap[src] ?? (0, 0);
      sourcesMap[src] = (curr.$1 + (isConverted ? 1 : 0), curr.$2 + 1);
    }

    final List<(String, int, int)> displaySources = sourcesMap.isNotEmpty
        ? (sourcesMap.entries
              .map((e) => (e.key, e.value.$1, e.value.$2))
              .toList()
            ..sort((a, b) {
              final convCmp = b.$2.compareTo(a.$2);
              if (convCmp != 0) return convCmp;
              return b.$3.compareTo(a.$3);
            }))
        : const [];

    final screenW = MediaQuery.of(context).size.width;
    final cardPadding = screenW < 960
        ? const EdgeInsets.all(16)
        : (screenW < 1280
              ? const EdgeInsets.all(20)
              : const EdgeInsets.all(24));
    final titleSize = screenW < 960 ? 15.0 : (screenW < 1280 ? 16.5 : 18.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: cardPadding,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF9FAFB), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Conversions by source',
                      maxLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        letterSpacing: 0.0527,
                        height: 28 / 18,
                      ),
                    ),
                  ),
                ),
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${leads.length} leads',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.0117,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: cardPadding,
            child: displaySources.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No source conversion data recorded yet.',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (
                        var i = 0;
                        i < displaySources.take(6).length;
                        i++
                      ) ...[
                        if (i > 0) const Gap(20),
                        Builder(
                          builder: (_) {
                            final r = displaySources[i];
                            return Row(
                              children: [
                                Expanded(
                                  flex: 32,
                                  child: Text(
                                    r.$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                      height: 16 / 12,
                                    ),
                                  ),
                                ),
                                const Gap(10),
                                Expanded(
                                  flex: 40,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9999),
                                    child: LinearProgressIndicator(
                                      value: r.$3 > 0
                                          ? (r.$2 / r.$3).clamp(0.0, 1.0)
                                          : 0.0,
                                      minHeight: 10,
                                      color: r.$2 > 0
                                          ? const Color(0xFFFB923C)
                                          : const Color(0xFF3F3FB4),
                                      backgroundColor: const Color(0xFFF9FAFB),
                                    ),
                                  ),
                                ),
                                const Gap(10),
                                SizedBox(
                                  width: 52,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: RichText(
                                      textAlign: TextAlign.right,
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${r.$2}',
                                            style: GoogleFonts.inter(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF111827),
                                              height: 16 / 20,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' ',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                            ),
                                          ),
                                          TextSpan(
                                            text: '/ ${r.$3}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF9FA0A1),
                                              height: 16 / 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OverdueFollowUps extends StatelessWidget {
  final List<Map<String, dynamic>> leads;
  final DateTime? referenceDate;
  final VoidCallback onReassign;

  const _OverdueFollowUps({
    required this.leads,
    this.referenceDate,
    required this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = leads.where((l) {
      final isDone = (l['isDone'] as bool?) ?? false;
      if (isDone) return false;
      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: l['followUpTime'],
        assignedDateKey: l['assignedDateKey'],
        assignedDateLabel: l['assignedDateLabel'],
        assignedAt: l['assignedAt'],
        updatedAt: l['updatedAt'],
        createdAt: l['createdAt'],
        status: (l['status'] ?? '').toString(),
        currentTime: referenceDate,
      );
      return eval.isOverdue;
    }).toList();

    final screenW = MediaQuery.of(context).size.width;
    final cardPad = screenW < 960
        ? const EdgeInsets.all(16)
        : (screenW < 1280
              ? const EdgeInsets.all(20)
              : const EdgeInsets.all(24));
    final titleSize = screenW < 960 ? 15.5 : (screenW < 1280 ? 16.5 : 18.0);

    return Container(
      padding: cardPad,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Overdue Follow ups',
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.2813,
                    ),
                  ),
                ),
              ),
              const Gap(8),
              InkWell(
                onTap: onReassign,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x333F3FB4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Manage in Leads',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF5C59B6),
                      fontSize: screenW < 960 ? 12.5 : 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.041,
                      height: 20 / 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(20),
          if (overdue.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF15803D),
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      'All follow-ups are up to date! No overdue calls.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF15803D),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < overdue.take(4).length; i++) ...[
              if (i > 0) const Gap(20),
              Builder(
                builder: (_) {
                  final l = overdue[i];
                  final name = (l['name'] ?? 'Student Inquiry').toString();
                  final assigned =
                      l['assignedToName'] ?? l['assignedTo'] ?? '--';
                  final college = l['college'] ?? l['collegeBranch'] ?? '';
                  final course = (l['course'] ?? l['branch'] ?? '').toString();

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: const Color(0xFF1A1A1A),
                                letterSpacing: 0.2197,
                                height: 22.5 / 15,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              course.isNotEmpty
                                  ? 'Assigned: $assigned · $college\n$course'
                                  : 'Assigned: $assigned · $college',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 19.5 / 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      InkWell(
                        onTap: onReassign,
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: const Color(0xFF5C59B6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Re Assign',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF5C59B6),
                              letterSpacing: 0.1914,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

class _CollegeVisits extends StatelessWidget {
  final VoidCallback onPlanVisit;

  const _CollegeVisits({required this.onPlanVisit});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardPad = screenW < 960
        ? const EdgeInsets.all(16)
        : (screenW < 1280
              ? const EdgeInsets.all(20)
              : const EdgeInsets.all(24));
    final titleSize = screenW < 960 ? 15.0 : (screenW < 1280 ? 16.5 : 18.0);

    return Container(
      padding: cardPad,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'College visits this week',
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.2813,
                    ),
                  ),
                ),
              ),
              const Gap(8),
              InkWell(
                onTap: onPlanVisit,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x333F3FB4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Plan Visit',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3F3FB4),
                      letterSpacing: 0.0752,
                      height: 16.5 / 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreStreamCache.instance.watchCollection(
              'college_visits',
            ),
            builder: (context, snapshot) {
              final List<Map<String, dynamic>> displayVisits =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty
                  ? snapshot.data!.docs.take(4).map((d) => d.data()).toList()
                  : <Map<String, dynamic>>[];

              if (displayVisits.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_city_outlined,
                          size: 32,
                          color: Color(0xFFCBD5E1),
                        ),
                        const Gap(8),
                        Text(
                          'No college visits scheduled',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const Gap(4),
                        Text(
                          'Tap "Plan Visit" above to schedule a college drive.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < displayVisits.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        color: Color(0xFFF3F4F6),
                        height: 24,
                        thickness: 1,
                      ),
                    Builder(
                      builder: (_) {
                        final v = displayVisits[i];
                        final name = (v['collegeName'] ?? 'College').toString();
                        final desc =
                            (v['purpose'] ?? v['subtitle'] ?? 'Campus visit')
                                .toString();
                        final status =
                            (v['status'] ?? v['statusLabel'] ?? 'Planned')
                                .toString();

                        Color badgeBg;
                        Color badgeFg;
                        if (status == 'Completed') {
                          badgeBg = const Color(0xFFE8F5E9);
                          badgeFg = const Color(0xFF2E7D32);
                        } else if (status == 'Cancelled') {
                          badgeBg = const Color(0xFFFEE2E2);
                          badgeFg = const Color(0xFFB91C1C);
                        } else {
                          badgeBg = const Color(0xFFEEF0FF);
                          badgeFg = _primary;
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () =>
                                    LinkLauncher.launchCollegeMapsDirections(
                                      name,
                                      locationHint: desc,
                                    ),
                                borderRadius: BorderRadius.circular(6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: const Color(0xFF1A1A1A),
                                              letterSpacing: -0.1465,
                                              height: 22.5 / 15,
                                            ),
                                          ),
                                        ),
                                        const Gap(4),
                                        const Icon(
                                          Icons.directions_outlined,
                                          size: 13,
                                          color: _primary,
                                        ),
                                      ],
                                    ),
                                    const Gap(2),
                                    Text(
                                      desc,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF6B7280),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.0127,
                                        height: 19.5 / 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Gap(12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: GoogleFonts.inter(
                                  color: badgeFg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.0752,
                                  height: 16.5 / 11,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

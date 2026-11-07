import 'package:flutter_svg/flutter_svg.dart';
import 'package:acadeno_crm/shared/theme/app_svgs.dart';
import 'package:flutter/cupertino.dart';
import 'package:acadeno_crm/core/services/app_phone_call_service.dart';
import 'package:acadeno_crm/core/services/offline_queue_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_cubit.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/ui/home/application/home_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/leads_state.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';

import 'widgets/lead_call_sheets.dart';

class LeadsTabView extends StatefulWidget {
  final VoidCallback onLogout;

  const LeadsTabView({super.key, required this.onLogout});

  @override
  State<LeadsTabView> createState() => _LeadsTabViewState();
}

class _LeadsTabViewState extends State<LeadsTabView> {
  double _scrollProgress = 0.0;

  void _confirmLogout(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        message: const Text(
          'Are you sure you want to end your current session?',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(AppSvgs.logout, width: 18, height: 18),
                const SizedBox(width: 8),
                const Text('Log Out'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      final offset = notification.metrics.pixels.clamp(0.0, 36.0);
      final nextProgress = (offset / 36.0).clamp(0.0, 1.0);
      if ((nextProgress - _scrollProgress).abs() > 0.02) {
        setState(() {
          _scrollProgress = nextProgress;
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeadsCubit, LeadsState>(
      builder: (context, state) {
        final cubit = context.read<LeadsCubit>();
        final homeCubit = context.read<HomeCubit>();
        final homeState = context.watch<HomeCubit>().state;
        final followUpsCubit = context.read<FollowUpsCubit>();
        final followUpsState = context.watch<FollowUpsCubit>().state;
        final pad = context.devicePadding;
        final displayedLeads = state.showingPendingCalls
            ? state.pendingLeads
            : state.doneLeads;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top White Header + Metrics + Progress Bar (Pinned at top)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFEAECF0)),
                ),
                boxShadow: _scrollProgress > 0.01
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.06 * _scrollProgress),
                          blurRadius: 10 * _scrollProgress,
                          offset: Offset(0, 3 * _scrollProgress),
                        ),
                      ]
                    : null,
              ),
              padding: EdgeInsets.fromLTRB(pad, 14, pad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Acadeno "A" Brand Mark (cropped A emblem from acadeno_logo.png)
                      Image.asset(
                        AppImages.acadenoALogo,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${homeState.greeting}, ${homeState.user.firstName.isNotEmpty ? homeState.user.firstName : "Test"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              homeState.todayLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Offline Sync Status Pill (RL-5, RL-6)
                      StreamBuilder<int>(
                        stream: OfflineQueueService.instance.pendingCountStream,
                        initialData: OfflineQueueService.instance.pendingCount,
                        builder: (context, snapshot) {
                          final pending = snapshot.data ?? 0;
                          if (pending == 0) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.cloud_upload,
                                  size: 14,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$pending syncing',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Logout button (Figma spec: 40x40, radius 12, #F9FAFB, border #F3F4F6, logout.svg)
                      InkWell(
                        onTap: () => _confirmLogout(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF3F4F6),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            AppSvgs.logout,
                            width: 16,
                            height: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Three Metric Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _MetricBox(
                          value:
                              '${state.callsDoneCount}/${state.totalCallsAssigned}',
                          label: 'Calls done',
                          bgColor: const Color(0xFFEEF2FF),
                          valueColor: const Color(0xFF4338CA),
                          labelColor: const Color(0xFF6366F1),
                          onTap: () => cubit.togglePendingOrDoneCalls(
                            !state.showingPendingCalls ? true : false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricBox(
                          value: '${followUpsState.todayFollowUps.length}',
                          label: 'Follow-ups',
                          bgColor: const Color(0xFFF0F9FF),
                          valueColor: const Color(0xFF0284C7),
                          labelColor: const Color(0xFF0EA5E9),
                          onTap: () {
                            followUpsCubit.selectFollowUpBucket(
                              FollowUpBucket.today,
                            );
                            homeCubit.selectBottomNav(1);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricBox(
                          value: '${followUpsState.overdueFollowUps.length}',
                          label: 'Overdue',
                          bgColor: const Color(0xFFFFF7ED),
                          valueColor: const Color(0xFFC2410C),
                          labelColor: const Color(0xFFEA580C),
                          onTap: () {
                            followUpsCubit.selectFollowUpBucket(
                              FollowUpBucket.overdue,
                            );
                            homeCubit.selectBottomNav(1);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: state.totalCallsAssigned == 0
                          ? 0
                          : state.callsDoneCount / state.totalCallsAssigned,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${state.progressPercent}% of today's calls done · ${state.callsLeftCount} left",
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Lower Gray Body (#F5F6FA) — Scrolls from DUE NOW downward with blur edge
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: const Color(0xFF4338CA),
                    backgroundColor: Colors.white,
                    displacement: 24,
                    onRefresh: () async {
                      cubit.refresh();
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleScroll,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(pad, 18, pad, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 4. DUE NOW Section
                            const Text(
                              'DUE NOW',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (state.dueNowLead != null)
                              Builder(
                                builder: (_) {
                                  final due = state.dueNowLead!;
                                  return InkWell(
                                    onTap: () =>
                                        LeadCallSheets.showLeadDetailSheet(
                                          context,
                                          lead: due,
                                        ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0x4DF97316),
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      CupertinoIcons.clock,
                                                      size: 15,
                                                      color: Color(0xFFEA580C),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${due.statusTag} · Due Today',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFFEA580C,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  due.name,
                                                  style: const TextStyle(
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F172A),
                                                    letterSpacing: -0.3,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${due.collegeInfo} · ${due.campaignTag}',
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    color: Color(0xFF64748B),
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          InkWell(
                                            onTap: () => AppPhoneCallService
                                                .instance
                                                .dialLead(context, due),
                                            borderRadius: BorderRadius.circular(
                                              26,
                                            ),
                                            child: Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF8144),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFEF8144,
                                                    ).withValues(alpha: 0.38),
                                                    blurRadius: 18,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                CupertinoIcons.phone_fill,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFEAECF0),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.checkmark_circle,
                                      color: Color(0xFF15803D),
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'No urgent pending calls right now',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475467),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 18),

                            // Quick Actions: Add Walk-in Lead & My Record (Responsive flex boxes)
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        LeadCallSheets.showPhoneLookupAndWalkInSheet(
                                          context,
                                        ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      height: 38,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFF3F4F6),
                                          width: 1,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0D000000),
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SvgPicture.asset(
                                              AppSvgs.addWalkInLead,
                                              width: 14,
                                              height: 14,
                                            ),
                                            const SizedBox(width: 7),
                                            const Text(
                                              'Add Walk-in Lead',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        LeadCallSheets.showMyRecordSheet(
                                          context,
                                        ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      height: 38,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFF3F4F6),
                                          width: 1,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0D000000),
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SvgPicture.asset(
                                              AppSvgs.myRecord,
                                              width: 14,
                                              height: 14,
                                            ),
                                            const SizedBox(width: 7),
                                            const Text(
                                              'My Record',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            // 5. TODAY'S CALLS Header with Pending / Completed switcher
                            Row(
                              children: [
                                const Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "TODAY'S CALLS",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 3,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFE2E8F0,
                                          ).withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(3),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _CallTabPill(
                                              label:
                                                  'Pending (${state.pendingLeads.length})',
                                              isSelected:
                                                  state.showingPendingCalls,
                                              onTap: () => cubit
                                                  .togglePendingOrDoneCalls(
                                                    true,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            _CallTabPill(
                                              label:
                                                  'Completed (${state.doneLeads.length})',
                                              isSelected:
                                                  !state.showingPendingCalls,
                                              onTap: () => cubit
                                                  .togglePendingOrDoneCalls(
                                                    false,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 6. Call Cards List (Loading, Error/Permission, Empty, or Assigned Leads)
                            if (state.isLoading)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 36,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFEAECF0),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color(0xFF4338CA),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Loading your assigned calls for today...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (state.errorMessage != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFEE4E2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      state.isPermissionDenied
                                          ? CupertinoIcons.lock
                                          : Icons.error_outline_rounded,
                                      color: const Color(0xFFB42318),
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      state.isPermissionDenied
                                          ? 'Access Restricted'
                                          : 'Could not load assigned leads',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      state.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: cubit.refresh,
                                      icon: const Icon(
                                        CupertinoIcons.refresh,
                                        size: 16,
                                      ),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            else if (displayedLeads.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 32,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFF3F4F6),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Top Icon Container
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: SvgPicture.asset(
                                        AppSvgs.clipboardCheck,
                                        width: 20,
                                        height: 25,
                                        colorFilter: const ColorFilter.mode(
                                          Color(0xFF9CA3AF),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Title
                                    Text(
                                      state.showingPendingCalls
                                          ? 'No pending leads assigned to you for today'
                                          : 'No completed calls recorded yet today',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Subtitle
                                    const Text(
                                      'New leads assigned by your Admin will\nappear here automatically.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF94A3B8),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Action Buttons (Responsive flex row)
                                    Row(
                                      children: [
                                        if (!state.showingPendingCalls) ...[
                                          // Back to Pending Calls Button (Figma: flex 8, height 44, radius 12, #D35501)
                                          Expanded(
                                            flex: 8,
                                            child: SizedBox(
                                              height: 44,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFFD35501,
                                                      ).withValues(alpha: 0.32),
                                                      blurRadius: 16,
                                                      offset: const Offset(
                                                        0,
                                                        6,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton(
                                                  onPressed: () => cubit
                                                      .togglePendingOrDoneCalls(
                                                        true,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFD35501),
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        SvgPicture.asset(
                                                          AppSvgs.arrowLeft,
                                                          width: 15,
                                                          height: 15,
                                                          colorFilter:
                                                              const ColorFilter.mode(
                                                                Colors.white,
                                                                BlendMode.srcIn,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        const Text(
                                                          'Back to Pending\nCalls',
                                                          textAlign:
                                                              TextAlign.left,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                            height: 1.15,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],

                                        // Refresh Button (Figma: flex 5, height 44, radius 12, border 1px #F3F4F6)
                                        Expanded(
                                          flex: state.showingPendingCalls
                                              ? 1
                                              : 5,
                                          child: SizedBox(
                                            height: 44,
                                            child: OutlinedButton(
                                              onPressed: cubit.refresh,
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: const Color(
                                                  0xFF334155,
                                                ),
                                                side: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                  width: 1,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    SvgPicture.asset(
                                                      AppSvgs.refresh,
                                                      width: 15,
                                                      height: 15,
                                                      colorFilter:
                                                          const ColorFilter.mode(
                                                            Color(0xFF475467),
                                                            BlendMode.srcIn,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 7),
                                                    const Text(
                                                      'Refresh',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFF334155,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayedLeads.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = displayedLeads[index];
                                  return _TodayLeadCard(
                                    item: item,
                                    onTapCard: () =>
                                        LeadCallSheets.showLeadDetailSheet(
                                          context,
                                          lead: item,
                                        ),
                                    onTapCall: () => AppPhoneCallService
                                        .instance
                                        .dialLead(context, item),
                                  );
                                },
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Top Ambient Shade Overlay when scrolling (Smooth gradient shade without cutting)
                  if (_scrollProgress > 0.01)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 24,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: _scrollProgress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.0, 0.35, 0.70, 1.0],
                                colors: [
                                  Color(0x18000000),
                                  Color(0x0A000000),
                                  Color(0x03000000),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String value;
  final String label;
  final Color bgColor;
  final Color valueColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _MetricBox({
    required this.value,
    required this.label,
    required this.bgColor,
    required this.valueColor,
    this.labelColor = const Color(0xFF475467),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 85,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayLeadCard extends StatelessWidget {
  final ExecutiveLeadItem item;
  final VoidCallback onTapCard;
  final VoidCallback onTapCall;

  const _TodayLeadCard({
    required this.item,
    required this.onTapCard,
    required this.onTapCall,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapCard,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Initials Circle
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                item.initials,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Center Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.collegeInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.statusTag.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          item.campaignTag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.isLocked && item.lockedMessage != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.lock,
                          size: 13.5,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.lockedMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Right Phone Button (hidden when locked by another executive)
            if (!item.isLocked) ...[
              const SizedBox(width: 10),
              InkWell(
                onTap: onTapCall,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: const Icon(
                    CupertinoIcons.phone_fill,
                    color: Color(0xFF4F46E5),
                    size: 18,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallTabPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CallTabPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF0F172A)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

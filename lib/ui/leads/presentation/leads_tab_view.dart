import 'package:flutter/cupertino.dart';
import 'package:acadeno_crm/core/services/app_phone_call_service.dart';
import 'package:acadeno_crm/core/services/offline_queue_service.dart';
import 'dart:ui';

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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.square_arrow_right,
                  color: CupertinoColors.destructiveRed,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text('Log Out'),
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
                            0xFF4338CA,
                          ).withValues(alpha: 0.08 * _scrollProgress),
                          blurRadius: 16 * _scrollProgress,
                          offset: Offset(0, 6 * _scrollProgress),
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
                        child: InkWell(
                          onTap: () => _showQuickMenu(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                homeState.todayLabel,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${homeState.greeting}, ${homeState.user.firstName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
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
                      // Logout button with Cupertino icon
                      InkWell(
                        onTap: () => _confirmLogout(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFEE2E2,
                            ).withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            CupertinoIcons.square_arrow_right,
                            color: Color(0xFFDC2626),
                            size: 20,
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
                          bgColor: const Color(0xFFEEEDFD),
                          valueColor: const Color(0xFF312E81),
                          onTap: () => cubit.togglePendingOrDoneCalls(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricBox(
                          value: '${followUpsState.todayFollowUps.length}',
                          label: 'Follow-ups',
                          bgColor: const Color(0xFFE8F3FC),
                          valueColor: const Color(0xFF0369A1),
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
                          bgColor: const Color(0xFFFDECE3),
                          valueColor: const Color(0xFFC2410C),
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
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: state.totalCallsAssigned == 0
                          ? 0
                          : state.callsDoneCount / state.totalCallsAssigned,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4338CA),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${state.progressPercent}% of today's calls done · ${state.callsLeftCount} left",
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF667085),
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
                                letterSpacing: 0.7,
                                color: Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (state.dueNowLead != null)
                              Builder(
                                builder: (_) {
                                  final due = state.dueNowLead!;
                                  return InkWell(
                                    onTap: () => AppPhoneCallService.instance
                                        .dialLead(context, due),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 15,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFD95D24),
                                          width: 1.4,
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
                                                      size: 14,
                                                      color: Color(0xFFB45309),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      '${due.statusTag} · Due Today',
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFFB45309,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  due.name,
                                                  style: const TextStyle(
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  '${due.collegeInfo} · ${due.campaignTag}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF475467),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF4338CA),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              CupertinoIcons.phone_fill,
                                              color: Colors.white,
                                              size: 22,
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
                            const SizedBox(height: 22),

                            // 5. TODAY'S CALLS Header + Pending / Done Toggles
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "TODAY'S CALLS",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                                Row(
                                  children: [
                                    _TogglePill(
                                      label:
                                          'Pending ${state.pendingLeads.length}',
                                      isSelected: state.showingPendingCalls,
                                      onTap: () =>
                                          cubit.togglePendingOrDoneCalls(true),
                                    ),
                                    const SizedBox(width: 8),
                                    _TogglePill(
                                      label: 'Done ${state.doneLeads.length}',
                                      isSelected: !state.showingPendingCalls,
                                      onTap: () =>
                                          cubit.togglePendingOrDoneCalls(false),
                                    ),
                                  ],
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
                                  vertical: 28,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFEAECF0),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.assignment_turned_in_outlined,
                                      color: Color(0xFF667085),
                                      size: 30,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      state.showingPendingCalls
                                          ? 'No pending leads assigned to you for today'
                                          : 'No completed calls recorded yet today',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'New leads assigned by your Admin will appear here automatically.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed: cubit.refresh,
                                      icon: const Icon(
                                        CupertinoIcons.refresh,
                                        size: 16,
                                      ),
                                      label: const Text('Refresh'),
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

                            // 7. Quick Executive Utilities Row (FR-1.4 Walk-in / PR-2.2 Lookup / FR-6.2 My Record)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        LeadCallSheets.showPhoneLookupAndWalkInSheet(
                                          context,
                                        ),
                                    icon: const Icon(
                                      CupertinoIcons.person_add,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Phone Lookup / + Walk-in',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF344054),
                                      side: const BorderSide(
                                        color: Color(0xFFD0D5DD),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      LeadCallSheets.showMyRecordSheet(context),
                                  icon: const Icon(
                                    Icons.bar_chart_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('My Record'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF344054),
                                    side: const BorderSide(
                                      color: Color(0xFFD0D5DD),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: widget.onLogout,
                                  tooltip: 'Sign out',
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 18,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Top Frosted Glass Blur & Fade Overlay when scrolling
                  if (_scrollProgress > 0.01)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 26,
                      child: IgnorePointer(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 6.0 * _scrollProgress,
                              sigmaY: 6.0 * _scrollProgress,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(
                                      0xFFF5F6FA,
                                    ).withValues(alpha: 0.90 * _scrollProgress),
                                    const Color(
                                      0xFFF5F6FA,
                                    ).withValues(alpha: 0.0),
                                  ],
                                ),
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

  void _showQuickMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFF4338CA),
                  ),
                  title: const Text(
                    'My Record & Performance (FR-6.2)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    LeadCallSheets.showMyRecordSheet(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    CupertinoIcons.search,
                    color: Color(0xFF4338CA),
                  ),
                  title: const Text(
                    '10-Digit Phone Lookup & Walk-in Lead (FR-1.4 / PR-2.2)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    LeadCallSheets.showPhoneLookupAndWalkInSheet(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFB42318),
                  ),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB42318),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onLogout();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String value;
  final String label;
  final Color bgColor;
  final Color valueColor;
  final VoidCallback onTap;

  const _MetricBox({
    required this.value,
    required this.label,
    required this.bgColor,
    required this.valueColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: valueColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475467),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4338CA) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFD0D5DD)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
          ),
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Initials Circle
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEDFD),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                item.initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3730A3),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Center Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.collegeInfo,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.statusTag,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: item.statusColor,
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
                            fontSize: 12.5,
                            color: Color(0xFF475467),
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
                        Text(
                          item.lockedMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Right Phone Button (hidden when locked by another executive)
            if (!item.isLocked)
              InkWell(
                onTap: onTapCall,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEEDFD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.phone_fill,
                    color: Color(0xFF4338CA),
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

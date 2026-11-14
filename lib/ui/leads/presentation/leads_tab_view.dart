import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:acadeno_crm/shared/theme/app_svgs.dart';
import 'package:flutter/cupertino.dart';
import 'package:acadeno_crm/core/services/app_phone_call_service.dart';
import 'package:acadeno_crm/core/services/offline_queue_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_cubit.dart';
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
  bool _isRefreshing = false;

  Future<void> _performRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    context.read<LeadsCubit>().refresh();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _confirmLogout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Card (Expands with device width, 10px padding from device, border-radius 24)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Gap(22),
                      const Text(
                        'Log Out',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Gap(8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Are you sure you want to end your current session?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const Gap(20),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF1F5F9),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onLogout();
                        },
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                        child: SizedBox(
                          height: 56,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                AppSvgs.logout,
                                width: 18,
                                height: 18,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFFEF4444),
                                  BlendMode.srcIn,
                                ),
                              ),
                              const Gap(8),
                              const Text(
                                'Log Out',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(10),

                // Bottom Cancel Button (Expands with device width, 10px padding from device, height 58, padding 16/24, border-radius 24)
                Container(
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(24),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0066CC),
                              letterSpacing: -0.2,
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
        );
      },
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
        final homeState = context.watch<HomeCubit>().state;
        final followUpsState = context.watch<FollowUpsCubit>().state;
        final pad = context.devicePadding;
        final displayedLeads = state.showingPendingCalls
            ? state.pendingLeads
            : state.doneLeads;

        final isShortScreen = MediaQuery.sizeOf(context).height < 560;
        final topHeaderSection = Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6)),
            ),
            boxShadow: !isShortScreen && _scrollProgress > 0.01
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
          padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
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
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${homeState.greeting}, ${homeState.user.firstName.isNotEmpty ? homeState.user.firstName : "Test"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 28 / 20,
                            color: Color(0xFF111827),
                            letterSpacing: -0.02,
                          ),
                        ),
                        Text(
                          homeState.todayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 16 / 12,
                            color: Color(0xFF6B7280),
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
                            const Gap(4),
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
              const Gap(16),

              // 2. Three Metric Cards Row (Static display metrics — no tap navigation or toggles)
              Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      value:
                          '${state.callsDoneCount}/${state.totalCallsAssigned}',
                      label: 'Calls done',
                      bgColor: const Color(0xFFEEF2FF),
                      valueColor: const Color(0xFF4338CA),
                      labelColor: const Color(0xCC4338CA),
                      valueLetterSpacing: -0.8,
                      labelLetterSpacing: 0.086,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _MetricBox(
                      value: '${followUpsState.todayFollowUps.length}',
                      label: 'Follow-ups',
                      bgColor: const Color(0xFFF0F9FF),
                      valueColor: const Color(0xFF0369A1),
                      labelColor: const Color(0xCC0369A1),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _MetricBox(
                      value: '${followUpsState.overdueFollowUps.length}',
                      label: 'Overdue',
                      bgColor: const Color(0xFFFFF7ED),
                      valueColor: const Color(0xFFC2410C),
                      labelColor: const Color(0xCCC2410C),
                      labelLetterSpacing: 0.193,
                    ),
                  ),
                ],
              ),
              const Gap(16),

              // 3. Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: LinearProgressIndicator(
                  value: state.totalCallsAssigned == 0
                      ? 0
                      : state.callsDoneCount / state.totalCallsAssigned,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF6366F1),
                  ),
                ),
              ),
              const Gap(8),
              Text(
                "${state.progressPercent}% of today's calls done · ${state.callsLeftCount} left",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 16 / 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pinned at top on portrait phones; scrolls with content on short landscape viewports
            if (!isShortScreen) topHeaderSection,

            // Lower Gray Body (#F9FAFB) — Scrolls from DUE NOW downward with blur edge
            Expanded(
              child: Stack(
                children: [
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(platform: TargetPlatform.iOS),
                    child: RefreshIndicator.adaptive(
                      color: const Color(0xFF4338CA),
                      backgroundColor: Colors.white,
                      displacement: 24,
                      onRefresh: _performRefresh,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleScroll,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isShortScreen) topHeaderSection,
                              Padding(
                                padding: EdgeInsets.fromLTRB(pad, 20, pad, 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 4. DUE NOW Section (Shows top overdue or due contact one-by-one)
                              const Text(
                                'DUE NOW',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 15 / 10,
                                  letterSpacing: 1.0,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              const Gap(12),
                              Builder(
                                builder: (_) {
                                  final hasOverdue = followUpsState
                                      .overdueFollowUps
                                      .isNotEmpty;
                                  final topOverdue = hasOverdue
                                      ? followUpsState.overdueFollowUps.first
                                      : null;
                                  final dueLead = state.dueNowLead;

                                  if (topOverdue != null) {
                                    final overdueLead = ExecutiveLeadItem(
                                      id: topOverdue.id,
                                      name: topOverdue.leadName,
                                      initials: topOverdue.leadName.isNotEmpty
                                          ? topOverdue.leadName[0].toUpperCase()
                                          : 'L',
                                      maskedPhone: topOverdue.maskedPhone,
                                      fullPhone: topOverdue.phone.isNotEmpty
                                          ? topOverdue.phone
                                          : topOverdue.maskedPhone,
                                      collegeInfo: topOverdue.collegeInfo,
                                      statusTag: 'Follow-up',
                                      statusColor: const Color(0xFFEF8144),
                                      statusBg: const Color(0xFFFEF0E6),
                                      campaignTag: topOverdue.note.isNotEmpty
                                          ? topOverdue.note
                                          : 'Follow-up Due',
                                      followUpTime: topOverdue.timeLabel,
                                    );

                                    const overdueTag = 'Follow-up · Due Today';

                                    return InkWell(
                                      onTap: () =>
                                          LeadCallSheets.showLeadDetailSheet(
                                            context,
                                            lead: overdueLead,
                                          ),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0x4DF97316),
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  CupertinoIcons.clock_fill,
                                                  size: 13,
                                                  color: Color(0xFFC2410C),
                                                ),
                                                const Gap(8),
                                                Flexible(
                                                  child: Text(
                                                    overdueTag,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 16 / 12,
                                                      letterSpacing: 0.082,
                                                      color: Color(0xFFC2410C),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Gap(8),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        topOverdue.leadName,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          height: 28 / 18,
                                                          color: Color(
                                                            0xFF111827,
                                                          ),
                                                        ),
                                                      ),
                                                      const Gap(3),
                                                      Text(
                                                        '${topOverdue.collegeInfo.isNotEmpty ? topOverdue.collegeInfo : 'Student'} · ${topOverdue.note.isNotEmpty ? topOverdue.note : 'Follow-up call scheduled'}',
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: Color(
                                                            0xFF6B7280,
                                                          ),
                                                          height: 22.75 / 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Gap(14),
                                                InkWell(
                                                  onTap: () =>
                                                      AppPhoneCallService
                                                          .instance
                                                          .dialFollowUpItem(
                                                            context,
                                                            topOverdue,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                  child: Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Color(
                                                            0xFFEF8144,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Color(
                                                                0xFFC7D2FE,
                                                              ),
                                                              blurRadius: 15,
                                                              spreadRadius: -3,
                                                              offset: Offset(
                                                                0,
                                                                10,
                                                              ),
                                                            ),
                                                            BoxShadow(
                                                              color: Color(
                                                                0xFFC7D2FE,
                                                              ),
                                                              blurRadius: 6,
                                                              spreadRadius: -4,
                                                              offset: Offset(
                                                                0,
                                                                4,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                    child: const Icon(
                                                      CupertinoIcons.phone_fill,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  if (dueLead != null) {
                                    return InkWell(
                                      onTap: () =>
                                          LeadCallSheets.showLeadDetailSheet(
                                            context,
                                            lead: dueLead,
                                          ),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0x4DF97316),
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  CupertinoIcons.clock_fill,
                                                  size: 13,
                                                  color: Color(0xFFC2410C),
                                                ),
                                                const Gap(8),
                                                Flexible(
                                                  child: Text(
                                                    '${dueLead.statusTag} · Due Today',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 16 / 12,
                                                      letterSpacing: 0.082,
                                                      color: Color(0xFFC2410C),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Gap(8),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        dueLead.name,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          height: 28 / 18,
                                                          color: Color(
                                                            0xFF111827,
                                                          ),
                                                        ),
                                                      ),
                                                      const Gap(3),
                                                      Text(
                                                        '${dueLead.collegeInfo} · ${dueLead.campaignTag}',
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: Color(
                                                            0xFF6B7280,
                                                          ),
                                                          height: 22.75 / 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Gap(14),
                                                InkWell(
                                                  onTap: () =>
                                                      AppPhoneCallService
                                                          .instance
                                                          .dialLead(
                                                            context,
                                                            dueLead,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                  child: Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Color(
                                                            0xFFEF8144,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Color(
                                                                0xFFC7D2FE,
                                                              ),
                                                              blurRadius: 15,
                                                              spreadRadius: -3,
                                                              offset: Offset(
                                                                0,
                                                                10,
                                                              ),
                                                            ),
                                                            BoxShadow(
                                                              color: Color(
                                                                0xFFC7D2FE,
                                                              ),
                                                              blurRadius: 6,
                                                              spreadRadius: -4,
                                                              offset: Offset(
                                                                0,
                                                                4,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                    child: const Icon(
                                                      CupertinoIcons.phone_fill,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  return Container(
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
                                        Gap(10),
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
                                  );
                                },
                              ),
                              const Gap(16),

                              // Quick Actions: Add Walk-in Lead & My Record (Figma: 141x34 & 113x34 pills, 11px gap)
                              Row(
                                children: [
                                  Flexible(
                                    child: InkWell(
                                      onTap: () =>
                                          LeadCallSheets.showPhoneLookupAndWalkInSheet(
                                            context,
                                          ),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 141,
                                        height: 34,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFF3F4F6),
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
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                AppSvgs.addWalkInLead,
                                                width: 17,
                                                height: 17,
                                              ),
                                              const Gap(8),
                                              const Text(
                                                'Add Walk-in Lead',
                                                maxLines: 1,
                                                softWrap: false,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                  height: 16 / 12,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Gap(11),
                                  Flexible(
                                    child: InkWell(
                                      onTap: () =>
                                          LeadCallSheets.showMyRecordSheet(
                                            context,
                                          ),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 113,
                                        height: 34,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFF3F4F6),
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
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                AppSvgs.myRecord,
                                                width: 15,
                                                height: 15,
                                              ),
                                              const Gap(8),
                                              const Text(
                                                'My Record',
                                                maxLines: 1,
                                                softWrap: false,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                  height: 16 / 12,
                                                  color: Color(0xFF6B7280),
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
                              const Gap(20),

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
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          height: 15 / 10,
                                          letterSpacing: 1.0,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Gap(8),
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
                                              const Gap(4),
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
                              const Gap(12),

                              // 6. Call Cards List (Loading, Error/Permission, Empty, or Assigned Leads)
                              if (state.isLoading && state.leads.isEmpty)
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
                                      Gap(12),
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
                                      const Gap(8),
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
                                      const Gap(4),
                                      Text(
                                        state.errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF667085),
                                        ),
                                      ),
                                      const Gap(12),
                                      OutlinedButton.icon(
                                        onPressed: _isRefreshing
                                            ? null
                                            : _performRefresh,
                                        icon: _isRefreshing
                                            ? const CupertinoActivityIndicator(
                                                radius: 7,
                                              )
                                            : const Icon(
                                                CupertinoIcons.refresh,
                                                size: 16,
                                              ),
                                        label: Text(
                                          _isRefreshing
                                              ? 'Refreshing...'
                                              : 'Retry',
                                        ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Top Icon Container
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                      const Gap(20),

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
                                      const Gap(8),

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
                                      const Gap(24),

                                      // Action Buttons (Responsive flex row)
                                      Row(
                                        children: [
                                          if (!state.showingPendingCalls) ...[
                                            // Back to Pending Calls Button (Figma: minWidth 157, expands with box, height 44, gap 14.23, padding [16, 12, 22.25, 12], radius 12, #D35501)
                                            Expanded(
                                              flex: 8,
                                              child: SizedBox(
                                                height: 44,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color:
                                                            const Color(
                                                              0xFFD35501,
                                                            ).withValues(
                                                              alpha: 0.32,
                                                            ),
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
                                                          const Color(
                                                            0xFFD35501,
                                                          ),
                                                      foregroundColor:
                                                          Colors.white,
                                                      elevation: 0,
                                                      shadowColor:
                                                          Colors.transparent,
                                                      minimumSize: const Size(
                                                        157,
                                                        44,
                                                      ),
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 16,
                                                            top: 12,
                                                            right: 22.25,
                                                            bottom: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        SvgPicture.asset(
                                                          AppSvgs.arrowLeft,
                                                          width: 14,
                                                          height: 14,
                                                          colorFilter:
                                                              const ColorFilter.mode(
                                                                Colors.white,
                                                                BlendMode.srcIn,
                                                              ),
                                                        ),
                                                        const Gap(14.23),
                                                        const Flexible(
                                                          child: FittedBox(
                                                            fit: BoxFit
                                                                .scaleDown,
                                                            child: Text(
                                                              'Back to Pending Calls',
                                                              maxLines: 1,
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'Inter',
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .white,
                                                                letterSpacing:
                                                                    -0.2,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const Gap(10),
                                          ],

                                          // Refresh Button (Figma: flex 5, height 44, radius 12, border 1px #E2E8F0, 3-sec loading indicator)
                                          Expanded(
                                            flex: state.showingPendingCalls
                                                ? 1
                                                : 5,
                                            child: SizedBox(
                                              height: 44,
                                              child: OutlinedButton(
                                                onPressed: _isRefreshing
                                                    ? null
                                                    : _performRefresh,
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
                                                      if (_isRefreshing) ...[
                                                        const CupertinoActivityIndicator(
                                                          radius: 7.5,
                                                        ),
                                                        const Gap(7),
                                                        const Text(
                                                          'Refreshing...',
                                                          style: TextStyle(
                                                            fontFamily: 'Inter',
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Color(
                                                              0xFF334155,
                                                            ),
                                                          ),
                                                        ),
                                                      ] else ...[
                                                        const Icon(
                                                          CupertinoIcons
                                                              .refresh,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF475467,
                                                          ),
                                                        ),
                                                        const Gap(7),
                                                        const Text(
                                                          'Refresh',
                                                          style: TextStyle(
                                                            fontFamily: 'Inter',
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Color(
                                                              0xFF334155,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
                                      const Gap(10),
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
                                    const Gap(16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Top Ambient Shade Overlay when scrolling (Smooth gradient shade without cutting)
                  if (!isShortScreen && _scrollProgress > 0.01)
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
  final double valueLetterSpacing;
  final double labelLetterSpacing;

  const _MetricBox({
    required this.value,
    required this.label,
    required this.bgColor,
    required this.valueColor,
    this.labelColor = const Color(0xFF475467),
    this.valueLetterSpacing = -0.5,
    this.labelLetterSpacing = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 32 / 24,
                  color: valueColor,
                  letterSpacing: valueLetterSpacing,
                ),
              ),
              const Gap(4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 16.5 / 11,
                  color: labelColor,
                  letterSpacing: labelLetterSpacing,
                ),
              ),
            ],
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
        padding: const EdgeInsets.all(16),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Initials Circle (Figma 1350:1652: 48x48, bg #EEF2FF, Inter Bold 16px #6366F1)
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
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 24 / 16,
                  letterSpacing: 0.39,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
            const Gap(16),

            // Right Details + Call Button + Bottom Tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 24 / 16,
                                letterSpacing: 0.06,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const Gap(2),
                            Text(
                              item.collegeInfo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 16 / 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!item.isLocked) ...[
                        const Gap(8),
                        InkWell(
                          onTap: onTapCall,
                          borderRadius: BorderRadius.circular(9999),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                color: const Color(0xFFF3F4F6),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              CupertinoIcons.phone_fill,
                              color: Color(0xFF6366F1),
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      Flexible(
                        flex: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            item.statusTag.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 15 / 10,
                              letterSpacing: 0.06,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Text(
                            item.campaignTag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              height: 15 / 10,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.isLocked && item.lockedMessage != null) ...[
                    const Gap(6),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.lock,
                          size: 13.5,
                          color: Color(0xFFB45309),
                        ),
                        const Gap(4),
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

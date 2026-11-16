import 'package:acadeno_crm/core/services/firestore_stream_cache.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:acadeno_crm/shared/utilities/link_launcher.dart';
import 'package:acadeno_crm/shared/widgets/college_selector_field.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/theme/app_svgs.dart';
import 'package:acadeno_crm/ui/dashboard/presentation/widgets/figma_calendar_dialog.dart';
import 'package:acadeno_crm/ui/visits/application/visits_cubit.dart';
import 'package:acadeno_crm/ui/visits/application/visits_state.dart';
import 'package:acadeno_crm/ui/visits/data/model/visit_models.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VisitsTabView extends StatefulWidget {
  const VisitsTabView({super.key});

  @override
  State<VisitsTabView> createState() => _VisitsTabViewState();
}

class _VisitsTabViewState extends State<VisitsTabView> {
  late final PageController _pageController;
  bool _isProgrammaticScroll = false;
  int? _targetPageIndex;

  @override
  void initState() {
    super.initState();
    final initialIndex = context.read<VisitsCubit>().state.selectedBucket.index;
    _pageController = PageController(initialPage: initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(VisitsCubit cubit, VisitStatusBucket bucket) {
    final target = bucket.index;
    if (_pageController.hasClients &&
        _pageController.page?.round() == target &&
        !_isProgrammaticScroll) {
      return;
    }
    setState(() {
      _isProgrammaticScroll = true;
      _targetPageIndex = target;
    });
    cubit.selectBucket(bucket);
    if (_pageController.hasClients) {
      _pageController
          .animateToPage(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
          )
          .then((_) {
            if (mounted) {
              setState(() {
                _isProgrammaticScroll = false;
                _targetPageIndex = null;
              });
            }
          });
    } else {
      _isProgrammaticScroll = false;
      _targetPageIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VisitsCubit, VisitsState>(
      listener: (context, state) {
        final targetPage = state.selectedBucket.index;
        if (!_isProgrammaticScroll &&
            _pageController.hasClients &&
            _pageController.page?.round() != targetPage) {
          _pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<VisitsCubit>();
        final media = MediaQuery.of(context);
        final screenWidth = media.size.width;
        final isLandscape = media.orientation == Orientation.landscape;
        final isCompact = screenWidth < 360;
        final hPad = isCompact ? 16.0 : 24.0;
        final topPad = media.padding.top > 0
            ? media.padding.top + (isLandscape ? 10.0 : 16.0)
            : (isLandscape ? 12.0 : 20.0);
        final headerToTabsGap = isLandscape ? 12.0 : 20.0;

        return Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top White Header with Title, "Log visit" action button, and 3 Status Tabs
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'College visits',
                              style: GoogleFonts.inter(
                                fontSize: isCompact ? 22 : 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                                height: 32 / 24,
                              ),
                            ),
                            SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                onPressed: () => _showLogVisitModal(context),
                                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                label: Text(
                                  'Log visit',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE64A19),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: const Color(0x0D000000),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Gap(headerToTabsGap),

                        // Flat Tab Headers: UPCOMING | COMPLETED | CANCELLED
                        Row(
                          children: [
                            Expanded(
                              child: _VisitTabItem(
                                title: 'UPCOMING',
                                count: state.upcomingCount,
                                alignment: Alignment.centerLeft,
                                isSelected:
                                    state.selectedBucket == VisitStatusBucket.upcoming,
                                onTap: () => _onTabTapped(
                                  cubit,
                                  VisitStatusBucket.upcoming,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _VisitTabItem(
                                title: 'COMPLETED',
                                count: state.completedCount,
                                alignment: Alignment.center,
                                isSelected:
                                    state.selectedBucket == VisitStatusBucket.completed,
                                onTap: () => _onTabTapped(
                                  cubit,
                                  VisitStatusBucket.completed,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _VisitTabItem(
                                title: 'CANCELLED',
                                count: state.cancelledCount,
                                alignment: Alignment.centerRight,
                                isSelected:
                                    state.selectedBucket == VisitStatusBucket.cancelled,
                                onTap: () => _onTabTapped(
                                  cubit,
                                  VisitStatusBucket.cancelled,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(8),

                        // Continuous sliding 2px indicator matching Follow-ups style
                        SizedBox(
                          height: 2,
                          width: double.infinity,
                          child: AnimatedAlign(
                            alignment: switch (state.selectedBucket) {
                              VisitStatusBucket.upcoming => Alignment.centerLeft,
                              VisitStatusBucket.completed => Alignment.center,
                              VisitStatusBucket.cancelled => Alignment.centerRight,
                            },
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOutCubic,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeInOutCubic,
                              height: 2,
                              width: switch (state.selectedBucket) {
                                VisitStatusBucket.upcoming =>
                                  isCompact ? 72.0 : 86.0,
                                VisitStatusBucket.completed =>
                                  isCompact ? 78.0 : 94.0,
                                VisitStatusBucket.cancelled =>
                                  isCompact ? 74.0 : 88.0,
                              },
                              decoration: BoxDecoration(
                                color: const Color(0xFFE64A19),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // PageView supporting horizontal swipe navigation between Upcoming, Completed, and Cancelled
              Expanded(
                child: ColoredBox(
                  color: const Color(0xFFF8F9FA),
                  child: PageView(
                    controller: _pageController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    onPageChanged: (pageIndex) {
                      if (_isProgrammaticScroll) {
                        if (_targetPageIndex != null &&
                            pageIndex == _targetPageIndex) {
                          setState(() {
                            _isProgrammaticScroll = false;
                            _targetPageIndex = null;
                          });
                        }
                        return;
                      }
                      final bucket = VisitStatusBucket.values[pageIndex];
                      cubit.selectBucket(bucket);
                    },
                    children: [
                      _buildVisitBucketPage(
                        context: context,
                        items: state.upcomingVisits,
                        bucket: VisitStatusBucket.upcoming,
                        cubit: cubit,
                        pad: hPad,
                        isLandscape: isLandscape,
                      ),
                      _buildVisitBucketPage(
                        context: context,
                        items: state.completedVisits,
                        bucket: VisitStatusBucket.completed,
                        cubit: cubit,
                        pad: hPad,
                        isLandscape: isLandscape,
                      ),
                      _buildVisitBucketPage(
                        context: context,
                        items: state.cancelledVisits,
                        bucket: VisitStatusBucket.cancelled,
                        cubit: cubit,
                        pad: hPad,
                        isLandscape: isLandscape,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitBucketPage({
    required BuildContext context,
    required List<ExecutiveCollegeVisit> items,
    required VisitStatusBucket bucket,
    required VisitsCubit cubit,
    required double pad,
    required bool isLandscape,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
      child: RefreshIndicator.adaptive(
        color: const Color(0xFF4338CA),
        backgroundColor: Colors.white,
        onRefresh: () async {
          cubit.refresh();
          await Future.delayed(const Duration(milliseconds: 1000));
        },
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  pad.clamp(16.0, 24.0),
                  isLandscape ? 16 : 24,
                  pad.clamp(16.0, 24.0),
                  32,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildEmptyState(context, bucket),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  pad.clamp(16.0, 24.0),
                  isLandscape ? 14 : 20,
                  pad.clamp(16.0, 24.0),
                  32,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Gap(14), // Strictly >= 10px spacing
                itemBuilder: (context, index) {
                  final visit = items[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: switch (bucket) {
                        VisitStatusBucket.upcoming => _UpcomingVisitCard(
                            key: ValueKey(visit.id),
                            visit: visit,
                            onDirections: () => _handleDirections(context, visit),
                            onRecordOutcome: () =>
                                _showRecordOutcomeSheet(context, visit),
                            onCancel: () =>
                                _showCancelVisitDialog(context, visit),
                            onDelete: () =>
                                _confirmDeleteVisit(context, visit),
                          ),
                        VisitStatusBucket.completed => _RecentVisitCard(
                            key: ValueKey(visit.id),
                            visit: visit,
                            onDirections: () => _handleDirections(context, visit),
                            onRecordOutcome: () =>
                                _showRecordOutcomeSheet(context, visit),
                            onDelete: () =>
                                _confirmDeleteVisit(context, visit),
                          ),
                        VisitStatusBucket.cancelled => _CancelledVisitCard(
                            key: ValueKey(visit.id),
                            visit: visit,
                            onReschedule: () =>
                                _showRescheduleDialog(context, visit),
                            onDelete: () =>
                                _confirmDeleteVisit(context, visit),
                          ),
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, VisitStatusBucket bucket) {
    final (icon, iconColor, iconBg, title, subtitle, showAction) =
        switch (bucket) {
      VisitStatusBucket.upcoming => (
          CupertinoIcons.calendar_today,
          const Color(0xFF4A3AFF),
          const Color(0xFFEEEBF6),
          'No upcoming visits',
          'You have no college campus visits scheduled right now.\nTap "Log visit" below to schedule a new visit.',
          true,
        ),
      VisitStatusBucket.completed => (
          Icons.verified_outlined,
          const Color(0xFF166534),
          const Color(0xFFF0FDF4),
          'No completed visits yet',
          'Visits you complete will appear here along with collected leads, student interest counts, and follow-up notes.',
          false,
        ),
      VisitStatusBucket.cancelled => (
          Icons.event_busy_outlined,
          const Color(0xFFDC2626),
          const Color(0xFFFEF2F2),
          'No cancelled visits',
          'Any cancelled or discontinued campus visits will be kept here for reference.',
          false,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const Gap(16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const Gap(6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          if (showAction) ...[
            const Gap(20),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => _showLogVisitModal(context),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: Text(
                  'Log visit',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE64A19),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelVisitDialog(
    BuildContext context,
    ExecutiveCollegeVisit visit,
  ) {
    final cubit = context.read<VisitsCubit>();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Cancel Visit',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel the campus visit to ${visit.collegeName}?',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const Gap(16),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Cancellation reason (e.g. exams, rescheduled)...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFD45107),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Keep Visit',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              cubit.cancelCollegeVisit(
                visitId: visit.id,
                reason: reasonCtrl.text.trim().isNotEmpty
                    ? reasonCtrl.text.trim()
                    : 'Visit cancelled by executive',
              );
              if (context.mounted) {
                SnackBarAlert.showToast(
                  context: context,
                  message: 'Visit cancelled for ${visit.collegeName}',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel Visit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRescheduleDialog(
    BuildContext context,
    ExecutiveCollegeVisit visit,
  ) async {
    final cubit = context.read<VisitsCubit>();
    final picked = await showFigmaCalendarDialog(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && context.mounted) {
      final dayStr = picked.day.toString();
      final monthStr = DateFormat('MMM').format(picked).toUpperCase();
      cubit.updateVisitStatus(
        visitId: visit.id,
        newStatus: 'Planned',
        dayNumber: dayStr,
        monthShort: monthStr,
      );
      if (context.mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'Visit rescheduled to $dayStr $monthStr ✓',
        );
      }
    }
  }

  Future<void> _handleDirections(
    BuildContext context,
    ExecutiveCollegeVisit visit,
  ) async {
    final college = visit.collegeName;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
            const Gap(10),
            Expanded(
              child: Text(
                'Opening Google Maps navigation for $college...',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );

    final launched = await LinkLauncher.launchCollegeMapsDirections(
      college,
      locationHint: visit.subtitle,
    );

    if (!launched && context.mounted) {
      _showDirectionsSheet(context, visit);
    }
  }

  void _showDirectionsSheet(BuildContext context, ExecutiveCollegeVisit visit) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: EdgeInsets.all(ctx.devicePadding.clamp(16.0, 22.0)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEDFD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car_filled_outlined,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit.collegeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            visit.subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFF4338CA),
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              'Destination: ${visit.collegeName}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (visit.purpose.isNotEmpty) ...[
                        const Gap(6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const Gap(6),
                            Expanded(
                              child: Text(
                                'Purpose: ${visit.purpose}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF475467),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Gap(6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              'Assigned: ${visit.staffNames}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475467),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFFD0D5DD)),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Color(0xFF344054),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          LinkLauncher.launchCollegeMapsDirections(
                            visit.collegeName,
                            locationHint: visit.subtitle,
                          );
                        },
                        icon: const Icon(Icons.navigation_rounded, size: 17),
                        label: const Text('Start Navigation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4338CA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  Future<void> _confirmDeleteVisit(
    BuildContext context,
    ExecutiveCollegeVisit visit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Visit',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to remove the visit to ${visit.collegeName}?',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475467),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<VisitsCubit>().deleteCollegeVisit(visit.id);
    }
  }

  void _showRecordOutcomeSheet(
    BuildContext context,
    ExecutiveCollegeVisit visit,
  ) {
    final cubit = context.read<VisitsCubit>();
    final formKey = GlobalKey<FormState>();
    final metCtrl = TextEditingController(text: visit.metSummary);
    final nextCtrl = TextEditingController(text: visit.nextActionSummary);
    final leadsCtrl = TextEditingController(
      text: visit.leadsCollected > 0 ? '${visit.leadsCollected}' : '',
    );
    final interestedCtrl = TextEditingController(
      text: visit.interestedCount > 0 ? '${visit.interestedCount}' : '',
    );
    bool isCancelled = visit.statusLabel == 'Cancelled';
    final cancelReasonCtrl = TextEditingController(
      text: isCancelled ? visit.metSummary : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Dialog(
          backgroundColor: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 385),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      'Record Visit Outcome',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 27.5 / 20,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const Gap(6),
                    Text(
                      '${visit.collegeName} · Outcome & student attendance',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 21.13 / 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const Gap(18),

                    // Modern Segmented Status Toggle (Completed vs Cancelled)
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {
                                  isCancelled = false;
                                  formKey.currentState?.reset();
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !isCancelled
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !isCancelled
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x0D000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: !isCancelled
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Completed',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: !isCancelled
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: !isCancelled
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {
                                  isCancelled = true;
                                  formKey.currentState?.reset();
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCancelled
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isCancelled
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x0D000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cancel_rounded,
                                      size: 16,
                                      color: isCancelled
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Cancelled',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isCancelled
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isCancelled
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(14),

                    // Inputs matching Log Visit Figma styling with Native Form Validation
                    if (!isCancelled) ...[
                      TextFormField(
                        key: const ValueKey('completed_persons_met'),
                        controller: metCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        validator: (v) {
                          if (isCancelled) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter persons met';
                          }
                          return null;
                        },
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Persons met (HOD / Faculty) *',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(
                            Icons.people_outline_rounded,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD45107),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                          errorStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFEF4444),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const Gap(14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const ValueKey('completed_leads_collected'),
                              controller: leadsCtrl,
                              keyboardType: TextInputType.number,
                              textAlignVertical: TextAlignVertical.center,
                              validator: (v) {
                                if (isCancelled) return null;
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter count';
                                }
                                final n = int.tryParse(v.trim());
                                if (n == null || n < 0) {
                                  return 'Invalid count';
                                }
                                return null;
                              },
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Leads collected *',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                prefixIcon: const Icon(
                                  Icons.how_to_reg_outlined,
                                  size: 19,
                                  color: Color(0xFF64748B),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD45107),
                                    width: 1.5,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEF4444),
                                    width: 1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEF4444),
                                    width: 1.5,
                                  ),
                                ),
                                errorStyle: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFEF4444),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: TextFormField(
                              key: const ValueKey('completed_interested_count'),
                              controller: interestedCtrl,
                              keyboardType: TextInputType.number,
                              textAlignVertical: TextAlignVertical.center,
                              validator: (v) {
                                if (isCancelled) return null;
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter count';
                                }
                                final n = int.tryParse(v.trim());
                                if (n == null || n < 0) {
                                  return 'Invalid count';
                                }
                                return null;
                              },
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Interested *',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                prefixIcon: const Icon(
                                  Icons.thumb_up_alt_outlined,
                                  size: 19,
                                  color: Color(0xFF64748B),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD45107),
                                    width: 1.5,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEF4444),
                                    width: 1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEF4444),
                                    width: 1.5,
                                  ),
                                ),
                                errorStyle: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFEF4444),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(14),
                      TextFormField(
                        key: const ValueKey('completed_next_action'),
                        controller: nextCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        validator: (v) {
                          if (isCancelled) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter next action & follow-up';
                          }
                          return null;
                        },
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Next action & follow-up *',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(
                            Icons.event_note_outlined,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD45107),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                          errorStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFEF4444),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ] else ...[
                      TextFormField(
                        key: const ValueKey('cancelled_reason_notes'),
                        controller: cancelReasonCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        validator: (v) {
                          if (!isCancelled) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter cancellation reason & notes';
                          }
                          return null;
                        },
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cancellation reason & notes *',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(
                            Icons.report_problem_outlined,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD45107),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                          errorStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFEF4444),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                    const Gap(20),

                    // Primary Action Button (Same as Log Visit)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          if (isCancelled) {
                            cubit.cancelCollegeVisit(
                              visitId: visit.id,
                              reason: cancelReasonCtrl.text.trim().isNotEmpty
                                  ? cancelReasonCtrl.text.trim()
                                  : metCtrl.text.trim(),
                            );
                          } else {
                            cubit.recordVisitOutcome(
                              visitId: visit.id,
                              metPeople: metCtrl.text.trim(),
                              nextAction: nextCtrl.text.trim(),
                              leadsCollected:
                                  int.tryParse(leadsCtrl.text.trim()) ?? 0,
                              interestedCount:
                                  int.tryParse(interestedCtrl.text.trim()) ?? 0,
                            );
                          }
                          Navigator.pop(ctx);
                          if (context.mounted) {
                            SnackBarAlert.showToast(
                              context: context,
                              message: isCancelled
                                  ? 'Visit marked as cancelled'
                                  : 'Visit outcome saved for ${visit.collegeName}',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD45107),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.only(
                            top: 14.5,
                            bottom: 15.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isCancelled
                              ? 'Save as Cancelled'
                              : 'Save Visit Outcome',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
      ),
    ),
  );
}

  void _showLogVisitModal(BuildContext context) {
    final cubit = context.read<VisitsCubit>();
    final formKey = GlobalKey<FormState>();
    final collegeCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final dateCtrl = TextEditingController(
      text: DateFormat('dd MMM yyyy').format(selectedDate),
    );
    final subCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 385),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan College Visit',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 27.5 / 20,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Gap(6),
                      Text(
                        'Schedule campus seminar, workshop, or student drive',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 21.13 / 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const Gap(18),
                      TextFormField(
                        controller: collegeCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter college name';
                          }
                          return null;
                        },
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'College Name *',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(
                            Icons.account_balance_outlined,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD45107),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                          errorStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFEF4444),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const Gap(14),
                      InkWell(
                        onTap: () async {
                          final picked = await showFigmaCalendarDialog(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                              dateCtrl.text = DateFormat(
                                'dd MMM yyyy',
                              ).format(picked);
                            });
                          }
                        },
                        child: IgnorePointer(
                          child: TextFormField(
                            controller: dateCtrl,
                            textAlignVertical: TextAlignVertical.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Visit Date *',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              prefixIcon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 19,
                                color: Color(0xFF64748B),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD45107),
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEF4444),
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEF4444),
                                  width: 1.5,
                                ),
                              ),
                              errorStyle: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFEF4444),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Gap(14),
                      TextFormField(
                        controller: subCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter department or location';
                          }
                          return null;
                        },
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Department / Location *',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(
                            Icons.place_outlined,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD45107),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                          errorStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFEF4444),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const Gap(14),
                      TextFormField(
                        controller: purposeCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter visit purpose';
                          }
                          return null;
                        },
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Visit Purpose *',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(
                            Icons.assignment_outlined,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD45107),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                          errorStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFEF4444),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const Gap(20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            CollegeSelectorField.saveCollegeIfNew(
                              collegeCtrl.text.trim(),
                            );
                            final dayNum = DateFormat('dd').format(selectedDate);
                            final month = DateFormat(
                              'MMM',
                            ).format(selectedDate).toUpperCase();
                            cubit.addCollegeVisit(
                              collegeName: collegeCtrl.text.trim(),
                              dayNumber: dayNum,
                              monthShort: month,
                              subtitle: subCtrl.text.trim().isNotEmpty
                                  ? subCtrl.text.trim()
                                  : DateFormat(
                                      'EEE · hh:mm a',
                                    ).format(selectedDate),
                              purpose: purposeCtrl.text.trim().isNotEmpty
                                  ? purposeCtrl.text.trim()
                                  : 'Campus outreach & student interaction',
                            );
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD45107),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.only(
                              top: 14.5,
                              bottom: 15.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Save College Visit',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
        ),
      ),
    );
  }
}

class _UpcomingVisitCard extends StatelessWidget {
  final ExecutiveCollegeVisit visit;
  final VoidCallback onDirections;
  final VoidCallback onRecordOutcome;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const _UpcomingVisitCard({
    super.key,
    required this.visit,
    required this.onDirections,
    required this.onRecordOutcome,
    this.onCancel,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = visit.staffInitials.isNotEmpty
        ? visit.staffInitials.first
        : (visit.staffNames.trim().isNotEmpty
              ? visit.staffNames
                    .trim()
                    .split(' ')
                    .take(2)
                    .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
                    .join()
              : 'AT');

    final month = visit.monthShort.isNotEmpty ? visit.monthShort : 'Nov';
    final day = visit.dayNumber.isNotEmpty ? visit.dayNumber : '11';

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Badge (Figma Node 1606:1494): #EEEBF6, rounded 12px, 56x56
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEBF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.37,
                        color: const Color(0xFF4A3AFF),
                        height: 15 / 10,
                      ),
                    ),
                    Text(
                      day,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4A3AFF),
                        height: 28 / 20,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // College & Subtitle (Figma Node 1606:1500)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.collegeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.07,
                        color: const Color(0xFF1A1A1A),
                        height: 22.5 / 18,
                      ),
                    ),
                    if (visit.subtitle.isNotEmpty) ...[
                      const Gap(2),
                      Text(
                        visit.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.15,
                          color: const Color(0xFF6B7280),
                          height: 20 / 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(8),

              // Planned Status Pill (Figma Node 1606:1505) & Quick Cancel
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      visit.statusLabel.isNotEmpty ? visit.statusLabel : 'Planned',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B21A8),
                        height: 15 / 10,
                      ),
                    ),
                  ),
                  if (onCancel != null) ...[
                    const Gap(6),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onCancel,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Purpose / Notes (Figma Node 1606:1507)
          if (visit.purpose.isNotEmpty) ...[
            const Gap(12),
            Text(
              visit.purpose,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9CA3AF),
                height: 20 / 14,
              ),
            ),
          ],

          // Assigned Team Row (Figma Node 1606:1509)
          const Gap(12),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A119B),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials.isNotEmpty ? initials : 'AT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.72,
                    height: 15 / 10,
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  visit.staffNames.isNotEmpty
                      ? visit.staffNames
                      : 'Assigned Team',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                    letterSpacing: 0.12,
                    height: 20 / 14,
                  ),
                ),
              ),
            ],
          ),

          // Action Buttons (Figma Node 1606:1514)
          const Gap(16),
          if (visit.statusLabel.toLowerCase() == 'cancelled')
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      CupertinoIcons.trash,
                      size: 14,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: onDirections,
                      icon: const Icon(
                        Icons.navigation_rounded,
                        size: 14,
                        color: Color(0xFF374151),
                      ),
                      label: Text(
                        'Directions',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                          letterSpacing: 0.1,
                          height: 20 / 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
                const Gap(14),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onRecordOutcome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A119B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        'Record Outcome',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                          height: 14 / 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentVisitCard extends StatelessWidget {
  final ExecutiveCollegeVisit visit;
  final VoidCallback? onDirections;
  final VoidCallback? onRecordOutcome;
  final VoidCallback? onDelete;

  const _RecentVisitCard({
    super.key,
    required this.visit,
    this.onDirections,
    this.onRecordOutcome,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreStreamCache.instance.watchCollection('leads'),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? const [];
        final collegeQuery = visit.collegeName.trim().toLowerCase();

        final matchedDocs = allDocs.where((doc) {
          final data = doc.data();
          final leadCollege =
              (data['collegeBranchYear'] ??
                      data['college'] ??
                      data['collegeName'] ??
                      '')
                  .toString()
                  .toLowerCase();
          return collegeQuery.isNotEmpty &&
              (leadCollege.contains(collegeQuery) ||
                  collegeQuery.contains(leadCollege));
        }).toList();

        final matchedInterested = matchedDocs.where((doc) {
          final data = doc.data();
          final outcome = (data['outcome'] ?? data['status'] ?? '')
              .toString()
              .toLowerCase();
          final score = (data['score'] as num?)?.toInt() ?? 0;
          return outcome.contains('interest') ||
              outcome.contains('callback') ||
              score >= 70;
        }).toList();

        final int leads = visit.leadsCollected > 0
            ? visit.leadsCollected
            : (matchedDocs.isNotEmpty ? matchedDocs.length : 0);

        final int interested = visit.interestedCount > 0
            ? visit.interestedCount
            : (matchedInterested.isNotEmpty ? matchedInterested.length : 0);

        final isCancelled = visit.statusLabel.toLowerCase() == 'cancelled';
        final month = visit.monthShort.isNotEmpty ? visit.monthShort : 'NOV';
        final day = visit.dayNumber.isNotEmpty
            ? (visit.dayNumber.length == 1
                  ? '0${visit.dayNumber}'
                  : visit.dayNumber)
            : '04';

        final title = visit.collegeName.isNotEmpty
            ? visit.collegeName
            : 'Campus Visit';
        final subtitle = visit.subtitle.isNotEmpty ? visit.subtitle : '';
        final met = visit.metSummary.isNotEmpty
            ? visit.metSummary
            : (isCancelled
                  ? 'Visit cancelled by executive'
                  : 'Meeting completed with college coordinators.');
        final next = visit.nextActionSummary.isNotEmpty
            ? visit.nextActionSummary
            : (isCancelled
                  ? 'None'
                  : 'Follow up with faculty & registered students.');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Date Badge + Title/Subtitle/Status + Action Buttons (Figma Node 1606:1528)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Badge (Figma Node 1606:1530)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFDCFCE7),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          month,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.37,
                            color: const Color(0xFF166534),
                            height: 15 / 10,
                          ),
                        ),
                        Text(
                          day,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.02,
                            color: const Color(0xFF166534),
                            height: 28 / 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),

                  // Title, Subtitle & Status (Figma Node 1606:1536)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.07,
                            color: const Color(0xFF1A1A1A),
                            height: 22.5 / 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const Gap(2),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Gap(4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCancelled
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                            const Gap(6),
                            Text(
                              isCancelled ? 'CANCELLED' : 'COMPLETED',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.02,
                                color: isCancelled
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669),
                                height: 15 / 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),

                  // Direction & Outcome or Delete Button (Figma Node 1606:1542)
                  if (isCancelled) ...[
                    if (onDelete != null)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(5.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.trash,
                              size: 13,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                  ] else if (onRecordOutcome != null) ...[
                    InkWell(
                      onTap: onRecordOutcome,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              AppSvgs.visitOutcome,
                              width: 12,
                              height: 12,
                            ),
                            const Gap(6),
                            Text(
                              'Outcome',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                                letterSpacing: 0.08,
                                height: 16 / 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Gap(16),

              // Stat Divider Section (Figma Node 1606:1549)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                    bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$leads',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                              height: 24 / 16,
                            ),
                          ),
                          const Gap(6),
                          Text(
                            'LEADS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6B7280),
                              letterSpacing: 0.25,
                              height: 15 / 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 16,
                      color: const Color(0xFFE5E7EB),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$interested',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                              height: 24 / 16,
                            ),
                          ),
                          const Gap(6),
                          Text(
                            'INTERESTED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6B7280),
                              letterSpacing: 0.25,
                              height: 15 / 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Notes Box (Figma Node 1606:1563)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Met: ',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: const Color(0xFF374151),
                            height: 16 / 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            met,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF4B5563),
                              height: 16 / 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next: ',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.25,
                            color: const Color(0xFF374151),
                            height: 16 / 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            next,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF4B5563),
                              height: 16 / 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
      },
    );
  }
}

class _CancelledVisitCard extends StatelessWidget {
  final ExecutiveCollegeVisit visit;
  final VoidCallback onReschedule;
  final VoidCallback onDelete;

  const _CancelledVisitCard({
    super.key,
    required this.visit,
    required this.onReschedule,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = visit.staffInitials.isNotEmpty
        ? visit.staffInitials.first
        : (visit.staffNames.trim().isNotEmpty
            ? visit.staffNames
                .trim()
                .split(' ')
                .take(2)
                .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
                .join()
            : 'AT');

    final month = visit.monthShort.isNotEmpty ? visit.monthShort : 'NOV';
    final day = visit.dayNumber.isNotEmpty
        ? (visit.dayNumber.length == 1 ? '0${visit.dayNumber}' : visit.dayNumber)
        : '04';

    final reason = visit.cancelReason.isNotEmpty
        ? visit.cancelReason
        : (visit.metSummary.isNotEmpty
            ? visit.metSummary
            : 'Visit cancelled by executive');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Red Date Badge + College Name / Subtitle / Status + Delete Button (Figma node 1863:640)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Red/Rose Date Badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFECACA),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.37,
                        color: const Color(0xFFDC2626),
                        height: 15 / 10,
                      ),
                    ),
                    Text(
                      day,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.02,
                        color: const Color(0xFFDC2626),
                        height: 28 / 20,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Title, Subtitle & Cancelled Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.collegeName.isNotEmpty
                          ? visit.collegeName
                          : 'Campus Visit',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.07,
                        color: const Color(0xFF1A1A1A),
                        height: 22.5 / 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (visit.subtitle.isNotEmpty) ...[
                      const Gap(2),
                      Text(
                        visit.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Gap(4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const Gap(6),
                        Text(
                          'CANCELLED',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.02,
                            color: const Color(0xFFDC2626),
                            height: 15 / 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(8),

              // Trash / Delete Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      CupertinoIcons.trash,
                      size: 14,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Cancellation Reason Box (Red/rose or neutral tinted)
          const Gap(14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  size: 16,
                  color: Color(0xFFEA580C),
                ),
                const Gap(8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: 'Reason: ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9A3412),
                      ),
                      children: [
                        TextSpan(
                          text: reason,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Assigned Staff Row
          const Gap(14),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF64748B),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials.isNotEmpty ? initials : 'AT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.72,
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  visit.staffNames.isNotEmpty
                      ? visit.staffNames
                      : 'Assigned Team',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          // Reschedule Action Button
          const Gap(16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onReschedule,
              icon: const Icon(
                Icons.restore_rounded,
                size: 16,
                color: Color(0xFF1E293B),
              ),
              label: Text(
                'Reschedule Visit',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTabItem extends StatelessWidget {
  final String title;
  final int count;
  final Alignment alignment;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisitTabItem({
    required this.title,
    required this.count,
    required this.alignment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.6,
                    height: 17 / 12,
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                  child: Text(title, maxLines: 1),
                ),
                const Gap(5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFF1EB)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFD8CC)
                          : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFD45107)
                          : const Color(0xFF64748B),
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

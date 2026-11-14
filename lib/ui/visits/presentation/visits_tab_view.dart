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
  double _scrollProgress = 0.0;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      final offset = notification.metrics.pixels;
      final progress = (offset / 24.0).clamp(0.0, 1.0);
      if (progress != _scrollProgress) {
        setState(() => _scrollProgress = progress);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisitsCubit, VisitsState>(
      builder: (context, state) {
        final pad = context.devicePadding;
        final upcoming = state.upcomingVisits;
        final recent = state.recentVisits;
        final isEmptyState = upcoming.isEmpty && recent.isEmpty;

        return Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top White Header (Matches Figma node 1606:1480)
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                  pad.clamp(16.0, 24.0),
                  MediaQuery.paddingOf(context).top > 0
                      ? MediaQuery.paddingOf(context).top + 16
                      : 24,
                  pad.clamp(16.0, 24.0),
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'College visits',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.6,
                            height: 32 / 24,
                          ),
                        ),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () => _showLogVisitModal(context),
                            icon: const Icon(Icons.add, size: 14, color: Colors.white),
                            label: Text(
                              'Log visit',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.11,
                                height: 20 / 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE64A19),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: const Color(0x0D000000),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Body Content (Scrollable with RefreshIndicator and Ambient Shade)
              Expanded(
                child: Container(
                  color: const Color(0xFFF8F9FA),
                  child: Stack(
                    children: [
                      RefreshIndicator.adaptive(
                        color: const Color(0xFF4338CA),
                        backgroundColor: Colors.white,
                        displacement: 20,
                        onRefresh: () async {
                          context.read<VisitsCubit>().refresh();
                          await Future.delayed(
                            const Duration(milliseconds: 1000),
                          );
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _handleScroll,
                          child: SingleChildScrollView(
                            physics: isEmptyState
                                ? const AlwaysScrollableScrollPhysics(
                                    parent: ClampingScrollPhysics(),
                                  )
                                : const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                            padding: EdgeInsets.fromLTRB(
                              pad.clamp(16.0, 24.0),
                              16,
                              pad.clamp(16.0, 24.0),
                              32,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                        if (upcoming.isEmpty && recent.isEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 36,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
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
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    CupertinoIcons.calendar_today,
                                    color: Color(0xFF94A3B8),
                                    size: 24,
                                  ),
                                ),
                                const Gap(16),
                                const Text(
                                  'No planned visits',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const Gap(6),
                                const Text(
                                  'You have no college campus visits scheduled right now.\nTap "Log visit" above to schedule a new visit.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // UPCOMING · ASSIGNED TO YOU (Figma node 1606:1489)
                          Text(
                            'UPCOMING · ASSIGNED TO YOU',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: const Color(0xFF6B7280),
                              height: 16.5 / 11,
                            ),
                          ),
                          const Gap(10),
                          if (upcoming.isEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                  width: 1.2,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.calendar_badge_minus,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  Gap(8),
                                  Text(
                                    'No planned visits scheduled',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...upcoming.map(
                              (visit) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _UpcomingVisitCard(
                                  visit: visit,
                                  onDirections: () =>
                                      _handleDirections(context, visit),
                                  onRecordOutcome: () =>
                                      _showRecordOutcomeSheet(context, visit),
                                  onDelete: () =>
                                      _confirmDeleteVisit(context, visit),
                                ),
                              ),
                            ),
                          const Gap(10),

                          // RECENT (Figma node 1606:1525)
                          Text(
                            'RECENT',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: const Color(0xFF6B7280),
                              height: 16.5 / 11,
                            ),
                          ),
                          const Gap(10),
                          if (recent.isEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                  width: 1.2,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.clock,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  Gap(8),
                                  Text(
                                    'No past visits recorded yet',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...recent.map(
                              (visit) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _RecentVisitCard(
                                  visit: visit,
                                  onDirections: () =>
                                      _handleDirections(context, visit),
                                  onRecordOutcome: () =>
                                      _showRecordOutcomeSheet(context, visit),
                                  onDelete: () =>
                                      _confirmDeleteVisit(context, visit),
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
      ),
    ],
  ),
);
},
);
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
  final VoidCallback? onDelete;

  const _UpcomingVisitCard({
    required this.visit,
    required this.onDirections,
    required this.onRecordOutcome,
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

              // Planned Status Pill (Figma Node 1606:1505)
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

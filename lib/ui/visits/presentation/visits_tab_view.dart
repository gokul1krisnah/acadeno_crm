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
import 'package:acadeno_crm/ui/visits/application/visits_cubit.dart';
import 'package:acadeno_crm/ui/visits/application/visits_state.dart';
import 'package:acadeno_crm/ui/visits/data/model/visit_models.dart';

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
              // Top White Header (Always anchored at top)
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFEAECF0)),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'College visits',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogVisitModal(context),
                        icon: const Icon(Icons.add, size: 17),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Log visit',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD95D24),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body Content (Scrollable with RefreshIndicator and Ambient Shade)
              Expanded(
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
                          padding: EdgeInsets.fromLTRB(pad, 18, pad, 24),
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
                          // UPCOMING · ASSIGNED TO YOU
                          const Text(
                            'UPCOMING · ASSIGNED TO YOU',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                              color: Color(0xFF667085),
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

                          // RECENT
                          const Text(
                            'RECENT',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                              color: Color(0xFF667085),
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
                          final picked = await showDatePicker(
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
        ? visit.staffInitials
        : (visit.staffNames.trim().isNotEmpty
              ? [
                  visit.staffNames
                      .trim()
                      .split(' ')
                      .firstWhere(
                        (s) => s.isNotEmpty,
                        orElse: () => 'E',
                      )[0]
                      .toUpperCase(),
                ]
              : const ['EX']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Badge (OCT / 29)
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEDFD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      visit.monthShort,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                    const Gap(1),
                    Text(
                      visit.dayNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF312E81),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),

              // College & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.collegeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Gap(2),
                    Text(
                      visit.subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF667085),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),

              // Planned Status Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEDFD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  visit.statusLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3730A3),
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),

          // Purpose
          Text(
            visit.purpose,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF344054),
              height: 1.35,
            ),
          ),
          const Gap(12),

          // Overlapping Avatars (AR + RM) + Names
          Row(
            children: [
              SizedBox(
                width: initials.length > 1 ? 50 : 28,
                height: 28,
                child: Stack(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4338CA),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials.isNotEmpty ? initials.first : 'EX',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (initials.length > 1)
                      Positioned(
                        left: 20,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials[1],
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  visit.staffNames.isNotEmpty
                      ? visit.staffNames
                      : 'Assigned Staff',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475467),
                  ),
                ),
              ),
            ],
          ),
          const Gap(14),

          // Action Buttons Row: Delete if Cancelled, otherwise Directions | Record outcome
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
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: onDirections,
                      icon: const Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: Color(0xFF0F172A),
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Directions',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD0D5DD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: onRecordOutcome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4338CA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Record outcome',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
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
      stream: FirebaseFirestore.instance.collection('leads').snapshots(),
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
        final isCompleted =
            visit.statusLabel.toLowerCase().contains('complete') ||
            visit.statusLabel.toLowerCase() == 'done';
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

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 377, minHeight: 263.19),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Date Badge + Title/Subtitle/Status + Action Buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Badge
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFBBF7D0),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            month,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const Gap(1),
                          Text(
                            day,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(14),

                    // Title, Subtitle & Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const Gap(3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const Gap(5),
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
                                      : const Color(0xFF047857),
                                ),
                              ),
                              const Gap(6),
                              Text(
                                isCancelled ? 'CANCELLED' : 'COMPLETED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: isCancelled
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),

                    // Direction & Outcome or Delete Button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                        ] else if (isCompleted) ...[
                          if (onRecordOutcome != null)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onRecordOutcome,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        size: 14,
                                        color: Color(0xFF334155),
                                      ),
                                      Gap(4),
                                      Text(
                                        'Outcome',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ] else ...[
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap:
                                  onDirections ??
                                  () =>
                                      LinkLauncher.launchCollegeMapsDirections(
                                        visit.collegeName,
                                        locationHint: visit.subtitle,
                                      ),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_rounded,
                                      size: 14,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    Gap(4),
                                    Text(
                                      'Direction',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (onRecordOutcome != null) ...[
                            const Gap(6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onRecordOutcome,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        size: 14,
                                        color: Color(0xFF334155),
                                      ),
                                      Gap(3),
                                      Text(
                                        'Outcome',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
                const Gap(16),

                // Middle Box: Actual Real Data $leads LEADS | $interested INTERESTED
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$leads',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Gap(6),
                                const Text(
                                  'LEADS',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 18,
                        color: const Color(0xFFE2E8F0),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$interested',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Gap(6),
                                const Text(
                                  'INTERESTED',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
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
                const Gap(16),

                // Bottom Met Box (Exact Figma Spec)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 80.19),
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0x80FFF7ED), // #FFF7ED80
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFF7ED),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.3,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Met: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(text: met),
                          ],
                        ),
                      ),
                      const Gap(6),
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.3,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Next: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(text: next),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

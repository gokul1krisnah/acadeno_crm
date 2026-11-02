import 'package:acadeno_crm/shared/utilities/link_launcher.dart';
import 'package:acadeno_crm/shared/widgets/college_selector_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/ui/visits/application/visits_cubit.dart';
import 'package:acadeno_crm/ui/visits/application/visits_state.dart';
import 'package:acadeno_crm/ui/visits/data/model/visit_models.dart';

class VisitsTabView extends StatelessWidget {
  const VisitsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisitsCubit, VisitsState>(
      builder: (context, state) {
        final pad = context.devicePadding;
        final upcoming = state.upcomingVisits;
        final recent = state.recentVisits;

        return RefreshIndicator(
          color: const Color(0xFF4338CA),
          backgroundColor: Colors.white,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top White Header
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
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: () => _showLogVisitModal(context),
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text(
                            'Log visit',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD95D24),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body Content
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 18, pad, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // UPCOMING · ASSIGNED TO YOU
                      const Text(
                        'UPCOMING · ASSIGNED TO YOU',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...upcoming.map(
                        (visit) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _UpcomingVisitCard(
                            visit: visit,
                            onDirections: () =>
                                _handleDirections(context, visit),
                            onRecordOutcome: () =>
                                _showRecordOutcomeSheet(context, visit),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // RECENT
                      const Text(
                        'RECENT',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...recent.map(
                        (visit) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RecentVisitCard(visit: visit),
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
            const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
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
        backgroundColor: Colors.white,
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
                    const SizedBox(width: 12),
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
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEAECF0)),
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
                          const SizedBox(width: 6),
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
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
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
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
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
                const SizedBox(height: 18),
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
                    const SizedBox(width: 10),
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

  void _showRecordOutcomeSheet(
    BuildContext context,
    ExecutiveCollegeVisit visit,
  ) {
    final cubit = context.read<VisitsCubit>();
    final metCtrl = TextEditingController(text: 'HOD CSE, Placement officer');
    final nextCtrl = TextEditingController(
      text: 'Share workshop registration QR by Friday',
    );
    final leadsCtrl = TextEditingController(text: '54');
    final interestedCtrl = TextEditingController(text: '14');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ctx.devicePadding.clamp(16.0, 24.0),
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: EdgeInsets.all(ctx.devicePadding.clamp(16.0, 20.0)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record Visit Outcome · ${visit.collegeName} (FR-8.2)',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: metCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          'People met (HOD / Placement officer / Faculty)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: leadsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Leads collected (FR-8.3)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: interestedCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Interested so far',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nextCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Next action & follow-up date',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        cubit.recordVisitOutcome(
                          visitId: visit.id,
                          metPeople: metCtrl.text.trim(),
                          nextAction: nextCtrl.text.trim(),
                          leadsCollected:
                              int.tryParse(leadsCtrl.text.trim()) ?? 0,
                          interestedCount:
                              int.tryParse(interestedCtrl.text.trim()) ?? 0,
                        );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4338CA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Visit Outcome',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
  }

  void _showLogVisitModal(BuildContext context) {
    final cubit = context.read<VisitsCubit>();
    final collegeCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '04');
    final monthCtrl = TextEditingController(text: 'NOV');
    final subCtrl = TextEditingController(
      text: 'Wed · 10:30 AM · IT department',
    );
    final purposeCtrl = TextEditingController(
      text: 'Promote Python & Data Science workshop · meet HOD',
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ctx.devicePadding.clamp(16.0, 24.0),
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: EdgeInsets.all(ctx.devicePadding.clamp(16.0, 20.0)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log / Plan College Visit (FR-8.1)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: collegeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'College Name *',
                      hintText: 'e.g. MES College Kuttippuram',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: monthCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Month (e.g. NOV)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: dayCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Day (e.g. 04)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Time & Department',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: purposeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Visit Purpose',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (collegeCtrl.text.trim().isEmpty) return;
                        CollegeSelectorField.saveCollegeIfNew(
                          collegeCtrl.text.trim(),
                        );
                        cubit.addCollegeVisit(
                          collegeName: collegeCtrl.text.trim(),
                          dayNumber: dayCtrl.text.trim(),
                          monthShort: monthCtrl.text.trim(),
                          subtitle: subCtrl.text.trim(),
                          purpose: purposeCtrl.text.trim(),
                        );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD95D24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add Visit',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
  }
}

class _UpcomingVisitCard extends StatelessWidget {
  final ExecutiveCollegeVisit visit;
  final VoidCallback onDirections;
  final VoidCallback onRecordOutcome;

  const _UpcomingVisitCard({
    required this.visit,
    required this.onDirections,
    required this.onRecordOutcome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0)),
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
                    const SizedBox(height: 1),
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
              const SizedBox(width: 12),

              // College & Subtitle
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
                    const SizedBox(height: 2),
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
              const SizedBox(width: 8),

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
          const SizedBox(height: 12),

          // Purpose
          Text(
            visit.purpose,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF344054),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Overlapping Avatars (AR + RM) + Names
          Row(
            children: [
              SizedBox(
                width: visit.staffInitials.length > 1 ? 50 : 28,
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
                        visit.staffInitials.first,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (visit.staffInitials.length > 1)
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
                            visit.staffInitials[1],
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visit.staffNames,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475467),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons Row: Directions | Record outcome
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
                    label: const Text(
                      'Directions',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
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
              const SizedBox(width: 10),
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
                    child: const Text(
                      'Record outcome',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
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

  const _RecentVisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final isCompleted = visit.statusLabel == 'Completed';
    final dateBg = isCompleted
        ? const Color(0xFFE6F4EA)
        : const Color(0xFFF2F4F7);
    final dateFg = isCompleted
        ? const Color(0xFF15803D)
        : const Color(0xFF344054);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Box
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: dateBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      visit.monthShort,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: dateFg,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      visit.dayNumber,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: dateFg,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // College & Subtitle
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
                    const SizedBox(height: 2),
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
              const SizedBox(width: 8),

              // Status Badge & Directions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dateBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      visit.statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: dateFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => LinkLauncher.launchCollegeMapsDirections(
                      visit.collegeName,
                      locationHint: visit.subtitle,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_outlined,
                            size: 14,
                            color: Color(0xFF4338CA),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Directions',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (isCompleted) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${visit.leadsCollected}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Leads collected',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${visit.interestedCount}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Interested so far',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF344054),
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text: 'Met: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextSpan(text: '${visit.metSummary} · '),
                  const TextSpan(
                    text: 'Next: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextSpan(text: visit.nextActionSummary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

        return Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: RefreshIndicator.adaptive(
            color: const Color(0xFF4338CA),
            backgroundColor: Colors.white,
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 2));
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
                              onDelete: () =>
                                  _confirmDeleteVisit(context, visit),
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
                    ),
                  ),
                ],
              ),
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
            const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
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

  Future<void> _confirmDeleteVisit(
    BuildContext context,
    ExecutiveCollegeVisit visit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
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
    final metCtrl = TextEditingController(text: visit.metSummary);
    final nextCtrl = TextEditingController(text: visit.nextActionSummary);
    final leadsCtrl = TextEditingController(
      text: visit.leadsCollected > 0 ? '${visit.leadsCollected}' : '',
    );
    final interestedCtrl = TextEditingController(
      text: visit.interestedCount > 0 ? '${visit.interestedCount}' : '',
    );
    bool isCancelled = visit.statusLabel == 'Cancelled';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(
            horizontal: ctx.devicePadding.clamp(16.0, 24.0),
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                      'Record Visit Outcome · ${visit.collegeName}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tick option for Cancelled / Not Completed
                    Container(
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCancelled
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: CheckboxListTile(
                        dense: true,
                        value: isCancelled,
                        activeColor: const Color(0xFFDC2626),
                        checkColor: Colors.white,
                        title: Text(
                          isCancelled
                              ? 'Not Completed · Cancelled'
                              : 'Visit Completed Successfully',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isCancelled
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                          ),
                        ),
                        subtitle: Text(
                          isCancelled
                              ? 'Tick to log this visit as not completed / cancelled'
                              : 'Tick if this visit was cancelled or could not be conducted',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isCancelled
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF15803D),
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            isCancelled = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: metCtrl,
                      decoration: InputDecoration(
                        labelText: isCancelled
                            ? 'Cancellation reason & notes'
                            : 'People met (HOD / Placement officer / Faculty)',
                        hintText: isCancelled
                            ? 'Why was the visit cancelled? e.g. Principal unavailable'
                            : 'e.g. Met HOD CSE, agreed to 2-day workshop',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (!isCancelled) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: leadsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Leads collected',
                                hintText: '0',
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
                                labelText: 'Interested students',
                                hintText: '0',
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
                          labelText: 'Next action & follow-up',
                          hintText: 'e.g. Share registration details on Monday',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              if (isCancelled) {
                                cubit.cancelCollegeVisit(
                                  visitId: visit.id,
                                  reason: metCtrl.text.trim().isNotEmpty
                                      ? metCtrl.text.trim()
                                      : 'Visit cancelled by executive',
                                );
                              } else {
                                cubit.recordVisitOutcome(
                                  visitId: visit.id,
                                  metPeople: metCtrl.text.trim(),
                                  nextAction: nextCtrl.text.trim(),
                                  leadsCollected:
                                      int.tryParse(leadsCtrl.text.trim()) ?? 0,
                                  interestedCount:
                                      int.tryParse(
                                        interestedCtrl.text.trim(),
                                      ) ??
                                      0,
                                );
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCancelled
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isCancelled
                                  ? 'Save as Cancelled'
                                  : 'Mark Completed',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  void _showLogVisitModal(BuildContext context) {
    final cubit = context.read<VisitsCubit>();
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
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Plan College Visit',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Schedule campus seminar, workshop, or student drive',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
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
                    const SizedBox(height: 18),
                    TextField(
                      controller: collegeCtrl,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'College Name *',
                        hintText: 'e.g. Kannur University',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(
                          Icons.account_balance_outlined,
                          size: 19,
                          color: Color(0xFF64748B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF4338CA),
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                        child: TextField(
                          controller: dateCtrl,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Visit Date *',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon: const Icon(
                              Icons.calendar_today_rounded,
                              size: 19,
                              color: Color(0xFF64748B),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF4338CA),
                                width: 1.5,
                              ),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: subCtrl,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Department / Location',
                        hintText: 'e.g. MCA Dept · 10:30 AM',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(
                          Icons.place_outlined,
                          size: 19,
                          color: Color(0xFF64748B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF4338CA),
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: purposeCtrl,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Visit Purpose',
                        hintText: 'e.g. Seminar + student drive',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(
                          Icons.assignment_outlined,
                          size: 19,
                          color: Color(0xFF64748B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF4338CA),
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (collegeCtrl.text.trim().isEmpty) return;
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
                          backgroundColor: const Color(0xFF4338CA),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save College Visit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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

          // Action Buttons Row: Delete if Cancelled, otherwise Directions | Record outcome
          if (visit.statusLabel.toLowerCase() == 'cancelled')
            SizedBox(
              height: 42,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: Color(0xFFDC2626),
                ),
                label: const Text(
                  'Delete visit',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
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
                          const SizedBox(height: 1),
                          Text(
                            day,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF166534),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title, Subtitle & Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
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
                          const SizedBox(height: 5),
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
                              const SizedBox(width: 6),
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
                    const SizedBox(width: 8),

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
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 14,
                                        color: Color(0xFFDC2626),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
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
                                      SizedBox(width: 4),
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
                                    SizedBox(width: 4),
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
                            const SizedBox(height: 6),
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
                                      SizedBox(width: 3),
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
                const SizedBox(height: 16),

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
                                const SizedBox(width: 6),
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
                                const SizedBox(width: 6),
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
                const SizedBox(height: 16),

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
                      const SizedBox(height: 6),
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

import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:acadeno_crm/shared/theme/app_typography.dart';
import 'package:acadeno_crm/shared/widgets/college_selector_field.dart';
import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';
import 'package:acadeno_crm/ui/leads/application/admin_leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/admin_leads_state.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';
import 'package:acadeno_crm/ui/leads/data/repository/leads_repo.dart';
import 'package:acadeno_crm/ui/leads/data/sources/leads_rds.dart';
import 'package:acadeno_crm/ui/leads/data/sources/lead_export_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/dashboard_cubit.dart';

const _primary = Color(0xFFEF8144);
const _border = Color(0xFFE5E7EB);
const _muted = Color(0xFF6B7280);
const _text = Color(0xFF111827);

class LeadsAssignView extends StatelessWidget {
  final AdminLeadsCubit? cubit;

  const LeadsAssignView({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    final existingCubit = cubit ?? _tryReadAdminLeadsCubit(context);
    if (existingCubit != null) {
      return BlocProvider<AdminLeadsCubit>.value(
        value: existingCubit,
        child: const _LeadsAssignBody(),
      );
    }
    return BlocProvider<AdminLeadsCubit>(
      create: (_) => AdminLeadsCubit(LeadsRepository(LeadsRds())),
      child: const _LeadsAssignBody(),
    );
  }

  static AdminLeadsCubit? _tryReadAdminLeadsCubit(BuildContext context) {
    try {
      return context.read<AdminLeadsCubit>();
    } catch (_) {
      return null;
    }
  }
}

class _LeadsAssignBody extends StatefulWidget {
  const _LeadsAssignBody();

  @override
  State<_LeadsAssignBody> createState() => _LeadsAssignBodyState();
}

class _LeadsAssignBodyState extends State<_LeadsAssignBody> {
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  DashboardCubit? _tryDashboardCubit() {
    try {
      return context.read<DashboardCubit>();
    } catch (_) {
      return null;
    }
  }

  void _openReviewAssignmentDialog(
    BuildContext context,
    AdminLeadsState state,
  ) {
    final cubit = context.read<AdminLeadsCubit>();
    final selectedLeads = state.selectedLeadRecords;
    final exec = state.selectedExecutive;
    if (selectedLeads.isEmpty || exec == null) return;

    final conflicts = state.conflictingSelectedLeads;
    bool confirmReassign = conflicts.isNotEmpty;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: dCtx.devicePadding,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Review & Confirm Assignment',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HR: ${exec.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _text,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          'Assignment Date: ${state.selectedDateLabel} (${state.selectedDateKey})',
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                        const Gap(4),
                        Text(
                          'Leads Selected: ${selectedLeads.length}',
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  const Text(
                    'SELECTED LEADS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Gap(6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SingleChildScrollView(
                      child: Column(
                        children: selectedLeads
                            .map(
                              (l) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${l.name} (${l.phone})',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _text,
                                        ),
                                      ),
                                    ),
                                    if (l.isAssigned)
                                      Text(
                                        'Currently: ${l.assignedToName}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB45309),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  if (conflicts.isNotEmpty) ...[
                    const Gap(12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${conflicts.length} selected ${conflicts.length == 1 ? "lead is" : "leads are"} already assigned for ${state.selectedDateLabel}.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const Gap(4),
                          Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              value: confirmReassign,
                              onChanged: (v) =>
                                  setD(() => confirmReassign = v ?? false),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: _primary,
                              title: const Text(
                                'Reassign these leads to the selected HR',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _text,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dCtx);
                final summary = await cubit.assignSelectedLeads(
                  allowReassign: confirmReassign,
                );
                if (summary != null) {
                  _tryDashboardCubit()?.recordAudit(
                    action:
                        'Assigned ${summary.totalCount} leads to ${summary.executiveName} for ${summary.dateLabel}',
                    target: summary.assignments
                        .map((e) => e.leadName)
                        .join(', '),
                    category: 'assignment',
                  );
                }
              },
              child: const Text('Confirm Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddLeadDialog(BuildContext context, AdminLeadsState state) {
    final cubit = context.read<AdminLeadsCubit>();
    final formKey = GlobalKey<FormState>();
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final collegeC = TextEditingController(text: 'NIT Calicut · CSE · 3');
    final notesC = TextEditingController();
    String source = 'Direct visit';
    String? backendError;
    bool saving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone Lookup & Add Walk-in Lead',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          height: 27.5 / 20,
                          letterSpacing: 0,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Gap(6),
                      Text(
                        'Type a 10-digit phone number to check duplicates before saving.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 21.13 / 13,
                          letterSpacing: 0,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const Gap(18),
                      if (backendError != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Color(0xFFDC2626),
                              ),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  backendError!,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF991B1B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: phoneC,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 21.13 / 13,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: '10-digit mobile nu...',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                            height: 21.13 / 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
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
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: LeadPhoneValidator.validate,
                      ),
                      const Gap(14),
                      TextFormField(
                        controller: nameC,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Student Name *',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
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
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const Gap(14),
                      Text(
                        'College · Branch · Year',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const Gap(6),
                      TextFormField(
                        controller: collegeC,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(
                            Icons.notes_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
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
                        ),
                      ),
                      const Gap(14),
                      Text(
                        'Source Event / Consent',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const Gap(6),
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: source,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF64748B),
                              size: 22,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF0F172A),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Direct visit',
                                child: Text('Direct visit'),
                              ),
                              DropdownMenuItem(
                                value: 'AI Webinar',
                                child: Text('AI Webinar'),
                              ),
                              DropdownMenuItem(
                                value: 'Python workshop',
                                child: Text('Python workshop'),
                              ),
                              DropdownMenuItem(
                                value: 'College visit',
                                child: Text('College visit'),
                              ),
                              DropdownMenuItem(
                                value: 'Add-on course',
                                child: Text('Add-on course'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setD(() => source = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const Gap(20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(dCtx),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF475467),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
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
                                onPressed: saving
                                    ? null
                                    : () async {
                                        setD(() => backendError = null);
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }
                                        setD(() => saving = true);
                                        try {
                                          await CollegeSelectorField.saveCollegeIfNew(
                                            collegeC.text,
                                          );
                                          final created = await cubit
                                              .createLead(
                                                name: nameC.text.trim(),
                                                phone: phoneC.text.trim(),
                                                collegeBranch: collegeC.text
                                                    .trim(),
                                                source: source,
                                                notes: notesC.text.trim(),
                                              );
                                          if (!dCtx.mounted) return;
                                          Navigator.pop(dCtx);
                                          if (created != null) {
                                            _tryDashboardCubit()?.recordAudit(
                                              action:
                                                  'Added walk-in lead ($source)',
                                              target:
                                                  '${created.name} · ${created.phone}',
                                              category: 'lead_create',
                                            );
                                          }
                                        } catch (e) {
                                          if (!dCtx.mounted) return;
                                          setD(() {
                                            saving = false;
                                            backendError = e
                                                .toString()
                                                .replaceFirst('Exception: ', '')
                                                .replaceFirst(
                                                  'Invalid argument(s): ',
                                                  '',
                                                );
                                          });
                                        }
                                      },
                                child: Text(
                                  'Save Walk-in Lead',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
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
          ),
        ),
      ),
    );
  }

  void _openLeadDetailAndEditDialog(
    BuildContext context,
    LeadRecord lead,
    AdminLeadsState state,
  ) {
    final cubit = context.read<AdminLeadsCubit>();
    final formKey = GlobalKey<FormState>();
    final nameC = TextEditingController(text: lead.name);
    final phoneC = TextEditingController(text: lead.phone);
    final collegeC = TextEditingController(text: lead.collegeBranch);
    final notesC = TextEditingController(text: lead.notes);

    final statusOptions = <String>{
      'New',
      'Assigned',
      'Follow-up',
      'No answer',
      'Interested',
      'Not interested',
      'Converted',
      lead.status,
    }.toList();
    final sourceOptions = <String>{
      'Direct visit',
      'AI Webinar',
      'Python workshop',
      'Industrial visit',
      'Add-on course',
      'College visit',
      'Workshop',
      lead.source,
    }.toList();

    String selectedStatus = lead.status;
    String selectedSource = lead.source;
    String? errorText;
    bool saving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Lead Details · ${lead.name}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 18.5,
                                height: 26 / 18.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const Gap(8),
                          _statusBadge(selectedStatus),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        'View and update lead contact details, stage, and history.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const Gap(16),
                      if (errorText != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Color(0xFFDC2626),
                              ),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  errorText!,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF991B1B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lead ID: ${lead.id}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const Gap(2),
                            Text(
                              'Assigned To: ${lead.assignedToName}${lead.dynamicAssignedDateLabel != null ? " (${lead.dynamicAssignedDateLabel})" : ""}',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (lead.assignedByName != null &&
                                lead.assignedByName!.isNotEmpty) ...[
                              const Gap(1),
                              Text(
                                'Assigned By: ${lead.assignedByName}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Gap(14),
                      Text(
                        'Student Name *',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const Gap(6),
                      TextFormField(
                        controller: nameC,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Student Name *',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
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
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const Gap(14),
                      Text(
                        '10-digit Phone Number *',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const Gap(6),
                      TextFormField(
                        controller: phoneC,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: '10-digit mobile number...',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
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
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: LeadPhoneValidator.validate,
                      ),
                      const Gap(14),
                      CollegeSelectorField(
                        controller: collegeC,
                        additionalColleges: state.allLeads
                            .map(
                              (l) => l.collegeBranch
                                  .split(RegExp(r'[·\-]'))
                                  .first
                                  .trim(),
                            )
                            .where((s) => s.isNotEmpty)
                            .toList(),
                      ),
                      const Gap(14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Source',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                const Gap(6),
                                Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedSource,
                                      isExpanded: true,
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF64748B),
                                        size: 22,
                                      ),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      items: sourceOptions
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(
                                                s,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setD(() => selectedSource = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                const Gap(6),
                                Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedStatus,
                                      isExpanded: true,
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF64748B),
                                        size: 22,
                                      ),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      items: statusOptions
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(
                                                s,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setD(() => selectedStatus = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(14),
                      Text(
                        'Notes',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const Gap(6),
                      TextFormField(
                        controller: notesC,
                        maxLines: 2,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add internal notes or context...',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          isDense: true,
                          contentPadding: const EdgeInsets.all(14),
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
                        ),
                      ),
                      if (lead.timeline.isNotEmpty) ...[
                        const Gap(14),
                        Text(
                          'TIMELINE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const Gap(6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: lead.timeline
                                .take(4)
                                .map(
                                  (t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            LeadDateHelper.formatTimelineEntry(
                                              t,
                                            ),
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: const Color(0xFF475467),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const Gap(20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(dCtx),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF475467),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD45107),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: saving
                                    ? null
                                    : () async {
                                        setD(() => errorText = null);
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }
                                        setD(() => saving = true);
                                        try {
                                          await CollegeSelectorField.saveCollegeIfNew(
                                            collegeC.text,
                                          );
                                          await cubit.updateLead(
                                            leadId: lead.id,
                                            name: nameC.text.trim(),
                                            phone: phoneC.text.trim(),
                                            collegeBranch: collegeC.text.trim(),
                                            source: selectedSource,
                                            status: selectedStatus,
                                            notes: notesC.text.trim(),
                                          );
                                          if (!dCtx.mounted) return;
                                          Navigator.pop(dCtx);
                                        } catch (e) {
                                          if (!dCtx.mounted) return;
                                          setD(() {
                                            saving = false;
                                            errorText = e
                                                .toString()
                                                .replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                );
                                          });
                                        }
                                      },
                                child: saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Save changes',
                                        style: GoogleFonts.inter(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
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
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final s = status.trim().toLowerCase();
    final (Color bg, Color fg, Border? border) = switch (s) {
      'contacted' || 'interested' => (
        const Color(0xFFF0FDF4),
        const Color(0xFF166534),
        Border.all(color: const Color(0xFFDCFCE7), width: 1),
      ),
      'assigned' => (
        const Color(0xFFEEF2FF),
        const Color(0xFF4F46E5),
        null,
      ),
      'follow-up' || 'followup' => (
        const Color(0xFFFFF7ED),
        const Color(0xFFEA580C),
        Border.all(color: const Color(0xFFFFEDD5), width: 1),
      ),
      'overdue' => (
        const Color(0xFFFFF7ED),
        const Color(0xFFEA580C),
        Border.all(color: const Color(0xFFFFEDD5), width: 1),
      ),
      'not interested' => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
        Border.all(color: const Color(0xFFFECACA), width: 1),
      ),
      'converted' => (
        const Color(0xFFF0FDF4),
        const Color(0xFF166534),
        Border.all(color: const Color(0xFFDCFCE7), width: 1),
      ),
      'new' => (
        const Color(0xFFF3F4F6),
        const Color(0xFF4B5563),
        null,
      ),
      _ => (
        const Color(0xFFF3F4F6),
        const Color(0xFF4B5563),
        null,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: border,
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: GoogleFonts.poppins(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 16.5 / 11,
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    final safeItems = items.contains(value) ? items : [value, ...items];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
            letterSpacing: 0.3,
            height: 16 / 12,
          ),
        ),
        const Gap(8),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          alignment: Alignment.center,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(8),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
                height: 20 / 14,
              ),
              items: safeItems
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminLeadsCubit, AdminLeadsState>(
      listener: (context, state) {
        if (state.toastMessage != null) {
          SnackBarAlert.showToast(
            context: context,
            message: state.toastMessage!,
            isWarning: state.isToastError,
          );
          context.read<AdminLeadsCubit>().clearToast();
        }
      },
      builder: (context, state) {
        final cubit = context.read<AdminLeadsCubit>();
        final rows = state.paginatedLeads;
        final allSelectedOnPage =
            rows.isNotEmpty &&
            rows.every((r) => state.selectedLeadIds.contains(r.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header - Rigorously aligned to the far right top
            LayoutBuilder(
              builder: (context, c) {
                final isNarrow =
                    MediaQuery.of(context).size.width < 960 || c.maxWidth < 900;
                final titleCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leads',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2051,
                        height: 36 / 30,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      '${state.allLeads.length} leads · filter, select and assign to HR for a day',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.0684,
                        height: 20 / 14,
                      ),
                    ),
                  ],
                );

                final actionButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1A1A),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          elevation: 0,
                        ),
                        onPressed: cubit.refresh,
                        icon: const Icon(
                          CupertinoIcons.refresh,
                          size: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                        label: Text(
                          'Refresh',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: 0.041,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1A1A),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _tryDashboardCubit()?.selectNav(5),
                        icon: const Icon(
                          Icons.upload_file_rounded,
                          size: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                        label: Text(
                          'Import Leads',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: 0.0684,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1A1A),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final leadsToExport = state.filteredLeads;
                          if (leadsToExport.isEmpty) {
                            SnackBarAlert.showToast(
                              context: context,
                              message:
                                  'No leads found to export with the current filters.',
                              isWarning: true,
                            );
                            return;
                          }
                          final success = await LeadExportHelper.exportLeads(
                            leads: leadsToExport,
                          );
                          if (context.mounted) {
                            SnackBarAlert.showToast(
                              context: context,
                              message: success
                                  ? 'Successfully exported leads to CSV!'
                                  : 'Export copied to clipboard',
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.download_rounded,
                          size: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                        label: Text(
                          'Export (${state.filteredLeads.isNotEmpty ? state.filteredLeads.length : ""})',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: 0.0273,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF8144),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => _openAddLeadDialog(context, state),
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: Text(
                          'Add lead',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.1641,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleCol,
                      const Gap(12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: actionButtons,
                      ),
                    ],
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: titleCol),
                      const Gap(16),
                      actionButtons,
                    ],
                  ),
                );
              },
            ),
            const Gap(24),

            // Filter Bar Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final searchField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEARCH',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                          letterSpacing: 0.3,
                          height: 16 / 12,
                        ),
                      ),
                      const Gap(8),
                      SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchC,
                          onChanged: cubit.setSearchQuery,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF111827),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Name, phone or college',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9CA3AF),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFEF8144),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );

                  final fSource = _filterDropdown(
                    label: 'Source',
                    value: state.sourceFilter,
                    items: const [
                      'All sources',
                      'Direct visit',
                      'AI Webinar',
                      'Python workshop',
                      'Industrial visit',
                      'Add-on course',
                      'College visit',
                      'Workshop',
                    ],
                    onChanged: cubit.setSourceFilter,
                  );
                  final fCollege = _filterDropdown(
                    label: 'College',
                    value: state.collegeFilter,
                    items: const [
                      'All colleges',
                      'KMCT',
                      'MES College',
                      'NIT Calicut',
                      'GEC Kozhikode',
                      'Farook College',
                      'Providence',
                    ],
                    onChanged: cubit.setCollegeFilter,
                  );
                  final fBranch = _filterDropdown(
                    label: 'Branch',
                    value: state.branchFilter,
                    items: const [
                      'All branches',
                      'CSE, ECE',
                      'CSE',
                      'ECE',
                      'MECH',
                      'BCA',
                      'BSc CS',
                      'EEE',
                      'IT',
                    ],
                    onChanged: cubit.setBranchFilter,
                  );
                  final fYear = _filterDropdown(
                    label: 'Year',
                    value: state.yearFilter,
                    items: const [
                      'Any year',
                      '1st yr',
                      '2nd yr',
                      '3rd yr',
                      '4th yr',
                    ],
                    onChanged: cubit.setYearFilter,
                  );
                  final fStatus = _filterDropdown(
                    label: 'Status',
                    value: state.statusFilter,
                    items: const [
                      'All statuses',
                      'New, No answer',
                      'New',
                      'Assigned',
                      'Follow-up',
                      'No answer',
                      'Interested',
                      'Not interested',
                      'Converted',
                    ],
                    onChanged: cubit.setStatusFilter,
                  );

                  final availableW = math.max(0.0, c.maxWidth);
                  if (availableW <= 0) return const SizedBox.shrink();

                  if (availableW >= 900) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const Gap(10),
                        Expanded(flex: 2, child: fSource),
                        const Gap(10),
                        Expanded(flex: 2, child: fCollege),
                        const Gap(10),
                        Expanded(flex: 2, child: fBranch),
                        const Gap(10),
                        Expanded(flex: 2, child: fYear),
                        const Gap(10),
                        Expanded(flex: 2, child: fStatus),
                      ],
                    );
                  }

                  final colW = availableW >= 560
                      ? math.max(100.0, (availableW - 20) / 3)
                      : (availableW >= 360
                          ? math.max(100.0, (availableW - 10) / 2)
                          : availableW);
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: availableW, child: searchField),
                      SizedBox(width: colW, child: fSource),
                      SizedBox(width: colW, child: fCollege),
                      SizedBox(width: colW, child: fBranch),
                      SizedBox(width: colW, child: fYear),
                      SizedBox(
                        width: availableW >= 560 ? colW : availableW,
                        child: fStatus,
                      ),
                    ],
                  );
                },
              ),
            ),
            const Gap(
              16,
            ), // Dark Bulk Selection & Assignment Bar (Always shown; grey & disabled if no tick selected)
            // Dark Bulk Selection & Assignment Bar (Responsive mobile-friendly layout)
            LayoutBuilder(
              builder: (context, barC) {
                final isMobileBar =
                    MediaQuery.of(context).size.width < 900 ||
                    barC.maxWidth < 820;

                final safeExecutives = state.activeExecutives;
                final safeSelectedExecUid = safeExecutives.any((e) => e.uid == state.selectedExecutive?.uid)
                    ? state.selectedExecutive?.uid
                    : (safeExecutives.isNotEmpty ? safeExecutives.first.uid : null);

                final execDropdown = Container(
                  height: 38,
                  width: isMobileBar ? null : 189,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF374151), width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: safeExecutives.isEmpty
                        ? Center(
                            child: Text(
                              'No active HR users',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF9CA3AF),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : DropdownButton<String>(
                            dropdownColor: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(8),
                            value: safeSelectedExecUid,
                            isDense: true,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            items: safeExecutives.map((exec) {
                              final count = state.assignmentCountForExecutive(
                                exec.uid,
                              );
                              return DropdownMenuItem<String>(
                                value: exec.uid,
                                child: Text(
                                  '${exec.name} ($count today)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (uid) {
                              if (uid != null) {
                                cubit.selectExecutive(uid);
                              }
                            },
                          ),
                  ),
                );

                final safeDateOptions = state.dateOptions.any((d) => d.dateKey == state.selectedDateKey)
                    ? state.dateOptions
                    : [(dateKey: state.selectedDateKey, label: state.selectedDateLabel), ...state.dateOptions];

                final dateDropdown = Container(
                  height: 38,
                  width: isMobileBar ? null : 147.75,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF374151), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: isMobileBar
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(8),
                            value: state.selectedDateKey,
                            isDense: true,
                            isExpanded: true,
                            icon: const SizedBox.shrink(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            items: safeDateOptions
                                .map(
                                  (d) => DropdownMenuItem<String>(
                                    value: d.dateKey,
                                    child: Text(
                                      d.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (key) {
                              if (key != null) {
                                cubit.selectAssignmentDate(key);
                              }
                            },
                          ),
                        ),
                      ),
                      const Gap(8),
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final parsed =
                              DateTime.tryParse(state.selectedDateKey) ?? now;
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: parsed,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                            builder: (ctx, child) {
                              return Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFEF8144),
                                    onPrimary: Colors.white,
                                    onSurface: Color(0xFF0F172A),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            cubit.selectCustomAssignmentDate(picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                    ],
                  ),
                );

                final assignBtn = SizedBox(
                  height: 36,
                  width: isMobileBar ? double.infinity : 97,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      alignment: Alignment.center,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: state.selectedLeadIds.isEmpty
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFEF8144),
                      foregroundColor: state.selectedLeadIds.isEmpty
                          ? const Color(0xFF9CA3AF)
                          : Colors.white,
                      disabledBackgroundColor: const Color(0xFF1F2937),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: state.selectedLeadIds.isEmpty
                              ? const Color(0xFF374151)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                    ),
                    onPressed:
                        state.selectedLeadIds.isEmpty ||
                            state.activeExecutives.isEmpty ||
                            state.isSubmitting
                        ? null
                        : () => _openReviewAssignmentDialog(context, state),
                    child: Center(
                      child: isMobileBar && state.selectedLeadIds.isNotEmpty
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Assign ${state.selectedLeadIds.length} Selected Leads',
                                textAlign: TextAlign.center,
                                style: AppTypography.figmaButton(
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Assign',
                              textAlign: TextAlign.center,
                              style: AppTypography.figmaButton(
                                color: state.selectedLeadIds.isEmpty
                                    ? const Color(0xFF9CA3AF)
                                    : Colors.white,
                              ),
                            ),
                    ),
                  ),
                );

                if (isMobileBar) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${state.selectedLeadIds.length} leads selected',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 20 / 14,
                            letterSpacing: 0.35,
                          ),
                        ),
                        const Gap(12),
                        Row(
                          children: [
                            Expanded(child: execDropdown),
                            const Gap(8),
                            Expanded(child: dateDropdown),
                          ],
                        ),
                        const Gap(12),
                        assignBtn,
                      ],
                    ),
                  );
                }

                return Container(
                  width: double.infinity,
                  height: 70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${state.selectedLeadIds.length} leads selected',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 20 / 14,
                          letterSpacing: 0.35,
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Assign to',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                  letterSpacing: 12 * 0.0049,
                                ),
                              ),
                              const Gap(16),
                              execDropdown,
                              const Gap(16),
                              Text(
                                'for',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                  letterSpacing: 12 * 0.0313,
                                ),
                              ),
                              const Gap(16),
                              dateDropdown,
                              const Gap(16),
                              assignBtn,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Gap(16),

            // Leads Table Card (Loading, Error, Empty, or Data rows)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildTableContent(
                context,
                state,
                rows,
                allSelectedOnPage,
              ),
            ),
            const Gap(14),

            // Pagination Footer
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 480;
                final textWidget = Text(
                  state.filteredLeads.isEmpty
                      ? 'Showing 0 of 0 matching leads'
                      : 'Showing ${state.showingStartIndex}–${state.showingEndIndex} of ${state.filteredLeads.length} matching leads',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                );
                final buttons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A1A1A),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: state.safeCurrentPage > 1
                          ? cubit.previousPage
                          : null,
                      child: Text(
                        'Previous',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Gap(8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A1A1A),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: state.safeCurrentPage < state.totalPages
                          ? cubit.nextPage
                          : null,
                      child: Text(
                        'Next',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      textWidget,
                      const Gap(12),
                      buttons,
                    ],
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      textWidget,
                      buttons,
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFigmaCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    Color activeColor = _primary,
    bool isRowHovered = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: value ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(2.5),
            border: Border.all(
              color: value
                  ? activeColor
                  : (isRowHovered ? const Color(0xFF334155) : const Color(0xFF767676)),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: value
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _buildTableContent(
    BuildContext context,
    AdminLeadsState state,
    List<LeadRecord> rows,
    bool allSelectedOnPage,
  ) {
    final cubit = context.read<AdminLeadsCubit>();

    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primary),
              Gap(12),
              Text(
                'Loading leads...',
                style: TextStyle(
                  color: _muted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.isPermissionDenied
                    ? Icons.lock_outline_rounded
                    : Icons.error_outline_rounded,
                size: 36,
                color: const Color(0xFFB91C1C),
              ),
              const Gap(10),
              Text(
                state.isPermissionDenied
                    ? 'Permission Denied'
                    : 'Unable to load leads',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const Gap(4),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              const Gap(14),
              OutlinedButton.icon(
                onPressed: cubit.refresh,
                icon: const Icon(CupertinoIcons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 36, color: _muted),
              const Gap(10),
              Text(
                state.allLeads.isEmpty
                    ? 'No leads available yet'
                    : 'No leads match your current filters',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const Gap(4),
              Text(
                state.allLeads.isEmpty
                    ? 'Click "+ Add lead" to create your first lead record.'
                    : 'Try clearing your search or changing the filter criteria.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              if (state.allLeads.isNotEmpty) ...[
                const Gap(12),
                OutlinedButton(
                  onPressed: () {
                    _searchC.clear();
                    cubit.resetFilters();
                  },
                  child: const Text('Reset filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // Mobile responsive card list (< 720px)
        if (c.maxWidth < 800) {
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _MobileLeadCardRow(
                  lead: rows[i],
                  isSelected: state.selectedLeadIds.contains(rows[i].id),
                  onTap: () =>
                      _openLeadDetailAndEditDialog(context, rows[i], state),
                  onSelectChanged: (v) =>
                      cubit.toggleLeadSelection(rows[i].id, v ?? false),
                  statusBadge: _statusBadge(rows[i].status),
                  checkboxBuilder: _buildFigmaCheckbox,
                ),
              ],
            ],
          );
        }

        final h = GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6B7280),
          letterSpacing: 1.1,
          height: 16.5 / 11,
        );
        return Column(
          children: [
            Container(
              color: const Color(0xFFF9FAFB),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 10,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildFigmaCheckbox(
                          value: allSelectedOnPage,
                          onChanged: (v) =>
                              cubit.toggleSelectAllOnPage(v ?? false),
                        ),
                        const Gap(20),
                        Text('NAME', style: h),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Text('COLLEGE - BRANCH', style: h),
                  ),
                  Expanded(flex: 6, child: Text('SOURCE', style: h)),
                  Expanded(flex: 5, child: Text('STATUS', style: h)),
                  Expanded(
                    flex: 5,
                    child: Text(
                      'LAST\nCONTACT',
                      style: h.copyWith(height: 1.2),
                    ),
                  ),
                  Expanded(flex: 6, child: Text('ASSIGNED TO', style: h)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFF9FAFB)),
              _DesktopLeadTableRow(
                lead: rows[i],
                isSelected: state.selectedLeadIds.contains(rows[i].id),
                onTap: () =>
                    _openLeadDetailAndEditDialog(context, rows[i], state),
                onSelectChanged: (v) =>
                    cubit.toggleLeadSelection(rows[i].id, v ?? false),
                statusBadge: _statusBadge(rows[i].status),
                checkboxBuilder: _buildFigmaCheckbox,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DesktopLeadTableRow extends StatefulWidget {
  final LeadRecord lead;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool?> onSelectChanged;
  final Widget statusBadge;
  final Widget Function({
    required bool value,
    required ValueChanged<bool?> onChanged,
    Color activeColor,
    bool isRowHovered,
  }) checkboxBuilder;

  const _DesktopLeadTableRow({
    required this.lead,
    required this.isSelected,
    required this.onTap,
    required this.onSelectChanged,
    required this.statusBadge,
    required this.checkboxBuilder,
  });

  @override
  State<_DesktopLeadTableRow> createState() => _DesktopLeadTableRowState();
}

class _DesktopLeadTableRowState extends State<_DesktopLeadTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.lead;
    final isSelected = widget.isSelected;

    // Harmonized with modern Figma dashboard:
    // Selected + Hovered: #FFEFE5 warm peach glow with 4px orange accent
    // Selected: #FFF6F0 warm peach tint with 3.5px orange accent
    // Hovered: #F8FAFC subtle cool slate tint with soft slate accent
    // Idle: Colors.white
    final Color bgColor = isSelected
        ? (_isHovered ? const Color(0xFFFFEFE5) : const Color(0xFFFFF6F0))
        : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white);

    final Color indicatorColor = isSelected
        ? _primary
        : (_isHovered ? const Color(0xFFCBD5E1) : Colors.transparent);

    final double indicatorWidth = isSelected
        ? (_isHovered ? 4.0 : 3.5)
        : (_isHovered ? 3.0 : 0.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            left: BorderSide(
              color: indicatorColor,
              width: indicatorWidth,
            ),
          ),
          boxShadow: _isHovered
              ? const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            splashColor: _primary.withValues(alpha: 0.08),
            highlightColor: _primary.withValues(alpha: 0.04),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSelected || _isHovered
                    ? (20.0 - indicatorWidth).clamp(16.0, 20.0)
                    : 20.0,
                vertical: 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 10,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        widget.checkboxBuilder(
                          value: isSelected,
                          isRowHovered: _isHovered,
                          onChanged: widget.onSelectChanged,
                        ),
                        const Gap(20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                r.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 16,
                                  letterSpacing: 0,
                                  color: _isHovered || isSelected
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF111827),
                                ),
                              ),
                              const Gap(2),
                              Text(
                                r.phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                  letterSpacing: 0,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        r.collegeBranch,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                          letterSpacing: -0.0957,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        r.source,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                          letterSpacing: -0.0957,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: widget.statusBadge,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        r.lastContact,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        r.assignedToName.isEmpty ? '—' : r.assignedToName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                          letterSpacing: 0.0684,
                          color: const Color(0xFF4B5563),
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
    );
  }
}

class _MobileLeadCardRow extends StatefulWidget {
  final LeadRecord lead;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool?> onSelectChanged;
  final Widget statusBadge;
  final Widget Function({
    required bool value,
    required ValueChanged<bool?> onChanged,
    Color activeColor,
    bool isRowHovered,
  }) checkboxBuilder;

  const _MobileLeadCardRow({
    required this.lead,
    required this.isSelected,
    required this.onTap,
    required this.onSelectChanged,
    required this.statusBadge,
    required this.checkboxBuilder,
  });

  @override
  State<_MobileLeadCardRow> createState() => _MobileLeadCardRowState();
}

class _MobileLeadCardRowState extends State<_MobileLeadCardRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.lead;
    final isSelected = widget.isSelected;

    final Color bgColor = isSelected
        ? (_isHovered ? const Color(0xFFFFEFE5) : const Color(0xFFFFF6F0))
        : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white);

    final Color indicatorColor = isSelected
        ? _primary
        : (_isHovered ? const Color(0xFFCBD5E1) : Colors.transparent);

    final double indicatorWidth = isSelected
        ? (_isHovered ? 4.0 : 3.5)
        : (_isHovered ? 3.0 : 0.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            left: BorderSide(
              color: indicatorColor,
              width: indicatorWidth,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSelected || _isHovered
                    ? (16.0 - indicatorWidth).clamp(12.0, 16.0)
                    : 16.0,
                vertical: 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  widget.checkboxBuilder(
                    value: isSelected,
                    isRowHovered: _isHovered,
                    onChanged: widget.onSelectChanged,
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 16,
                                  letterSpacing: 0,
                                  color: _isHovered || isSelected
                                      ? const Color(0xFF0F172A)
                                      : _text,
                                ),
                              ),
                            ),
                            widget.statusBadge,
                          ],
                        ),
                        Text(
                          r.phone,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 16 / 12,
                            letterSpacing: 0,
                            color: const Color(0xFF8A94A6),
                          ),
                        ),
                        const Gap(6),
                        Text(
                          '${r.collegeBranch} · ${r.source}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          'Source: ${r.source} · Last: ${r.lastContact} · Assigned: ${r.assignedToName}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

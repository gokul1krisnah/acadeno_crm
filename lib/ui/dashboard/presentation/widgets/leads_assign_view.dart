import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
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
                        const SizedBox(height: 4),
                        Text(
                          'Assignment Date: ${state.selectedDateLabel} (${state.selectedDateKey})',
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Leads Selected: ${selectedLeads.length}',
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SELECTED LEADS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                    const SizedBox(height: 12),
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
                          const SizedBox(height: 4),
                          CheckboxListTile(
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
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 18),
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
                              const SizedBox(width: 8),
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
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 14),
                      Text(
                        'College · Branch · Year',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 14),
                      Text(
                        'Source Event / Consent',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 20),
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
                          const SizedBox(width: 12),
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
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Lead Details · ${lead.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              _statusBadge(selectedStatus),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorText != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lead ID: ${lead.id}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Assigned To: ${lead.assignedToName}${lead.assignedDateLabel != null ? " (${lead.assignedDateLabel})" : ""}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _text,
                            ),
                          ),
                          if (lead.assignedByName != null &&
                              lead.assignedByName!.isNotEmpty)
                            Text(
                              'Assigned By: ${lead.assignedByName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameC,
                      decoration: InputDecoration(
                        labelText: 'Student Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneC,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '10-digit Phone Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      validator: LeadPhoneValidator.validate,
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedSource,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            decoration: InputDecoration(
                              labelText: 'Source',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              isDense: true,
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
                            onChanged: (v) => setD(
                              () => selectedSource = v ?? selectedSource,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            decoration: InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              isDense: true,
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
                            onChanged: (v) => setD(
                              () => selectedStatus = v ?? selectedStatus,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesC,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                    if (lead.timeline.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'TIMELINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...lead.timeline
                          .take(4)
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '• $t',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dCtx),
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
              onPressed: saving
                  ? null
                  : () async {
                      setD(() => errorText = null);
                      if (!formKey.currentState!.validate()) return;
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
                          errorText = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      }
                    },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (Color bg, Color fg) = switch (status) {
      'Follow-up' => (const Color(0xFFFFF1E6), const Color(0xFFB45309)),
      'Interested' => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      'Not interested' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'Converted' => (const Color(0xFFEDE9FE), const Color(0xFF4338CA)),
      'Assigned' => (const Color(0xFFE8EDFF), const Color(0xFF3730A3)),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF334155)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
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
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _text,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _muted,
              ),
              style: const TextStyle(fontSize: 13, color: _text),
              items: safeItems
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    MediaQuery.of(context).size.width < 768 || c.maxWidth < 760;
                final titleCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Leads',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.allLeads.length} leads · filter, select and assign to HR for a day',
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                );

                final actionButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: cubit.refresh,
                        icon: const Icon(
                          CupertinoIcons.refresh,
                          size: 16,
                          color: Color(0xFF475467),
                        ),
                        label: const Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: () => _tryDashboardCubit()?.selectNav(5),
                        icon: const Icon(
                          Icons.upload_file_rounded,
                          size: 16,
                          color: Color(0xFF475467),
                        ),
                        label: const Text(
                          'Import Leads',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                          size: 16,
                          color: Color(0xFF475467),
                        ),
                        label: Text(
                          'Export (${state.filteredLeads.isNotEmpty ? state.filteredLeads.length : ""})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF8144),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () => _openAddLeadDialog(context, state),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add lead',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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
                      const SizedBox(height: 12),
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
                      const SizedBox(width: 16),
                      actionButtons,
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // Filter Bar Card
            Container(
              padding: EdgeInsets.all(context.devicePadding.clamp(14.0, 18.0)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final searchField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _searchC,
                          onChanged: cubit.setSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Name, phone or college',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: _muted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _border),
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

                  if (c.maxWidth >= 880) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: fSource),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: fCollege),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: fBranch),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: fYear),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: fStatus),
                      ],
                    );
                  }

                  final colW = c.maxWidth >= 520
                      ? (c.maxWidth - 20) / 3
                      : (c.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: c.maxWidth, child: searchField),
                      SizedBox(width: colW, child: fSource),
                      SizedBox(width: colW, child: fCollege),
                      SizedBox(width: colW, child: fBranch),
                      SizedBox(width: colW, child: fYear),
                      SizedBox(
                        width: c.maxWidth >= 520 ? colW : c.maxWidth,
                        child: fStatus,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(
              height: 16,
            ), // Dark Bulk Selection & Assignment Bar (Always shown; grey & disabled if no tick selected)
            // Dark Bulk Selection & Assignment Bar (Responsive mobile-friendly layout)
            LayoutBuilder(
              builder: (context, barC) {
                final isMobileBar =
                    MediaQuery.of(context).size.width < 768 ||
                    barC.maxWidth < 640;

                final execDropdown = Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: state.activeExecutives.isEmpty
                        ? const Center(
                            child: Text(
                              'No active HR users',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12.5,
                              ),
                            ),
                          )
                        : DropdownButton<String>(
                            dropdownColor: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            value: state.selectedExecutive?.uid,
                            isDense: true,
                            isExpanded: isMobileBar,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            items: state.activeExecutives.map((exec) {
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

                final dateDropdown = Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisSize: isMobileBar
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    children: [
                      Expanded(
                        flex: isMobileBar ? 1 : 0,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            value: state.selectedDateKey,
                            isDense: true,
                            isExpanded: isMobileBar,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            items: state.dateOptions
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
                      const SizedBox(width: 6),
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
                  height: 40,
                  width: isMobileBar ? double.infinity : null,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.selectedLeadIds.isEmpty
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEF8144),
                      foregroundColor: state.selectedLeadIds.isEmpty
                          ? const Color(0xFF64748B)
                          : Colors.white,
                      disabledBackgroundColor: const Color(0xFF1E293B),
                      disabledForegroundColor: const Color(0xFF64748B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed:
                        state.selectedLeadIds.isEmpty ||
                            state.activeExecutives.isEmpty ||
                            state.isSubmitting
                        ? null
                        : () => _openReviewAssignmentDialog(context, state),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isMobileBar && state.selectedLeadIds.isNotEmpty
                            ? 'Assign ${state.selectedLeadIds.length} Selected Leads'
                            : 'Assign',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );

                if (isMobileBar) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: execDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: dateDropdown),
                          ],
                        ),
                        const SizedBox(height: 12),
                        assignBtn,
                      ],
                    ),
                  );
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Text(
                        '${state.selectedLeadIds.length} leads selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Assign to',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          execDropdown,
                          const Text(
                            'for',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          dateDropdown,
                          assignBtn,
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Leads Table Card (Loading, Error, Empty, or Data rows)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildTableContent(
                context,
                state,
                rows,
                allSelectedOnPage,
              ),
            ),
            const SizedBox(height: 14),

            // Pagination Footer
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  state.filteredLeads.isEmpty
                      ? 'Showing 0 of 0 matching leads'
                      : 'Showing ${state.showingStartIndex}–${state.showingEndIndex} of ${state.filteredLeads.length} matching leads',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _text,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: state.safeCurrentPage > 1
                          ? cubit.previousPage
                          : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _text,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: state.safeCurrentPage < state.totalPages
                          ? cubit.nextPage
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
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
              SizedBox(height: 12),
              Text(
                'Loading leads from Firestore...',
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
              const SizedBox(height: 10),
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
              const SizedBox(height: 4),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 10),
              Text(
                state.allLeads.isEmpty
                    ? 'No leads in Firestore yet'
                    : 'No leads match your current filters',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.allLeads.isEmpty
                    ? 'Click "+ Add lead" to create your first lead record.'
                    : 'Try clearing your search or changing the filter criteria.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              if (state.allLeads.isNotEmpty) ...[
                const SizedBox(height: 12),
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
                Builder(
                  builder: (_) {
                    final r = rows[i];
                    final isSelected = state.selectedLeadIds.contains(r.id);
                    return InkWell(
                      onTap: () =>
                          _openLeadDetailAndEditDialog(context, r, state),
                      child: Container(
                        color: isSelected
                            ? const Color(0xFFF5F6FF)
                            : Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: _primary,
                              onChanged: (v) =>
                                  cubit.toggleLeadSelection(r.id, v ?? false),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      _statusBadge(r.status),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${r.phone} · ${r.collegeBranch}',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
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
                    );
                  },
                ),
              ],
            ],
          );
        }

        const h = TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.4,
        );
        return Column(
          children: [
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: allSelectedOnPage,
                      activeColor: _primary,
                      onChanged: (v) => cubit.toggleSelectAllOnPage(v ?? false),
                    ),
                  ),
                  const Expanded(flex: 3, child: Text('NAME', style: h)),
                  const Expanded(
                    flex: 3,
                    child: Text('COLLEGE - BRANCH', style: h),
                  ),
                  const Expanded(flex: 2, child: Text('SOURCE', style: h)),
                  const Expanded(flex: 2, child: Text('STATUS', style: h)),
                  const Expanded(
                    flex: 2,
                    child: Text('LAST CONTACT', style: h),
                  ),
                  const Expanded(flex: 2, child: Text('ASSIGNED TO', style: h)),
                ],
              ),
            ),
            const Divider(height: 1),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Builder(
                builder: (_) {
                  final r = rows[i];
                  final isSelected = state.selectedLeadIds.contains(r.id);
                  return InkWell(
                    onTap: () =>
                        _openLeadDetailAndEditDialog(context, r, state),
                    child: Container(
                      color: isSelected
                          ? const Color(0xFFF5F6FF)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: _primary,
                              onChanged: (v) =>
                                  cubit.toggleLeadSelection(r.id, v ?? false),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: _text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  r.phone,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              r.collegeBranch,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _text,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r.source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _text,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _statusBadge(r.status),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r.lastContact,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _text,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r.assignedToName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

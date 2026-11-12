import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../shared/utilities/link_launcher.dart';

class _CollegeVisit {
  final String id;

  final String collegeName;

  final String dateLabel;

  final String purpose;

  final String assignedStaff;

  String status;

  String outcomeNotes;

  int leadsCollected;

  int conversions;

  _CollegeVisit({
    required this.id,

    required this.collegeName,

    required this.dateLabel,

    required this.purpose,

    required this.assignedStaff,

    required this.status,

    required this.outcomeNotes,

    required this.leadsCollected,

    required this.conversions,
  });
}

class CollegeVisitsView extends StatefulWidget {
  const CollegeVisitsView({super.key});

  @override
  State<CollegeVisitsView> createState() => _CollegeVisitsViewState();
}

class _CollegeVisitsViewState extends State<CollegeVisitsView> {
  final _visitsCollection = FirebaseFirestore.instance.collection(
    'college_visits',
  );

  void _showPlanVisitDialog() {
    final formKey = GlobalKey<FormState>();
    final collegeCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: DateFormat('dd MMM yyyy').format(DateTime.now()),
    );
    final purposeCtrl = TextEditingController();
    final staffCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
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
                      'Schedule campus outreach, seminar, or student drive',
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
                          return 'Please enter college & department';
                        }
                        return null;
                      },
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'College & Department *',
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
                    SizedBox(
                      height: 54,
                      child: TextField(
                        controller: dateCtrl,
                        readOnly: true,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: now,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFD45107),
                                    onPrimary: Colors.white,
                                    onSurface: Color(0xFF0F172A),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            dateCtrl.text = DateFormat(
                              'dd MMM yyyy',
                            ).format(picked);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Visit Date',
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
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const Gap(14),
                    TextFormField(
                      controller: purposeCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter purpose / event';
                        }
                        return null;
                      },
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Purpose / Event *',
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
                    const Gap(14),
                    TextFormField(
                      controller: staffCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter assigned staff';
                        }
                        return null;
                      },
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Assigned Staff *',
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
                    const Gap(22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
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
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final dText = dateCtrl.text.trim();
                                final dayNum =
                                    RegExp(r'\d+').firstMatch(dText)?.group(0) ??
                                    '29';
                                final month = dText.contains('Nov')
                                    ? 'NOV'
                                    : (dText.contains('Dec') ? 'DEC' : 'OCT');

                                await _visitsCollection.add({
                                  'collegeName': collegeCtrl.text.trim(),
                                  'dateLabel': dText,
                                  'dayNumber': dayNum,
                                  'monthShort': month,
                                  'purpose': purposeCtrl.text.trim().isEmpty
                                      ? 'Campus outreach & seminar'
                                      : purposeCtrl.text.trim(),
                                  'assignedStaff': staffCtrl.text.trim(),
                                  'staffNames': staffCtrl.text.trim(),
                                  'staffInitials': staffCtrl.text
                                      .trim()
                                      .split(',')
                                      .map((s) => s.trim())
                                      .where((s) => s.isNotEmpty)
                                      .map(
                                        (s) => s
                                            .split(' ')
                                            .where((p) => p.isNotEmpty)
                                            .map((p) => p[0].toUpperCase())
                                            .join(),
                                      )
                                      .where((s) => s.isNotEmpty)
                                      .toList(),
                                  'status': 'Planned',
                                  'statusLabel': 'Planned',
                                  'outcomeNotes': 'Scheduled campus visit.',
                                  'leadsCollected': 0,
                                  'conversions': 0,
                                  'createdByUid':
                                      FirebaseAuth.instance.currentUser?.uid,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: Text(
                                'Save Visit',
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
    );
  }

  void _showLogOutcomeDialog(_CollegeVisit visit) {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final notesCtrl = TextEditingController(text: visit.outcomeNotes);
    final leadsCtrl = TextEditingController(
      text: visit.leadsCollected > 0 ? '${visit.leadsCollected}' : '',
    );
    bool isCancelled = visit.status == 'Cancelled';
    bool isSaving = false;

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
                              onTap: isSaving
                                  ? null
                                  : () {
                                      setDialogState(() {
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
                              onTap: isSaving
                                  ? null
                                  : () {
                                      setDialogState(() {
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
                    TextFormField(
                      key: ValueKey('visit_outcome_notes_$isCancelled'),
                      controller: notesCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return isCancelled
                              ? 'Please enter cancellation reason & notes'
                              : 'Please enter meeting notes & agreements';
                        }
                        return null;
                      },
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: isCancelled
                            ? 'Cancellation reason & notes *'
                            : 'People met, agreements & notes *',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: Icon(
                          isCancelled
                              ? Icons.report_problem_outlined
                              : Icons.people_outline_rounded,
                          size: 19,
                          color: const Color(0xFF64748B),
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
                    if (!isCancelled) ...[
                      const Gap(14),
                      TextFormField(
                        key: const ValueKey('visit_outcome_leads'),
                        controller: leadsCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (isCancelled) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter student leads count';
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0) {
                            return 'Please enter valid count';
                          }
                          return null;
                        },
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Student leads collected from visit *',
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
                    ],
                    const Gap(20),

                    // Primary Button (same as Log Visit)
                    SizedBox(
                      width: double.infinity,
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
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setDialogState(() => isSaving = true);
                                final newNotes = notesCtrl.text.trim();
                                final newLeads = isCancelled
                                    ? 0
                                    : (int.tryParse(leadsCtrl.text.trim()) ??
                                        0);

                                try {
                                  if (isCancelled) {
                                    await _visitsCollection.doc(visit.id).set({
                                      'status': 'Cancelled',
                                      'statusLabel': 'Cancelled',
                                      'outcomeNotes': newNotes,
                                      'cancelReason': newNotes,
                                      'leadsCollected': 0,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Visit to ${visit.collegeName} saved as Cancelled.',
                                          ),
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  } else {
                                    await _visitsCollection.doc(visit.id).set({
                                      'status': 'Completed',
                                      'statusLabel': 'Completed',
                                      'outcomeNotes': newNotes,
                                      'metSummary': newNotes,
                                      'leadsCollected': newLeads,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Visit to ${visit.collegeName} marked as Completed!',
                                          ),
                                          backgroundColor:
                                              const Color(0xFF15803D),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  setDialogState(() => isSaving = false);
                                  if (ctx.mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update visit: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
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

  Future<void> _confirmDeleteVisit(
    BuildContext context,
    _CollegeVisit visit,
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
      try {
        await _visitsCollection.doc(visit.id).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Visit to ${visit.collegeName} deleted'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _visitsCollection.snapshots(),
      builder: (context, snapshot) {
        final List<_CollegeVisit> visits;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          visits = snapshot.data!.docs.map((doc) {
            final d = doc.data();

            return _CollegeVisit(
              id: doc.id,
              collegeName: (d['collegeName'] ?? 'College').toString(),
              dateLabel:
                  (d['dateLabel'] ??
                          DateFormat('d MMM yyyy').format(DateTime.now()))
                      .toString(),
              purpose: (d['purpose'] ?? '').toString(),
              assignedStaff: (d['assignedStaff'] ?? d['staffNames'] ?? 'Team')
                  .toString(),
              status: (d['status'] ?? d['statusLabel'] ?? 'Planned').toString(),
              outcomeNotes: (d['outcomeNotes'] ?? d['metSummary'] ?? '')
                  .toString(),
              leadsCollected: (d['leadsCollected'] as num?)?.toInt() ?? 0,
              conversions: (d['conversions'] as num?)?.toInt() ?? 0,
            );
          }).toList();
        } else {
          visits = const [];
        }

        final totalLeads = visits.fold<int>(
          0,
          (acc, v) => acc + v.leadsCollected,
        );

        final totalConversions = visits.fold<int>(
          0,
          (acc, v) => acc + v.conversions,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              LayoutBuilder(
                builder: (context, c) {
                  final isMobile =
                      MediaQuery.of(context).size.width < 768 || c.maxWidth < 680;
                  final titleCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'College visits',
                        style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.3809,
                          height: 36 / 30,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        'Plan campus outreach, log HOD/faculty meetings, and track $totalLeads leads ($totalConversions conversions) generated',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          letterSpacing: -0.1094,
                          height: 24 / 16,
                        ),
                      ),
                    ],
                  );

                  final planBtn = SizedBox(
                    height: 44,
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: _showPlanVisitDialog,
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: Text(
                        'Plan college visit',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.0137,
                          height: 24 / 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        alignment: Alignment.center,
                        backgroundColor: const Color(0xFFEF8144),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [titleCol, const Gap(16), planBtn],
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleCol),
                        const Gap(24),
                        planBtn,
                      ],
                    ),
                  );
                },
              ),
              const Gap(32),

              if (visits.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.05),
                        blurRadius: 1,
                        offset: Offset(0, 1),
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
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          CupertinoIcons.calendar_today,
                          color: Color(0xFF94A3B8),
                          size: 24,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        'No planned visits yet',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Gap(6),
                      Text(
                        'Click "Plan college visit" above to schedule campus outreach.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...visits.map((visit) {
                  final isCompleted = visit.status == 'Completed';
                  final isCancelled = visit.status == 'Cancelled';

                  return LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final isMobile =
                          MediaQuery.of(context).size.width < 768 ||
                          cardConstraints.maxWidth < 680;

                      Color badgeBg;
                      Color badgeBorder;
                      Color badgeDot;
                      Color badgeFg;
                      if (isCompleted) {
                        badgeBg = const Color(0xFFF0FDF4);
                        badgeBorder = const Color(0xFFDCFCE7);
                        badgeDot = const Color(0xFF22C55E);
                        badgeFg = const Color(0xFF22C55E);
                      } else if (isCancelled) {
                        badgeBg = const Color(0xFFFEF2F2);
                        badgeBorder = const Color(0xFFFECACA);
                        badgeDot = const Color(0xFFDC2626);
                        badgeFg = const Color(0xFFDC2626);
                      } else {
                        badgeBg = const Color(0xFFFFF7ED);
                        badgeBorder = const Color(0xFFFFEDD5);
                        badgeDot = const Color(0xFFEA580C);
                        badgeFg = const Color(0xFFEA580C);
                      }

                      final statusBadge = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: badgeDot,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Gap(6),
                            Text(
                              '${visit.status} • ${visit.dateLabel}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: badgeFg,
                                letterSpacing: 0.0137,
                                height: 20 / 14,
                              ),
                            ),
                          ],
                        ),
                      );

                      final actionButtons = Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isCancelled)
                            InkWell(
                              onTap: () =>
                                  _confirmDeleteVisit(context, visit),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.trash,
                                  size: 14,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          InkWell(
                            onTap: () =>
                                LinkLauncher.launchCollegeMapsDirections(
                                  visit.collegeName,
                                ),
                            borderRadius: BorderRadius.circular(9999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.near_me_rounded,
                                    size: 14,
                                    color: Color(0xFF4F46E5),
                                  ),
                                  const Gap(8),
                                  Text(
                                    'Directions',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF4F46E5),
                                      letterSpacing: 0.0547,
                                      height: 20 / 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showLogOutcomeDialog(visit),
                            borderRadius: BorderRadius.circular(9999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                'Update outcome',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.041,
                                  height: 20 / 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: isMobile
                            ? const EdgeInsets.all(18)
                            : const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                            width: 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.05),
                              blurRadius: 1,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isMobile)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        visit.collegeName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                          letterSpacing: -0.4492,
                                          height: 28 / 20,
                                        ),
                                      ),
                                      statusBadge,
                                    ],
                                  ),
                                  const Gap(14),
                                  actionButtons,
                                ],
                              )
                            else
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          visit.collegeName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                            letterSpacing: -0.4492,
                                            height: 28 / 20,
                                          ),
                                        ),
                                        statusBadge,
                                      ],
                                    ),
                                  ),
                                  const Gap(16),
                                  actionButtons,
                                ],
                              ),
                            const Gap(16),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 20 / 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Purpose: ',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  TextSpan(
                                    text: visit.purpose.isEmpty
                                        ? 'Campus outreach'
                                        : visit.purpose,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  •  ',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Staff: ',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  TextSpan(
                                    text: visit.assignedStaff.isEmpty
                                        ? 'Team'
                                        : visit.assignedStaff,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  if (visit.outcomeNotes.isNotEmpty) ...[
                                    TextSpan(
                                      text: '  •  ',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFCBD5E1),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: visit.outcomeNotes,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (visit.leadsCollected > 0 ||
                                visit.conversions > 0) ...[
                              const Gap(14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (visit.leadsCollected > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${visit.leadsCollected} leads collected',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                  if (visit.conversions > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${visit.conversions} conversions',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF047857),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                }),
            ],
          );
      },
    );
  }
}

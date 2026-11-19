import 'package:acadeno_crm/core/injection/injection.dart';
import 'package:acadeno_crm/ui/follow_ups/data/repository/follow_ups_repo.dart';
import 'package:acadeno_crm/ui/follow_ups/data/sources/follow_ups_rds.dart';
import 'package:acadeno_crm/ui/leads/data/repository/leads_repo.dart';
import 'package:acadeno_crm/ui/leads/data/sources/leads_rds.dart';
import 'package:acadeno_crm/shared/widgets/acadeno_dropdown.dart';
import '../pages/lead_detail_page.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:acadeno_crm/shared/widgets/college_selector_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';

import 'package:acadeno_crm/ui/dashboard/presentation/widgets/figma_calendar_dialog.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_cubit.dart';
import 'package:acadeno_crm/ui/home/application/home_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LeadCallSheets {
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // ACADENO Official Curriculum Programs & Matcher
  // ---------------------------------------------------------------------------
  static const List<String> acadenoPrograms = [
    'Python Full Stack',
    'Python AI & Machine Learning',
    'Data Science & AI',
    'Data Analytics',
    'MERN Stack Development',
    'Robotics & IoT',
    'Flutter Mobile App',
    'Digital Marketing',
    'Cyber Security',
  ];

  static String matchProgram(String? raw) {
    if (raw == null || raw.trim().isEmpty) return acadenoPrograms.first;
    final lower = raw.trim().toLowerCase();
    for (final prog in acadenoPrograms) {
      if (prog.toLowerCase() == lower) return prog;
    }
    if (lower.contains('flutter') || lower.contains('mobile')) {
      return 'Flutter Mobile App';
    }
    if (lower.contains('mern') ||
        lower.contains('react') ||
        lower.contains('node')) {
      return 'MERN Stack Development';
    }
    if (lower.contains('data science')) {
      return 'Data Science & AI';
    }
    if (lower.contains('data analytic') || lower.contains('analytics')) {
      return 'Data Analytics';
    }
    if (lower.contains('robot') || lower.contains('iot')) {
      return 'Robotics & IoT';
    }
    if (lower.contains('cyber') ||
        lower.contains('security') ||
        lower.contains('ethical')) {
      return 'Cyber Security';
    }
    if (lower.contains('digital market') || lower.contains('marketing')) {
      return 'Digital Marketing';
    }
    if (lower.contains('machine learning') ||
        lower.contains('ai') ||
        lower.contains('ml')) {
      return 'Python AI & Machine Learning';
    }
    if (lower.contains('python') ||
        lower.contains('full stack') ||
        lower.contains('fullstack')) {
      return 'Python Full Stack';
    }
    return acadenoPrograms.first;
  }

  // 1. Mandatory Call & Outcome Sheet (Matches Exact Figma UI node-id=1643-2)
  // ---------------------------------------------------------------------------
  static Future<bool> showCallAndOutcomeSheet(
    BuildContext context, {
    String? leadId,
    required String leadName,
    String maskedPhone = '98470 •••11',
    String collegeInfo = 'NIT Calicut · CSE · 3rd yr',
    String campaignTag = 'AI & ML Workshop',
    String initialDuration = '0s',
    String? course,
    String? fee,
    Future<void> Function({
      required String outcome,
      required String notes,
      String? courseEnrolled,
      String? batch,
      String? followUpTime,
    })? onSave,
  }) async {
    final LeadsCubit cubit;
    LeadsCubit? tempCubit;
    try {
      tempCubit = context.read<LeadsCubit>();
    } catch (_) {
      try {
        tempCubit = getIt<LeadsCubit>();
      } catch (_) {}
    }
    cubit = tempCubit ?? LeadsCubit(LeadsRepository(LeadsRds()));

    final FollowUpsCubit followUpsCubit;
    FollowUpsCubit? tempFollowUpsCubit;
    try {
      tempFollowUpsCubit = context.read<FollowUpsCubit>();
    } catch (_) {
      try {
        tempFollowUpsCubit = getIt<FollowUpsCubit>();
      } catch (_) {}
    }
    followUpsCubit =
        tempFollowUpsCubit ??
        FollowUpsCubit(FollowUpsRepository(FollowUpsRds()));

    String selectedOutcome = 'Interested';
    bool isSaving = false;
    String? saveError;
    String selectedFollowUpSlot = LeadDateHelper.formatFollowUp(
      DateTime.now().add(const Duration(days: 1)).copyWith(hour: 10, minute: 30),
    );
    String selectedProgram = matchProgram(course);
    String selectedPaymentMode = 'UPI';
    String expectedBalanceDate = LeadDateHelper.formatFollowUp(
      DateTime.now().add(const Duration(days: 7)).copyWith(hour: 11, minute: 0),
    );
    final notesCtrl = TextEditingController();
    final resolvedInitialDuration = initialDuration.trim().isNotEmpty
        ? initialDuration.trim()
        : '0s';
    final batchCtrl = TextEditingController(text: 'Nov 2026 Weekend');
    final rawFeeDigits = (fee ?? '').replaceAll(RegExp(r'\D'), '');
    final feeCtrl = TextEditingController(
      text: rawFeeDigits.isNotEmpty ? rawFeeDigits : '1499',
    );
    final discountCtrl = TextEditingController(text: '0');
    final paidCtrl = TextEditingController(
      text: rawFeeDigits.isNotEmpty ? rawFeeDigits : '1499',
    );
    final receiptCtrl = TextEditingController();

    const outcomeRows = [
      [('Interested', Color(0xFF22C55E)), ('No answer', Color(0xFF1E3A8A))],
      [('Busy', Color(0xFF4F46E5)), ('Switched off', Color(0xFF0F172A))],
      [('Converted', Color(0xFF2563EB)), ('Not interested', Color(0xFFDC2626))],
      [('Wrong number', Color(0xFF64748B)), ('Callback', Color(0xFFD97706))],
    ];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      elevation: 0,
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        final safeBottom = MediaQuery.paddingOf(ctx).bottom;
        final screenWidth = MediaQuery.sizeOf(ctx).width;
        final hPad = screenWidth < 360 ? 16.0 : 20.0;

        return Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 512,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
            ),
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                return Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      12,
                      hPad,
                      bottomInset + (safeBottom > 0 ? safeBottom + 12 : 24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Drag Handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                        const Gap(20),

                        // Title: How did the call go?
                        Text(
                          'How did the call go?',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                            height: 28 / 22,
                          ),
                        ),
                        const Gap(20),

                        // 2x4 Outcomes Grid
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(outcomeRows.length, (rowIdx) {
                            final row = outcomeRows[rowIdx];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: rowIdx < outcomeRows.length - 1 ? 12 : 0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildOutcomeButton(
                                      name: row[0].$1,
                                      dotColor: row[0].$2,
                                      isSelected: selectedOutcome == row[0].$1,
                                      onTap: () {
                                        setSheetState(
                                          () => selectedOutcome = row[0].$1,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildOutcomeButton(
                                      name: row[1].$1,
                                      dotColor: row[1].$2,
                                      isSelected: selectedOutcome == row[1].$1,
                                      onTap: () {
                                        setSheetState(
                                          () => selectedOutcome = row[1].$1,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),

                        // Converted: Course / Workshop dropdown and Batch input
                        if (selectedOutcome == 'Converted') ...[
                          const Gap(20),
                          Text(
                            'Course / Workshop',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                              height: 18 / 12,
                            ),
                          ),
                          const Gap(6),
                          AcadenoDropdown<String>(
                            value: selectedProgram,
                            items: acadenoPrograms
                                .map(
                                  (p) => AcadenoDropdownItem<String>(
                                    value: p,
                                    label: p,
                                  ),
                                )
                                .toList(),
                            fillColor: const Color(0xFFF5F5F5),
                            borderColor: const Color(0xFFE5E7EB),
                            borderRadius: 16.0,
                            dropdownColor: const Color(0xFFE2E2E2),
                            activeItemColor: const Color(0xFFC84B14),
                            onChanged: (v) {
                              if (v != null) {
                                setSheetState(() => selectedProgram = v);
                              }
                            },
                          ),
                          const Gap(14),
                          Text(
                            'Batch',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                              height: 18 / 12,
                            ),
                          ),
                          const Gap(6),
                          Container(
                            height: 47,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: batchCtrl,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1E293B),
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Enter batch name...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ] else if (selectedOutcome == 'Callback') ...[
                          const Gap(20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final dateButton = Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    final now = DateTime.now();
                                    final d = await showFigmaCalendarDialog(
                                      context: ctx,
                                      initialDate: now.add(
                                        const Duration(days: 1),
                                      ),
                                      firstDate: now,
                                      lastDate: now.add(
                                        const Duration(days: 90),
                                      ),
                                    );
                                    if (d != null && ctx.mounted) {
                                      final t = await showTimePicker(
                                        context: ctx,
                                        initialTime: const TimeOfDay(
                                          hour: 10,
                                          minute: 30,
                                        ),
                                      );
                                      if (t != null) {
                                        final dt = DateTime(
                                          d.year,
                                          d.month,
                                          d.day,
                                          t.hour,
                                          t.minute,
                                        );
                                        setSheetState(() {
                                          selectedFollowUpSlot =
                                              LeadDateHelper.formatFollowUp(dt);
                                        });
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFFFEDD5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 14,
                                          color: Color(0xFFC84B14),
                                        ),
                                        const Gap(8),
                                        Flexible(
                                          child: Text(
                                            selectedFollowUpSlot,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFC84B14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              final isNarrow = constraints.maxWidth < 360;
                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Callback Date & Time',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF374151),
                                      ),
                                    ),
                                    const Gap(8),
                                    dateButton,
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Callback Date & Time',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                  const Gap(10),
                                  Flexible(child: dateButton),
                                ],
                              );
                            },
                          ),
                        ],

                        const Gap(24),

                        // Notes (optional)
                        Text(
                          'Notes (optional)',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            height: 22 / 16,
                          ),
                        ),
                        const Gap(10),

                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 112),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: notesCtrl,
                            maxLines: 4,
                            minLines: 3,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF0F172A),
                              height: 1.45,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText:
                                  'Wants fee details and batch timings. Prefers WhatsApp.',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF475569),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.45,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        if (saveError != null) ...[
                          const Gap(14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                const Gap(8),
                                Expanded(
                                  child: Text(
                                    saveError!,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFB91C1C),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(14),
                        ] else
                          const Gap(28),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (selectedOutcome.trim().isEmpty) {
                                      setSheetState(
                                        () => saveError =
                                            'Please select a call outcome before saving.',
                                      );
                                      return;
                                    }
                                    if (selectedOutcome == 'Converted' &&
                                        batchCtrl.text.trim().isEmpty) {
                                      setSheetState(
                                        () => saveError =
                                            'Please enter a batch name for converted leads.',
                                      );
                                      return;
                                    }

                                    setSheetState(() {
                                      isSaving = true;
                                      saveError = null;
                                    });

                                    final trimmedNotes = notesCtrl.text.trim();
                                    final courseVal =
                                        (selectedOutcome == 'Converted' ||
                                            selectedOutcome == 'Interested')
                                        ? selectedProgram
                                        : null;
                                    final batchVal =
                                        selectedOutcome == 'Converted'
                                        ? batchCtrl.text.trim()
                                        : null;

                                    try {
                                      if (onSave != null) {
                                        await onSave(
                                          outcome: selectedOutcome,
                                          notes: trimmedNotes,
                                          courseEnrolled: courseVal,
                                          batch: batchVal,
                                          followUpTime: selectedFollowUpSlot,
                                        );
                                      } else {
                                        final feeVal = int.tryParse(
                                          feeCtrl.text.trim(),
                                        );
                                        final discVal = int.tryParse(
                                          discountCtrl.text.trim(),
                                        );
                                        final paidVal = int.tryParse(
                                          paidCtrl.text.trim(),
                                        );
                                        final balanceVal =
                                            (feeVal ?? 0) -
                                            (discVal ?? 0) -
                                            (paidVal ?? 0);

                                        final result = await cubit
                                            .recordCallOutcome(
                                              leadId: leadId,
                                              leadName: leadName,
                                              outcome: selectedOutcome,
                                              duration: resolvedInitialDuration,
                                              notes: trimmedNotes,
                                              courseEnrolled: courseVal,
                                              discountAmount:
                                                  selectedOutcome == 'Converted'
                                                  ? discVal
                                                  : null,
                                              batch: batchVal,
                                              feeAmount:
                                                  selectedOutcome == 'Converted'
                                                  ? feeVal
                                                  : null,
                                              amountPaid:
                                                  selectedOutcome == 'Converted'
                                                  ? paidVal
                                                  : null,
                                              paymentMode:
                                                  selectedOutcome == 'Converted'
                                                  ? selectedPaymentMode
                                                  : null,
                                              receiptNumber:
                                                  selectedOutcome == 'Converted'
                                                  ? receiptCtrl.text.trim()
                                                  : null,
                                              expectedBalanceDate:
                                                  (selectedOutcome ==
                                                          'Converted' &&
                                                      balanceVal > 0)
                                                  ? expectedBalanceDate
                                                  : null,
                                              followUpTime:
                                                  selectedFollowUpSlot,
                                            );
                                        followUpsCubit.addFromCallOutcome(
                                          leadName: leadName,
                                          collegeInfo: result.collegeInfo,
                                          outcome:
                                              (selectedOutcome == 'Converted' &&
                                                  balanceVal > 0)
                                              ? 'Follow-up'
                                              : (selectedOutcome == 'Callback'
                                                    ? 'Follow-up'
                                                    : selectedOutcome),
                                          notes:
                                              (selectedOutcome == 'Converted' &&
                                                  balanceVal > 0)
                                              ? 'Balance collection (₹$balanceVal due)'
                                              : trimmedNotes,
                                          followUpTimeLabel:
                                              (selectedOutcome == 'Converted' &&
                                                  balanceVal > 0)
                                              ? expectedBalanceDate
                                              : selectedFollowUpSlot,
                                        );
                                      }

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx, true);
                                      }
                                      if (context.mounted) {
                                        SnackBarAlert.showToast(
                                          context: context,
                                          message:
                                              'Saved as $selectedOutcome',
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('recordCallOutcome error: $e');
                                      if (ctx.mounted) {
                                        final rawMsg = e
                                            .toString()
                                            .replaceFirst('Exception: ', '')
                                            .replaceFirst(
                                              'Bad state: ',
                                              '',
                                            );
                                        setSheetState(() {
                                          isSaving = false;
                                          saveError = rawMsg.isNotEmpty
                                              ? 'Failed to save: $rawMsg'
                                              : 'Failed to save outcome. Please try again.';
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC84B14),
                              disabledBackgroundColor: const Color(
                                0xFFC84B14,
                              ).withValues(alpha: 0.65),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Save',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 24 / 17,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    return saved == true;
  }

  static Widget _buildOutcomeButton({
    required String name,
    required Color dotColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC84B14) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFC84B14)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x45C84B14),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                  height: 20 / 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Lead Detail Page Navigation (Matches Exact First Image UI + PR-2.5 100/hr Rate Limit)
  // ---------------------------------------------------------------------------
  static Future<void> showLeadDetailSheet(
    BuildContext context, {
    required ExecutiveLeadItem lead,
  }) async {
    try {
      final cubit = context.read<LeadsCubit>();
      final allowed = await cubit.checkAndRecordLeadDetailOpen();
      if (!allowed) return;
    } catch (_) {}
    if (!context.mounted) return;

    LeadsCubit? leadsCubit;
    try {
      leadsCubit = context.read<LeadsCubit>();
    } catch (_) {
      try {
        leadsCubit = getIt<LeadsCubit>();
      } catch (_) {}
    }

    FollowUpsCubit? followUpsCubit;
    try {
      followUpsCubit = context.read<FollowUpsCubit>();
    } catch (_) {
      try {
        followUpsCubit = getIt<FollowUpsCubit>();
      } catch (_) {}
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) {
          Widget page = LeadDetailPage(lead: lead);
          if (leadsCubit != null && followUpsCubit != null) {
            return MultiBlocProvider(
              providers: [
                BlocProvider.value(value: leadsCubit),
                BlocProvider.value(value: followUpsCubit),
              ],
              child: page,
            );
          } else if (leadsCubit != null) {
            return BlocProvider.value(value: leadsCubit, child: page);
          } else if (followUpsCubit != null) {
            return BlocProvider.value(value: followUpsCubit, child: page);
          }
          return page;
        },
      ),
    );
  }

  // WhatsApp Templates Quick Action Sheet
  static void showWhatsAppTemplatesSheet(
    BuildContext context, {
    required ExecutiveLeadItem lead,
  }) {
    final cubit = context.read<LeadsCubit>();
    const templates = [
      (
        'Brochure & Syllabus',
        'Hi! Here is the official ACADENO AI & ML Workshop syllabus & brochure.',
      ),
      (
        'Fee & Early-Bird Offer',
        'Workshop fee is ₹1,499 (₹999 early-bird for groups of 3+).',
      ),
      (
        'Batch Timings',
        'Weekend batch starts 14 Nov, 9:30 AM – 4:30 PM at Acadeno Centre.',
      ),
      (
        'Campus Location Pin',
        'Acadeno Research & Innovation Centre location map & contact details.',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  24 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Gap(16),
                    const Text(
                      'WhatsApp Quick Templates',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Gap(6),
                    Text(
                      'Choose a pre-filled template to send to ${lead.name}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Gap(14),
                    ...templates.map((tpl) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await cubit.logWhatsAppTemplateSent(
                              leadId: lead.id,
                              leadName: lead.name,
                              templateTitle: tpl.$1,
                            );
                            final rawPhone = lead.fullPhone.isNotEmpty
                                ? lead.fullPhone
                                : lead.maskedPhone;
                            final digits = rawPhone.replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            final cleanPhone = digits.length == 10
                                ? '91$digits'
                                : digits;
                            final encodedText = Uri.encodeComponent(tpl.$2);
                            final uri = Uri.parse(
                              cleanPhone.isNotEmpty
                                  ? 'https://wa.me/$cleanPhone?text=$encodedText'
                                  : 'https://wa.me/?text=$encodedText',
                            );
                            try {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {}
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF15803D),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tpl.$1,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const Gap(2),
                                      Text(
                                        tpl.$2,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Phone Lookup & Add Walk-In Lead Sheet
  // ---------------------------------------------------------------------------
  static void showPhoneLookupAndWalkInSheet(BuildContext context) {
    final cubit = context.read<LeadsCubit>();
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final collegeCtrl = TextEditingController(
      text: 'MES College · CSE · 3rd yr',
    );
    final otherSourceCtrl = TextEditingController();
    String selectedCampaign = 'Social Media';
    String? lookupFeedback;
    bool lookupFoundDuplicate = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Heading Text (Inter Bold 700, 20px, line-height 27.5px)
                      Text(
                        'Phone Lookup & Add Walk-in Lead',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 27.5 / 20,
                          letterSpacing: 0,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Gap(6),
                      // Short Heading (Inter Regular 400, 13px, line-height 21.13px)
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

                      // Phone Lookup Row: Phone input (height 54) + Check button (width 98, height 54)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                textAlignVertical: TextAlignVertical.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 21.13 / 13,
                                  color: const Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText: '10-digit mobile nu...',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    height: 21.13 / 13,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
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
                            ),
                          ),
                          const Gap(10),
                          // Check button (Figma spec: width 98, height 54, borderRadius 12, padding 24px)
                          SizedBox(
                            width: 98,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () async {
                                final res = await cubit.lookupByPhone(
                                  phoneCtrl.text,
                                );
                                if (!ctx.mounted) return;
                                setSheetState(() {
                                  lookupFeedback = res.owner != null
                                      ? '${res.message} · Owned by ${res.owner} (${res.status})'
                                      : res.message;
                                  lookupFoundDuplicate = res.found;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE2E8F0),
                                foregroundColor: const Color(0xFF334155),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Check',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (lookupFeedback != null) ...[
                        const Gap(12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: lookupFoundDuplicate
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                lookupFoundDuplicate
                                    ? Icons.error_outline_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 18,
                                color: lookupFoundDuplicate
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  lookupFeedback!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: lookupFoundDuplicate
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF166534),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Gap(14),

                      // Student Name (Figma spec: width 343, height 54, borderRadius 12, borderWidth 1, padding 16)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: TextField(
                          controller: nameCtrl,
                          textAlignVertical: TextAlignVertical.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Student Name (Optional)',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
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
                      ),
                      const Gap(14),

                      // College Selection Dropdown + Add New College + College · Branch · Year
                      CollegeSelectorField(controller: collegeCtrl),
                      const Gap(4),
                      Text(
                        'You can freely edit or fine-tune college, bran...',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const Gap(14),

                      // Source Event Label
                      Text(
                        'Source Event',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const Gap(6),
                      // Source Event Dropdown
                      Container(
                        height: 47,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D764BA2),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 21),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCampaign,
                            isExpanded: true,
                            dropdownColor: const Color(0xFFE2E2E2),
                            borderRadius: BorderRadius.circular(12),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF2E1D44),
                              size: 20,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2E1D44),
                            ),
                            selectedItemBuilder: (context) => [
                              'Social Media',
                              'Contact',
                              'Referral',
                              'Other',
                            ].map((c) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                c,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF2E1D44),
                                ),
                              ),
                            )).toList(),
                            items: [
                              DropdownMenuItem(
                                value: 'Social Media',
                                child: AcadenoDropdown.buildMenuItemChild(
                                  label: 'Social Media',
                                  isSelected: selectedCampaign == 'Social Media',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Contact',
                                child: AcadenoDropdown.buildMenuItemChild(
                                  label: 'Contact',
                                  isSelected: selectedCampaign == 'Contact',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Referral',
                                child: AcadenoDropdown.buildMenuItemChild(
                                  label: 'Referral',
                                  isSelected: selectedCampaign == 'Referral',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Other',
                                child: AcadenoDropdown.buildMenuItemChild(
                                  label: 'Other',
                                  isSelected: selectedCampaign == 'Other',
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setSheetState(() => selectedCampaign = v);
                              }
                            },
                          ),
                        ),
                      ),
                      if (selectedCampaign == 'Other') ...[
                        const Gap(10),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: TextField(
                            controller: otherSourceCtrl,
                            textAlignVertical: TextAlignVertical.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter source details *',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
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
                        ),
                      ],
                      const Gap(20),

                      // Save Button (Figma spec: width 343, height 44, borderRadius 16, padding-top 14.5, padding-bottom 15.5)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (lookupFoundDuplicate || isSaving)
                              ? null
                              : () async {
                                  final phoneErr = LeadPhoneValidator.validate(
                                    phoneCtrl.text,
                                  );
                                  if (phoneErr != null) {
                                    setSheetState(() {
                                      lookupFeedback = phoneErr;
                                      lookupFoundDuplicate = true;
                                    });
                                    return;
                                  }
                                  setSheetState(() {
                                    isSaving = true;
                                  });
                                  try {
                                    await CollegeSelectorField.saveCollegeIfNew(
                                      collegeCtrl.text,
                                    );
                                    final effectiveCampaign =
                                        (selectedCampaign == 'Other' &&
                                                otherSourceCtrl.text
                                                    .trim()
                                                    .isNotEmpty)
                                            ? otherSourceCtrl.text.trim()
                                            : selectedCampaign;
                                    final ok = await cubit.addWalkInLead(
                                      name: nameCtrl.text,
                                      phone: phoneCtrl.text,
                                      collegeBranchYear: collegeCtrl.text,
                                      campaign: effectiveCampaign,
                                    );
                                    if (ok && ctx.mounted) {
                                      Navigator.pop(ctx);
                                    } else if (ctx.mounted) {
                                      setSheetState(() {
                                        isSaving = false;
                                      });
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setSheetState(() {
                                        isSaving = false;
                                        lookupFeedback = e
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                        lookupFoundDuplicate = true;
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD45107),
                            disabledBackgroundColor: const Color(
                              0xFFD45107,
                            ).withValues(alpha: 0.6),
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
                          child: isSaving ? const SpinKitThreeBounce(
                                  color: Colors.white,
                                  size: 20,
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Save Walk-in Lead',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. "My Record" & Personal Performance Sheet
  // ---------------------------------------------------------------------------
  static void showMyRecordSheet(BuildContext context) {
    final user = context.read<HomeCubit>().state.user;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final state = ctx.watch<LeadsCubit>().state;
          final totalCalls = state.callRecords.length;
          final interestedCount = state.callRecords
              .where((r) => r.outcome.trim().toLowerCase() == 'interested')
              .length;
          final convertedCount = state.callRecords
              .where((r) => r.outcome.trim().toLowerCase() == 'converted')
              .length;

          return Dialog(
            backgroundColor: const Color(0xFFFFFFFF),
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 764.4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              padding: const EdgeInsets.fromLTRB(10, 24, 10, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Record & Performance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Gap(4),
                            Text(
                              '${user.displayName} · ${user.roleLabel} · Joined ${user.joinedLabel}\nPermanent read-only call log',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.35,
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
              const Gap(18),
              // Responsive metric boxes with 10 left/right padding, height 84, gap 4px, radius 16
              Row(
                children: [
                  Expanded(
                    child: _buildRecordMetricBox(
                      value: '$totalCalls',
                      label: 'Total Calls',
                      valueColor: const Color(0xFF0F172A),
                      bgColor: const Color(0xFFF3E8FF).withValues(alpha: 0.55),
                    ),
                  ),
                  const Gap(4),
                  Expanded(
                    child: _buildRecordMetricBox(
                      value: '$interestedCount',
                      label: 'Interested',
                      valueColor: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFE0F2FE),
                    ),
                  ),
                  const Gap(4),
                  Expanded(
                    child: _buildRecordMetricBox(
                      value: '$convertedCount',
                      label: 'Converted',
                      valueColor: const Color(0xFF16A34A),
                      bgColor: const Color(0xFFDCFCE7),
                    ),
                  ),
                ],
              ),
              const Gap(22),
              const Text(
                'RECENT PERMANENT CALL LOGS (READ-ONLY)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.callRecords.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 16,
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                Icons.call_end_outlined,
                                size: 36,
                                color: Colors.grey.shade400,
                              ),
                              const Gap(8),
                              Text(
                                'No call records logged yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                'Calls you make will be recorded here with duration and outcome.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...state.callRecords.map(
                          (rec) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${rec.leadName} · ${rec.outcome}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const Gap(8),
                                    Text(
                                      '${rec.duration.isNotEmpty ? "${rec.duration} · " : ""}${rec.timestamp}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(4),
                                Text(
                                  rec.notes.isNotEmpty
                                      ? rec.notes
                                      : 'Logged ${rec.outcome} outcome',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);
}

  static Widget _buildRecordMetricBox({
    required String value,
    required String label,
    required Color valueColor,
    required Color bgColor,
  }) {
    return SizedBox(
      height: 84,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ),
            const Gap(4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

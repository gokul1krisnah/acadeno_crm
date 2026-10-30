import 'package:acadeno_crm/shared/widgets/college_selector_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/ui/alerts/application/alerts_cubit.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_cubit.dart';
import 'package:acadeno_crm/ui/home/application/home_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';

class LeadCallSheets {
  // ---------------------------------------------------------------------------
  // 1. Mandatory Call & Outcome Sheet (FR-3.1–3.5 & FR-5.3–5.6 Enrolment Form)
  // ---------------------------------------------------------------------------
  static void showCallAndOutcomeSheet(
    BuildContext context, {
    String? leadId,
    required String leadName,
    String maskedPhone = '98470 •••11',
    String collegeInfo = 'NIT Calicut · CSE · 3rd yr',
    String campaignTag = 'AI & ML Workshop',
  }) {
    final cubit = context.read<LeadsCubit>();
    final followUpsCubit = context.read<FollowUpsCubit>();
    final alertsCubit = context.read<AlertsCubit>();
    final user = context.read<HomeCubit>().state.user;
    String selectedOutcome = 'Interested';
    String selectedFollowUpSlot = 'Tomorrow · 10:30 AM';
    final durationCtrl = TextEditingController(text: '2m 18s');
    final notesCtrl = TextEditingController();

    // Enrolment form controllers (FR-5.3)
    String selectedCourse = 'AI & Machine Learning Workshop';
    String selectedBatch = '14 Nov Weekend Batch';
    String paymentMode = 'UPI';
    final feeCtrl = TextEditingController(text: '1499');
    final discountCtrl = TextEditingController(text: '0');
    final paidCtrl = TextEditingController(text: '1499');
    final receiptCtrl = TextEditingController(text: 'AC-2026-884');

    const outcomes = [
      'Interested',
      'Follow-up',
      'Converted',
      'No answer',
      'Busy',
      'Switched off',
      'Not interested',
      'Wrong number',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ctx.devicePadding.clamp(16.0, 24.0),
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final pad = ctx.devicePadding.clamp(16.0, 20.0);
              final discountVal = int.tryParse(discountCtrl.text.trim()) ?? 0;
              final needsManagerApproval = discountVal > 500;

              return Padding(
                padding: EdgeInsets.all(pad),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Soft-lock banner (FR-3.1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEDFD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_clock_outlined,
                              size: 16,
                              color: Color(0xFF4338CA),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lead claimed by ${user.firstName} · Dialing $maskedPhone (PR-2.3 masked)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3730A3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Lead Name & College
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  leadName,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$collegeInfo · $campaignTag',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: TextField(
                              controller: durationCtrl,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'MANDATORY CALL OUTCOME (FR-3.3)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: outcomes.map((o) {
                          final active = selectedOutcome == o;
                          return InkWell(
                            onTap: () =>
                                setSheetState(() => selectedOutcome = o),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF4338CA)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: active
                                      ? const Color(0xFF4338CA)
                                      : const Color(0xFFD0D5DD),
                                ),
                              ),
                              child: Text(
                                o,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? Colors.white
                                      : const Color(0xFF344054),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Follow-up Date/Time selector (FR-3.4)
                      if (selectedOutcome == 'Follow-up' ||
                          selectedOutcome == 'Interested') ...[
                        const SizedBox(height: 16),
                        const Text(
                          'FOLLOW-UP SCHEDULE (FR-3.4)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                'Today · 5:30 PM',
                                'Tomorrow · 10:30 AM',
                                'Thu, 29 Oct · 11:00 AM',
                                'Fri, 30 Oct · 4:00 PM',
                              ].map((slot) {
                                final active = selectedFollowUpSlot == slot;
                                return InkWell(
                                  onTap: () => setSheetState(
                                    () => selectedFollowUpSlot = slot,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(0xFFEEEDFD)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: active
                                            ? const Color(0xFF4338CA)
                                            : const Color(0xFFD0D5DD),
                                      ),
                                    ),
                                    child: Text(
                                      slot,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: active
                                            ? const Color(0xFF4338CA)
                                            : const Color(0xFF344054),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ],

                      // Auto-retry info banner for No answer (FR-4.3)
                      if (selectedOutcome == 'No answer') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF0E6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'FR-4.3: Auto-schedules retry within working hours (9 AM–8 PM IST), up to 3 tries. Does not overwrite prior Interested status (FR-3.5).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ],

                      // Enrolment Form when Converted is selected (FR-5.3–5.6)
                      if (selectedOutcome == 'Converted') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ENROLMENT & PAYMENT RECORD (FR-5.3)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: selectedCourse,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Course / Workshop',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'AI & Machine Learning Workshop',
                                    child: Text(
                                      'AI & Machine Learning Workshop',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Python Full Stack Bootcamp',
                                    child: Text('Python Full Stack Bootcamp'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Embedded & Robotics Add-on Course',
                                    child: Text(
                                      'Embedded & Robotics Add-on Course',
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setSheetState(() => selectedCourse = v);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: feeCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Course Fee (₹)',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: discountCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setSheetState(() {}),
                                      decoration: const InputDecoration(
                                        labelText: 'Discount (₹)',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: paidCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Paid Now (₹)',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (needsManagerApproval) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF0E6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'FR-5.4: Discount exceeds ₹500 limit — will be sent to Manager for approval before finalization.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9A3412),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: paymentMode,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Payment Mode',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'UPI',
                                          child: Text('UPI'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Bank Transfer',
                                          child: Text('Bank Transfer'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Cash Receipt',
                                          child: Text('Cash Receipt'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setSheetState(() => paymentMode = v);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: receiptCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Receipt #',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Batch: $selectedBatch · Credited to ${user.displayName} (FR-5.6)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Call notes / next step',
                          hintText:
                              'e.g. Send fee details for AI workshop on WhatsApp',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Release lock'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final result = await cubit.recordCallOutcome(
                                  leadId: leadId,
                                  leadName: leadName,
                                  outcome: selectedOutcome,
                                  duration: durationCtrl.text.trim(),
                                  notes: notesCtrl.text.trim(),
                                  courseEnrolled: selectedCourse,
                                  discountAmount: discountVal,
                                );
                                followUpsCubit.addFromCallOutcome(
                                  leadName: leadName,
                                  collegeInfo: result.collegeInfo,
                                  outcome: selectedOutcome,
                                  notes: notesCtrl.text.trim(),
                                  followUpTimeLabel: selectedFollowUpSlot,
                                );
                                if (result.needsDiscountApproval) {
                                  alertsCubit.addDiscountApprovalAlert(
                                    leadName: leadName,
                                    courseEnrolled: selectedCourse,
                                    discountAmount: discountVal,
                                  );
                                }
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4338CA),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Save Outcome & Unlock',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
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
  // 2. Lead Detail + Talking Points + WhatsApp Templates Sheet (FR-3.6, FR-5.1–5.2)
  // ---------------------------------------------------------------------------
  static void showLeadDetailSheet(
    BuildContext context, {
    required ExecutiveLeadItem lead,
  }) {
    final cubit = context.read<LeadsCubit>();
    final user = context.read<HomeCubit>().state.user;
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
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: EdgeInsets.all(ctx.devicePadding.clamp(16.0, 20.0)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top watermark notice (PR-1.3 & PR-2.4)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'WATERMARK: ${user.displayName.toUpperCase()} · ${user.uid.isEmpty ? 'EMP' : user.uid.substring(0, user.uid.length < 6 ? user.uid.length : 6).toUpperCase()} · NO COPY/SHARE (PR-2.4)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF98A2B3),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEEDFD),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          lead.initials,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3730A3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lead.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${lead.collegeInfo} · Phone: ${lead.maskedPhone}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!lead.isLocked)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            showCallAndOutcomeSheet(
                              context,
                              leadId: lead.id,
                              leadName: lead.name,
                              maskedPhone: lead.maskedPhone,
                              collegeInfo: lead.collegeInfo,
                              campaignTag: lead.campaignTag,
                            );
                          },
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4338CA),
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Campaign Talking Points (FR-5.2)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CAMPAIGN TALKING POINTS · ${lead.campaignTag.toUpperCase()} (FR-5.2)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4338CA),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...lead.talkingPoints.map(
                          (pt) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $pt',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF344054),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // WhatsApp Quick Replies (FR-5.1)
                  const Text(
                    'WHATSAPP QUICK REPLIES — PREFILLED TEMPLATES (FR-5.1)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF667085),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: templates.map((tpl) {
                      return OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          cubit.logWhatsAppTemplateSent(
                            leadName: lead.name,
                            templateTitle: tpl.$1,
                          );
                        },
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 14,
                          color: Color(0xFF15803D),
                        ),
                        label: Text(
                          tpl.$1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Lead Timeline (FR-3.6)
                  const Text(
                    'LEAD TIMELINE (FR-3.6)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF667085),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...lead.timeline.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $entry',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475467),
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

  // ---------------------------------------------------------------------------
  // 3. Phone Lookup & Add Walk-In Lead Sheet (FR-1.4 & PR-2.2)
  // ---------------------------------------------------------------------------
  static void showPhoneLookupAndWalkInSheet(BuildContext context) {
    final cubit = context.read<LeadsCubit>();
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final collegeCtrl = TextEditingController(
      text: 'MES College · CSE · 3rd yr',
    );
    String selectedCampaign = 'Direct Walk-in';
    String? lookupFeedback;
    bool lookupFoundDuplicate = false;

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
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final pad = ctx.devicePadding.clamp(16.0, 20.0);
              return Padding(
                padding: EdgeInsets.all(pad),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phone Lookup & Add Walk-in Lead (FR-1.4 / PR-2.2)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type a 10-digit phone number to check duplicates before saving. Lookups this hour: ${cubit.state.phoneLookupsThisHour}/40 (PR-2.5).',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: '10-digit mobile number *',
                                hintText: '9847011111',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
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
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Check'),
                          ),
                        ],
                      ),
                      if (lookupFeedback != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: lookupFoundDuplicate
                                ? const Color(0xFFFEF0E6)
                                : const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            lookupFeedback!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: lookupFoundDuplicate
                                  ? const Color(0xFF9A3412)
                                  : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Student Name *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CollegeSelectorField(
                        controller: collegeCtrl,
                        label: 'College · Branch · Year',
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCampaign,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Source Event / Consent',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Direct Walk-in',
                            child: Text('Direct Walk-in'),
                          ),
                          DropdownMenuItem(
                            value: 'AI Webinar',
                            child: Text('AI Webinar'),
                          ),
                          DropdownMenuItem(
                            value: 'College visit',
                            child: Text('College visit'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setSheetState(() => selectedCampaign = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: lookupFoundDuplicate
                              ? null
                              : () async {
                                  final phoneErr = LeadPhoneValidator.validate(
                                    phoneCtrl.text,
                                  );
                                  if (nameCtrl.text.trim().isEmpty ||
                                      phoneErr != null) {
                                    setSheetState(() {
                                      lookupFeedback =
                                          phoneErr ??
                                          'Student name is required';
                                      lookupFoundDuplicate = true;
                                    });
                                    return;
                                  }
                                  await CollegeSelectorField.saveCollegeIfNew(
                                    collegeCtrl.text,
                                  );
                                  final ok = await cubit.addWalkInLead(
                                    name: nameCtrl.text,
                                    phone: phoneCtrl.text,
                                    collegeBranchYear: collegeCtrl.text,
                                    campaign: selectedCampaign,
                                  );
                                  if (ok && ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
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
                            'Save Walk-in Lead',
                            style: TextStyle(fontWeight: FontWeight.w700),
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
  // 4. "My Record" & Personal Performance Sheet (FR-6.2 & FR-6.3)
  // ---------------------------------------------------------------------------
  static void showMyRecordSheet(BuildContext context) {
    final state = context.read<LeadsCubit>().state;
    final user = context.read<HomeCubit>().state.user;

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Record & Performance (FR-6.2 / FR-6.3)',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${user.displayName} · ${user.roleLabel} · Joined ${user.joinedLabel} · Permanent read-only call log',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _miniPerfStat(
                        'Calls (Oct)',
                        '254',
                        const Color(0xFF4338CA),
                      ),
                      const SizedBox(width: 8),
                      _miniPerfStat(
                        'Interested',
                        '62',
                        const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      _miniPerfStat('Converted', '14', const Color(0xFF15803D)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'RECENT PERMANENT CALL LOGS (READ-ONLY · FR-3.7)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...state.callRecords
                      .take(6)
                      .map(
                        (rec) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                  const SizedBox(width: 8),
                                  Text(
                                    '${rec.duration} · ${rec.timestamp}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF667085),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                rec.notes,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475467),
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
        ),
      ),
    );
  }

  static Widget _miniPerfStat(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475467)),
            ),
          ],
        ),
      ),
    );
  }
}

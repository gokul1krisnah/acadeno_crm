import '../pages/lead_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:acadeno_crm/shared/widgets/college_selector_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_cubit.dart';
import 'package:acadeno_crm/ui/home/application/home_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';

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

  // 1. Mandatory Call & Outcome Sheet (Matches Exact UI)
  // ---------------------------------------------------------------------------
  static void showCallAndOutcomeSheet(
    BuildContext context, {
    String? leadId,
    required String leadName,
    String maskedPhone = '98470 •••11',
    String collegeInfo = 'NIT Calicut · CSE · 3rd yr',
    String campaignTag = 'AI & ML Workshop',
    String initialDuration = '0s',
    String? course,
    String? fee,
  }) {
    final cubit = context.read<LeadsCubit>();
    final followUpsCubit = context.read<FollowUpsCubit>();
    String selectedOutcome = 'Follow-up';
    String selectedFollowUpSlot = 'Tomorrow 10:30';
    final notesCtrl = TextEditingController();

    const outcomeRows = [
      [('Interested', Color(0xFF15803D)), ('Follow-up', Color(0xFFEF8144))],
      [('No answer', Color(0xFF64748B)), ('Busy', Color(0xFF64748B))],
      [('Switched off', Color(0xFF64748B)), ('Converted', Color(0xFF4338CA))],
      [
        ('Not interested', Color(0xFFDC2626)),
        ('Wrong number', Color(0xFF64748B)),
      ],
    ];

    final displayDuration = initialDuration.trim().isNotEmpty
        ? initialDuration.trim()
        : '0s';

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
                      // Header Row: Title & Subtitle + Close button (exact same as Add Walk-in Lead)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Log Call Outcome',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    height: 27.5 / 20,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$leadName · Ended in $displayDuration\n$collegeInfo',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                    height: 1.35,
                                    color: const Color(0xFF64748B),
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

                      // Title: How did the call go?
                      const Text(
                        'How did the call go?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2x4 Outcomes Grid
                              ...outcomeRows.map((row) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: row.map((item) {
                                      final name = item.$1;
                                      final dotColor = item.$2;
                                      final isSelected =
                                          selectedOutcome == name;
                                      final selectedBgColor = dotColor;

                                      return Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: item == row.first ? 5 : 0,
                                            left: item == row.last ? 5 : 0,
                                          ),
                                          child: InkWell(
                                            onTap: () {
                                              setSheetState(
                                                () => selectedOutcome = name,
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Container(
                                              height: 46,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? selectedBgColor
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? selectedBgColor
                                                      : const Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? Colors.white
                                                          : dotColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 9),
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF0F172A,
                                                              ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }),

                              const SizedBox(height: 6),

                              // Follow up when?
                              const Text(
                                'Follow up when?',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),

                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildSlotPill(
                                    label: 'Today 5 PM',
                                    selected:
                                        selectedFollowUpSlot == 'Today 5 PM',
                                    onTap: () => setSheetState(
                                      () => selectedFollowUpSlot = 'Today 5 PM',
                                    ),
                                  ),
                                  _buildSlotPill(
                                    label: 'Tomorrow 10:30',
                                    selected:
                                        selectedFollowUpSlot ==
                                        'Tomorrow 10:30',
                                    onTap: () => setSheetState(
                                      () => selectedFollowUpSlot =
                                          'Tomorrow 10:30',
                                    ),
                                  ),
                                  _buildSlotPill(
                                    label: 'In 3 days',
                                    selected:
                                        selectedFollowUpSlot == 'In 3 days',
                                    onTap: () => setSheetState(
                                      () => selectedFollowUpSlot = 'In 3 days',
                                    ),
                                  ),
                                  _buildSlotPill(
                                    label:
                                        selectedFollowUpSlot.startsWith(
                                              'Pick',
                                            ) ||
                                            [
                                              'Today 5 PM',
                                              'Tomorrow 10:30',
                                              'In 3 days',
                                            ].contains(selectedFollowUpSlot)
                                        ? 'Pick date...'
                                        : selectedFollowUpSlot,
                                    selected: ![
                                      'Today 5 PM',
                                      'Tomorrow 10:30',
                                      'In 3 days',
                                    ].contains(selectedFollowUpSlot),
                                    onTap: () async {
                                      final now = DateTime.now();
                                      final pickedDate = await showDatePicker(
                                        context: ctx,
                                        initialDate: now.add(
                                          const Duration(days: 1),
                                        ),
                                        firstDate: now,
                                        lastDate: now.add(
                                          const Duration(days: 90),
                                        ),
                                      );
                                      if (pickedDate != null && ctx.mounted) {
                                        final pickedTime = await showTimePicker(
                                          context: ctx,
                                          initialTime: const TimeOfDay(
                                            hour: 10,
                                            minute: 30,
                                          ),
                                        );
                                        if (pickedTime != null && ctx.mounted) {
                                          final dt = DateTime(
                                            pickedDate.year,
                                            pickedDate.month,
                                            pickedDate.day,
                                            pickedTime.hour,
                                            pickedTime.minute,
                                          );
                                          setSheetState(() {
                                            selectedFollowUpSlot = DateFormat(
                                              'EEE, d MMM · h:mm a',
                                            ).format(dt);
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Notes (optional)
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Notes ',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    TextSpan(
                                      text: '(optional)',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              TextField(
                                controller: notesCtrl,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Wants fee details and batch timings. Prefers WhatsApp.',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4F46E5),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Save & next call Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    try {
                                      final result = await cubit
                                          .recordCallOutcome(
                                            leadId: leadId,
                                            leadName: leadName,
                                            outcome: selectedOutcome,
                                            duration: displayDuration,
                                            notes: notesCtrl.text.trim(),
                                            followUpTime: selectedFollowUpSlot,
                                          );
                                      followUpsCubit.addFromCallOutcome(
                                        leadName: leadName,
                                        collegeInfo: result.collegeInfo,
                                        outcome: selectedOutcome,
                                        notes: notesCtrl.text.trim(),
                                        followUpTimeLabel: selectedFollowUpSlot,
                                      );
                                    } catch (e) {
                                      debugPrint('recordCallOutcome error: $e');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Save & next call',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
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

  static Widget _buildSlotPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Lead Detail Page Navigation (Matches Exact First Image UI)
  // ---------------------------------------------------------------------------
  static void showLeadDetailSheet(
    BuildContext context, {
    required ExecutiveLeadItem lead,
  }) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (ctx) => LeadDetailPage(lead: lead)));
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
                    const SizedBox(height: 16),
                    const Text(
                      'WhatsApp Quick Templates',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a pre-filled template to send to ${lead.name}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...templates.map((tpl) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            cubit.logWhatsAppTemplateSent(
                              leadName: lead.name,
                              templateTitle: tpl.$1,
                            );
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
                                const SizedBox(width: 12),
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
                                      const SizedBox(height: 2),
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
    String selectedCollege = 'MES College';
    String selectedCampaign = 'Direct Walk-in';
    String? lookupFeedback;
    bool lookupFoundDuplicate = false;

    const knownColleges = [
      'MES College',
      'NIT Calicut',
      'Farook College',
      'GEC Kozhikode',
      'KMCT College of Engineering',
      'Government Polytechnic',
    ];

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
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 18),

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
                          const SizedBox(width: 10),
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
                        const SizedBox(height: 12),
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
                              const SizedBox(width: 8),
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
                      const SizedBox(height: 14),

                      // Student Name (Figma spec: width 343, height 54, borderRadius 12, borderWidth 1, padding 16)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: TextField(
                          controller: nameCtrl,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Student Name *',
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
                      const SizedBox(height: 14),

                      // College Selection Label
                      Text(
                        'College Selection',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // College Selection Dropdown (Figma styling: height 54, borderRadius 12, padding 16)
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
                            value: selectedCollege,
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
                            items: knownColleges.map((col) {
                              return DropdownMenuItem<String>(
                                value: col,
                                child: Text(col),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() {
                                  selectedCollege = val;
                                  final parts = collegeCtrl.text.split('·');
                                  final branchYear = parts.length > 1
                                      ? ' ·${parts.sublist(1).join('·')}'
                                      : ' · CSE · 3rd yr';
                                  collegeCtrl.text = '$val$branchYear';
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // COLLEGE · BRANCH · YEAR Label
                      Text(
                        'COLLEGE · BRANCH · YEAR',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Editable College · Branch · Year text input (height 54, borderRadius 12)
                      SizedBox(
                        height: 54,
                        child: TextField(
                          controller: collegeCtrl,
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
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can freely edit or fine-tune college, bran...',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Source Event / Consent Label
                      Text(
                        'Source Event / Consent',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Source Event Dropdown (height 54, borderRadius 12, padding 16)
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
                            value: selectedCampaign,
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
                              DropdownMenuItem(
                                value: 'Campus Drive',
                                child: Text('Campus Drive'),
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
                      const SizedBox(height: 20),

                      // Save Button (Figma spec: width 343, height 44, borderRadius 16, padding-top 14.5, padding-bottom 15.5)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
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
                          child: FittedBox(
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
    final state = context.read<LeadsCubit>().state;
    final user = context.read<HomeCubit>().state.user;

    final totalCalls = state.callRecords.length;
    final interestedCount = state.callRecords
        .where((r) => r.outcome.trim().toLowerCase() == 'interested')
        .length;
    final convertedCount = state.callRecords
        .where((r) => r.outcome.trim().toLowerCase() == 'converted')
        .length;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
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
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
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
              const SizedBox(height: 18),
              // Fixed-dimension metric boxes: width 99.333, height 84, gap 4px, radius 16
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRecordMetricBox(
                        value: '$totalCalls',
                        label: 'Total Calls',
                        valueColor: const Color(0xFF0F172A),
                        bgColor: const Color(0xFFF3E8FF).withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 4),
                      _buildRecordMetricBox(
                        value: '$interestedCount',
                        label: 'Interested',
                        valueColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFE0F2FE),
                      ),
                      const SizedBox(width: 4),
                      _buildRecordMetricBox(
                        value: '$convertedCount',
                        label: 'Converted',
                        valueColor: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFDCFCE7),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'RECENT PERMANENT CALL LOGS (READ-ONLY)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'RECENT PERMANENT CALL LOGS (READ-ONLY)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                              const SizedBox(height: 8),
                              Text(
                                'No call records logged yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                                    const SizedBox(width: 8),
                                    Text(
                                      '${rec.duration.isNotEmpty ? "${rec.duration} · " : ""}${rec.timestamp}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
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
      width: 99.33333587646484,
      height: 84,
      child: Container(
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
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
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

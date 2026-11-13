import 'dart:ui' show ImageFilter;
import '../pages/lead_detail_page.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:acadeno_crm/shared/theme/app_svgs.dart';
import 'package:acadeno_crm/shared/widgets/college_selector_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';

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

  // 1. Mandatory Call & Outcome Sheet (Matches Exact Figma UI node-id=1643-2)
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
    HomeCubit? homeCubit;
    try {
      homeCubit = context.read<HomeCubit>();
    } catch (_) {
      homeCubit = null;
    }

    final greeting = homeCubit?.state.greeting ?? 'Good afternoon';
    final firstName = (homeCubit?.state.user.firstName.isNotEmpty ?? false)
        ? homeCubit!.state.user.firstName
        : 'Test';
    final todayLabel = (homeCubit?.state.todayLabel.isNotEmpty ?? false)
        ? homeCubit!.state.todayLabel
        : DateFormat('EEE, d MMM').format(DateTime.now());

    String selectedOutcome = 'Follow-up';
    const String selectedFollowUpSlot = 'Tomorrow 10:30';
    final notesCtrl = TextEditingController();

    const outcomeRows = [
      [('Interested', Color(0xFF22C55E)), ('Follow-up', Color(0xFFE8612D))],
      [('No answer', Color(0xFF1E3A8A)), ('Busy', Color(0xFF3730A3))],
      [('Switched off', Color(0xFF1E293B)), ('Converted', Color(0xFF2563EB))],
      [
        ('Not interested', Color(0xFFEF4444)),
        ('Wrong number', Color(0xFF6B7280)),
      ],
    ];

    final displayDuration = initialDuration.trim().isNotEmpty
        ? initialDuration.trim()
        : '7s';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      elevation: 0,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height,
          width: double.infinity,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 512),
                child: Column(
                  children: [
                    // Top Blurred Header (Figma node 1643:31 + 1643:116, height 96px)
                    SizedBox(
                      height: 96,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        AppImages.acadenoALogo,
                                        width: 38,
                                        height: 38,
                                        fit: BoxFit.contain,
                                      ),
                                      const Gap(12),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$greeting, $firstName',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF111827),
                                                letterSpacing: -0.0195,
                                                height: 28 / 20,
                                              ),
                                            ),
                                            Text(
                                              todayLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF6B7280),
                                                height: 16 / 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFF3F4F6),
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: SvgPicture.asset(
                                    AppSvgs.logout,
                                    width: 16,
                                    height: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 2.2,
                                  sigmaY: 2.2,
                                ),
                                child: Container(
                                  color: const Color(0x33D9D9D9),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Post Call Feedback Screen (Figma node 1606:1689 / 1606:1609)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: StatefulBuilder(
                          builder: (ctx, setSheetState) {
                            return SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.viewInsetsOf(ctx).bottom + 32,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // "Follow-ups" Title (Figma node 1606:1625)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      'Follow-ups',
                                      style: GoogleFonts.inter(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 36 / 30,
                                      ),
                                    ),
                                  ),

                                  // Call ended card (Figma node 1606:1628 -> 1606:1629)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      32,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1C1C1C),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Call ended • $displayDuration',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF9CA3AF),
                                              height: 20 / 14,
                                            ),
                                          ),
                                          const Gap(4),
                                          Text(
                                            leadName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              height: 32 / 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Light Rounded Sheet (Figma node 1606:1635)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      16,
                                      24,
                                      28,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(32),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Top Drag Handle (Figma node 1606:1636)
                                        Center(
                                          child: Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD1D5DB),
                                              borderRadius:
                                                  BorderRadius.circular(9999),
                                            ),
                                          ),
                                        ),
                                        const Gap(24),

                                        // Heading 3: How did the call go? (Figma node 1606:1637)
                                        Text(
                                          'How did the call go?',
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF111827),
                                            height: 28 / 20,
                                          ),
                                        ),
                                        const Gap(24),

                                        // 2x4 Outcomes Grid (Figma node 1606:1639)
                                        LayoutBuilder(
                                          builder: (context, gridConstraints) {
                                            final availW =
                                                gridConstraints.maxWidth;
                                            final colGap = availW >= 420
                                                ? 48.0
                                                : (availW * 0.06).clamp(
                                                    12.0,
                                                    48.0,
                                                  );
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: List.generate(outcomeRows.length, (
                                                rowIdx,
                                              ) {
                                                final row = outcomeRows[rowIdx];
                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom:
                                                        rowIdx <
                                                            outcomeRows.length -
                                                                1
                                                        ? 14
                                                        : 0,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 201,
                                                        child: _buildOutcomeButton(
                                                          name: row[0].$1,
                                                          dotColor: row[0].$2,
                                                          isSelected:
                                                              selectedOutcome ==
                                                              row[0].$1,
                                                          dotToTextGap:
                                                              row[0].$1 ==
                                                                  'Not interested'
                                                              ? 24.89
                                                              : 12.0,
                                                          onTap: () {
                                                            setSheetState(
                                                              () =>
                                                                  selectedOutcome =
                                                                      row[0].$1,
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      SizedBox(width: colGap),
                                                      Expanded(
                                                        flex: 190,
                                                        child: _buildOutcomeButton(
                                                          name: row[1].$1,
                                                          dotColor: row[1].$2,
                                                          isSelected:
                                                              selectedOutcome ==
                                                              row[1].$1,
                                                          dotToTextGap: 12.0,
                                                          onTap: () {
                                                            setSheetState(
                                                              () =>
                                                                  selectedOutcome =
                                                                      row[1].$1,
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            );
                                          },
                                        ),

                                        const Gap(32),

                                        // Notes (optional) (Figma node 1606:1677)
                                        Text(
                                          'Notes (optional)',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF374151),
                                            height: 24 / 16,
                                          ),
                                        ),
                                        const Gap(16),

                                        Container(
                                          width: double.infinity,
                                          constraints: const BoxConstraints(
                                            minHeight: 100,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x0D000000),
                                                blurRadius: 1,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            15,
                                            16,
                                            16,
                                          ),
                                          child: TextField(
                                            controller: notesCtrl,
                                            maxLines: 3,
                                            minLines: 2,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF4B5563),
                                              height: 24.38 / 15,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                              hintText:
                                                  'Wants fee details and batch timings.\nPrefers WhatsApp.',
                                              hintStyle: GoogleFonts.inter(
                                                color: const Color(0xFF4B5563),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                                height: 24.38 / 15,
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                            ),
                                          ),
                                        ),
                                        const Gap(24),

                                        // Save Button (Figma node 1606:1683)
                                        SizedBox(
                                          width: double.infinity,
                                          height: 60,
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
                                                      notes: notesCtrl.text
                                                          .trim(),
                                                      followUpTime:
                                                          selectedFollowUpSlot,
                                                    );
                                                followUpsCubit
                                                    .addFromCallOutcome(
                                                      leadName: leadName,
                                                      collegeInfo:
                                                          result.collegeInfo,
                                                      outcome: selectedOutcome,
                                                      notes: notesCtrl.text
                                                          .trim(),
                                                      followUpTimeLabel:
                                                          selectedFollowUpSlot,
                                                    );
                                                if (context.mounted) {
                                                  SnackBarAlert.showToast(
                                                    context: context,
                                                    message:
                                                        'Outcome saved for $leadName',
                                                  );
                                                }
                                              } catch (e) {
                                                debugPrint(
                                                  'recordCallOutcome error: $e',
                                                );
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFE8612D,
                                              ),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              'Save',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 0.0879,
                                                height: 28 / 18,
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildOutcomeButton({
    required String name,
    required Color dotColor,
    required bool isSelected,
    required double dotToTextGap,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8612D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE8612D)
                : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 6,
                    offset: Offset(0, 4),
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                    spreadRadius: -2,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : dotColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: dotToTextGap),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                  height: 24 / 16,
                ),
              ),
            ),
          ],
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
    String selectedCampaign = 'Direct Walk-in';
    String? lookupFeedback;
    bool lookupFoundDuplicate = false;

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

                      // Source Event / Consent Label
                      Text(
                        'Source Event / Consent',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const Gap(6),
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
                      const Gap(20),

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

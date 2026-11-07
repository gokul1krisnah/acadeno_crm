import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/app_phone_call_service.dart';
import '../../../follow_ups/application/follow_ups_cubit.dart';
import '../../data/model/lead_models.dart';
import '../widgets/lead_call_sheets.dart';

class LeadDetailPage extends StatefulWidget {
  final ExecutiveLeadItem lead;

  const LeadDetailPage({super.key, required this.lead});

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  String? _rescheduledFollowUp;

  void _onReschedule(String leadId, String currentSlot) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 30),
      );
      if (pickedTime != null && mounted) {
        final dt = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        final formatted = DateFormat('EEE, d MMM · h:mm a').format(dt);
        setState(() {
          _rescheduledFollowUp = formatted;
        });

        try {
          final entry = 'Today · Follow-up rescheduled to $formatted';
          await FirebaseFirestore.instance
              .collection('leads')
              .doc(leadId)
              .update({
                'followUpTime': formatted,
                'timeline': FieldValue.arrayUnion([entry]),
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {}

        if (mounted) {
          context.read<FollowUpsCubit>().addFromCallOutcome(
            leadName: widget.lead.name,
            collegeInfo: widget.lead.collegeInfo,
            outcome: 'Follow-up',
            notes: 'Rescheduled to $formatted',
            followUpTimeLabel: formatted,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up rescheduled to $formatted'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFFEF8144),
            ),
          );
        }
      }
    }
  }

  void _openWhatsApp(String phoneToUse) async {
    final rawPhone = phoneToUse.isNotEmpty
        ? phoneToUse
        : (widget.lead.fullPhone.isNotEmpty
              ? widget.lead.fullPhone
              : widget.lead.maskedPhone);
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = digits.length == 10 ? '91$digits' : digits;

    if (cleanPhone.isNotEmpty) {
      final uri = Uri.parse('https://wa.me/$cleanPhone');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          LeadCallSheets.showWhatsAppTemplatesSheet(context, lead: widget.lead);
        }
      }
    } else {
      LeadCallSheets.showWhatsAppTemplatesSheet(context, lead: widget.lead);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('leads')
          .doc(lead.id)
          .snapshots(),
      builder: (context, snapshot) {
        final snapData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data()
            : null;

        final rawFollowUp =
            (snapData != null
                    ? (snapData['followUpTime'] ??
                          snapData['follow_up_time'] ??
                          '')
                    : lead.followUpTime)
                .toString()
                .trim();
        final effectiveFollowUp =
            _rescheduledFollowUp ??
            (rawFollowUp.isNotEmpty ? rawFollowUp : 'Today, 10:30 AM');

        final liveNotes = (snapData != null ? (snapData['notes'] ?? '') : '')
            .toString()
            .trim();
        final liveCourse =
            (snapData != null ? (snapData['course'] ?? '') : lead.course)
                .toString()
                .trim();
        final liveCollegeInfo =
            (snapData != null
                    ? (snapData['collegeBranch'] ?? snapData['college'] ?? '')
                    : lead.collegeInfo)
                .toString()
                .trim();
        final effectiveCollegeInfo = liveCollegeInfo.isNotEmpty
            ? liveCollegeInfo
            : lead.collegeInfo;

        final liveCampaign =
            (snapData != null
                    ? (snapData['source'] ?? snapData['campaign'] ?? '')
                    : lead.campaignTag)
                .toString()
                .trim();
        final effectiveCampaign = liveCampaign.isNotEmpty
            ? liveCampaign
            : lead.campaignTag;

        final liveStatus =
            (snapData != null ? (snapData['status'] ?? '') : lead.statusTag)
                .toString()
                .trim();
        final effectiveStatus = liveStatus.isNotEmpty
            ? liveStatus
            : lead.statusTag;

        final livePhone =
            (snapData != null ? (snapData['phone'] ?? '') : lead.fullPhone)
                .toString()
                .trim();
        final effectivePhone = livePhone.isNotEmpty
            ? livePhone
            : (lead.fullPhone.isNotEmpty ? lead.fullPhone : lead.maskedPhone);

        final liveEmail = (snapData != null ? (snapData['email'] ?? '') : '')
            .toString()
            .trim();
        final effectiveEmail = liveEmail.isNotEmpty
            ? liveEmail
            : '${lead.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}@example.com';

        final rawInterests = snapData != null ? snapData['interests'] : null;
        final List<String> interests =
            rawInterests is Iterable && rawInterests.isNotEmpty
            ? rawInterests.map((e) => e.toString()).toList()
            : ['AI', 'Python', 'ML'];

        final rawTimeline = snapData != null ? snapData['timeline'] : null;
        final List<String> timelineList =
            rawTimeline is Iterable && rawTimeline.isNotEmpty
            ? rawTimeline.map((e) => e.toString()).toList()
            : (lead.timeline.isNotEmpty
                  ? lead.timeline
                  : [
                      if (effectiveStatus.isNotEmpty &&
                          effectiveStatus != 'New')
                        'Today · $effectiveStatus logged by current executive',
                      '24 Oct, 9:15 AM · Assigned to executive',
                      '12 Sep · Registered via ${effectiveCampaign.isNotEmpty ? effectiveCampaign : "Campus outreach"} (Consent recorded)',
                    ]);

        // Parse college and branch/year
        final parts = effectiveCollegeInfo
            .split('·')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final collegeDisplay = parts.isNotEmpty ? parts[0] : 'NIT Calicut';
        final branchYearDisplay = parts.length > 1
            ? parts.sublist(1).join(' · ')
            : 'CSE · 3rd year';

        final sourceDisplay = effectiveCampaign.isNotEmpty
            ? '$effectiveCampaign · 12 Sep'
            : 'AI Webinar · 12 Sep';

        final parsedTimeline = timelineList
            .map((t) => _parseTimelineEntry(t))
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 28,
                color: Color(0xFF0F172A),
              ),
            ),
            titleSpacing: 0,
            title: const Text(
              'Lead',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF0F172A),
                  size: 22,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'outcome') {
                    LeadCallSheets.showCallAndOutcomeSheet(
                      context,
                      leadId: lead.id,
                      leadName: lead.name,
                      maskedPhone: lead.maskedPhone,
                      collegeInfo: effectiveCollegeInfo,
                      campaignTag: effectiveCampaign,
                      course: liveCourse,
                    );
                  } else if (value == 'whatsapp_tpl') {
                    LeadCallSheets.showWhatsAppTemplatesSheet(
                      context,
                      lead: lead,
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'outcome',
                    child: Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 18,
                          color: Color(0xFFEF8144),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Log Call Outcome',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'whatsapp_tpl',
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: Color(0xFF15803D),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'WhatsApp Templates',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFF1F5F9)),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Lead Header Profile Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Avatar circle with Initials
                              Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3F37C9),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  lead.initials,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lead.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.3,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            effectiveStatus.isNotEmpty
                                                ? effectiveStatus
                                                : 'Follow-up',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFC2410C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      effectivePhone.isNotEmpty
                                          ? effectivePhone
                                          : '+91 98470 11111',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      AppPhoneCallService.instance.dialLead(
                                        context,
                                        lead,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.phone_outlined,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Call',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3F37C9),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openWhatsApp(effectivePhone),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 18,
                                      color: Color(0xFF0F172A),
                                    ),
                                    label: const Text(
                                      'WhatsApp',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
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

                    const SizedBox(height: 12),

                    // 2. Next Follow-Up Banner Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFED7AA),
                              ),
                            ),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              color: Color(0xFFC2410C),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'NEXT FOLLOW-UP · YOU',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFC2410C),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  effectiveFollowUp,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  liveNotes.isNotEmpty
                                      ? liveNotes
                                      : (liveCourse.isNotEmpty
                                            ? 'Send fee details for $liveCourse'
                                            : 'Send fee details for AI workshop'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                _onReschedule(lead.id, effectiveFollowUp),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFED7AA),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: const Text(
                                'Reschedule',
                                style: TextStyle(
                                  color: Color(0xFF9A3412),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3. Details Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DETAILS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'College',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      collegeDisplay,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Branch · Year',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      branchYearDisplay,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Source',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      sourceDisplay,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Email',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      effectiveEmail,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Interests',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: interests.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 4. Activity · Visible to whole team Card (Live Data from Firestore)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACTIVITY · VISIBLE TO WHOLE TEAM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...parsedTimeline.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final isLast = idx == parsedTimeline.length - 1;
                            return _ActivityTimelineItem(
                              dotColor: item.dotColor,
                              title: item.title,
                              timestamp: item.timestamp,
                              subtitle: item.subtitle,
                              note: item.note,
                              isLast: isLast,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static _ParsedTimelineEntry _parseTimelineEntry(String raw) {
    final trimmed = raw.trim();
    Color dotColor = const Color(0xFF64748B);
    String title = 'Activity logged';
    String timestamp = 'Today';
    String subtitle = '';
    String? note;

    String mainPart = trimmed;
    final parenMatch = RegExp(r'\((.*?)\)$').firstMatch(trimmed);
    if (parenMatch != null) {
      note = parenMatch.group(1)?.trim();
      mainPart = trimmed.substring(0, parenMatch.start).trim();
    }

    final parts = mainPart.split('·').map((s) => s.trim()).toList();
    if (parts.length >= 2) {
      timestamp = parts[0];
      final actionPart = parts.sublist(1).join(' · ').trim();
      final lower = actionPart.toLowerCase();

      if (lower.contains('follow-up') || lower.contains('callback')) {
        title = 'Follow-up · call back';
        dotColor = const Color(0xFFEA580C);
      } else if (lower.contains('no answer')) {
        title = 'No answer';
        dotColor = const Color(0xFF64748B);
      } else if (lower.contains('busy')) {
        title = 'Busy';
        dotColor = const Color(0xFF64748B);
      } else if (lower.contains('switched off')) {
        title = 'Switched off';
        dotColor = const Color(0xFF64748B);
      } else if (lower.contains('converted')) {
        title = 'Converted';
        dotColor = const Color(0xFF15803D);
      } else if (lower.contains('interested')) {
        title = 'Interested';
        dotColor = const Color(0xFF15803D);
      } else if (lower.contains('rescheduled')) {
        title = 'Follow-up rescheduled';
        dotColor = const Color(0xFFEA580C);
      } else if (lower.contains('assigned')) {
        title = actionPart;
        dotColor = const Color(0xFF4338CA);
      } else {
        title = actionPart;
      }

      if (actionPart.toLowerCase().contains('logged by')) {
        final byIdx = actionPart.toLowerCase().indexOf('logged by');
        subtitle = actionPart.substring(byIdx + 9).trim();
        if (subtitle.contains('(')) {
          subtitle = subtitle.split('(').first.trim();
        }
      } else if (actionPart.toLowerCase().contains('by ')) {
        final byIdx = actionPart.toLowerCase().indexOf('by ');
        subtitle = actionPart.substring(byIdx).trim();
      }
    } else {
      final lower = mainPart.toLowerCase();
      if (lower.contains('registered') ||
          lower.contains('created') ||
          lower.contains('direct visit')) {
        title = 'Lead created';
        dotColor = const Color(0xFF2563EB);
        subtitle = mainPart;
        timestamp = '12 Sep';
      } else if (lower.contains('assigned')) {
        title = mainPart;
        dotColor = const Color(0xFF4338CA);
      } else {
        title = mainPart;
      }
    }

    return _ParsedTimelineEntry(
      dotColor: dotColor,
      title: title,
      timestamp: timestamp,
      subtitle: subtitle,
      note: note,
    );
  }
}

class _ParsedTimelineEntry {
  final Color dotColor;
  final String title;
  final String timestamp;
  final String subtitle;
  final String? note;

  const _ParsedTimelineEntry({
    required this.dotColor,
    required this.title,
    required this.timestamp,
    required this.subtitle,
    this.note,
  });
}

class _ActivityTimelineItem extends StatelessWidget {
  final Color dotColor;
  final String title;
  final String timestamp;
  final String subtitle;
  final String? note;
  final bool isLast;

  const _ActivityTimelineItem({
    required this.dotColor,
    required this.title,
    required this.timestamp,
    required this.subtitle,
    this.note,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot and vertical line
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        timestamp,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  if (note != null && note!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Text(
                        note!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

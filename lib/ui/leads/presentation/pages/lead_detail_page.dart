import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/services/app_phone_call_service.dart';
import '../../../../core/services/firestore_stream_cache.dart';
import '../../../../shared/widgets/college_selector_field.dart';
import '../../../../shared/widgets/staff_watermark_overlay.dart';
import '../../../dashboard/presentation/widgets/figma_calendar_dialog.dart';
import '../../../follow_ups/application/follow_ups_cubit.dart';
import '../../../follow_ups/data/model/follow_up_time_helper.dart';
import '../../data/model/lead_models.dart';
import '../../data/sources/leads_rds.dart';
import '../widgets/lead_call_sheets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LeadDetailPage extends StatefulWidget {
  final ExecutiveLeadItem lead;

  const LeadDetailPage({super.key, required this.lead});

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  String? _rescheduledFollowUp;
  late final TextEditingController _studentNotesCtrl;
  late final TextEditingController _managerNotesCtrl;
  bool _studentNotesInitialized = false;
  bool _managerNotesInitialized = false;
  bool _isSavingStudentNotes = false;
  bool _isSavingManagerNotes = false;

  @override
  void initState() {
    super.initState();
    _studentNotesCtrl = TextEditingController(text: widget.lead.studentNotes);
    _managerNotesCtrl = TextEditingController(text: widget.lead.managerNotes);
  }

  @override
  void dispose() {
    _studentNotesCtrl.dispose();
    _managerNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStudentNotes() async {
    if (_isSavingStudentNotes) return;
    setState(() => _isSavingStudentNotes = true);
    final text = _studentNotesCtrl.text.trim();
    try {
      await FirebaseFirestore.instance
          .collection('leads')
          .doc(widget.lead.id)
          .set({
            'studentNotes': text,
            'notes': text,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      widget.lead.studentNotes = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student notes saved successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update student notes: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingStudentNotes = false);
    }
  }

  Future<void> _saveManagerNotes() async {
    if (_isSavingManagerNotes) return;
    setState(() => _isSavingManagerNotes = true);
    final text = _managerNotesCtrl.text.trim();
    try {
      await FirebaseFirestore.instance
          .collection('leads')
          .doc(widget.lead.id)
          .set({
            'managerNotes': text,
            'leadManagerNotes': text,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      widget.lead.managerNotes = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manager notes saved successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update manager notes: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingManagerNotes = false);
    }
  }

  void _onReschedule(String leadId, String currentSlot) async {
    final now = DateTime.now();
    final pickedDate = await showFigmaCalendarDialog(
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
        final formatted = LeadDateHelper.formatFollowUp(dt);
        setState(() {
          _rescheduledFollowUp = formatted;
        });

        try {
          final entry =
              '${LeadDateHelper.timelineStamp()} · Follow-up rescheduled to $formatted';
          await FirebaseFirestore.instance
              .collection('leads')
              .doc(leadId)
              .update({
                'followUpTime': formatted,
                'status': 'Follow-up',
                'isDone': false,
                'followUpDone': false,
                'isOverdue': false,
                'timeline': FieldValue.arrayUnion([entry]),
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {}

        if (mounted) {
          FollowUpsCubit? fuCubit;
          try {
            fuCubit = context.read<FollowUpsCubit>();
          } catch (_) {
            try {
              fuCubit = getIt<FollowUpsCubit>();
            } catch (_) {}
          }
          fuCubit?.addFromCallOutcome(
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

  void _openEditLeadDialog({
    required String currentName,
    required String currentEmail,
    required String currentCollege,
    required String currentCourse,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _EditLeadDialog(
        leadId: widget.lead.id,
        initialName: currentName,
        initialEmail: currentEmail,
        initialCollege: currentCollege,
        initialCourse: currentCourse,
      ),
    );
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
      stream: FirestoreStreamCache.instance.watchDoc('leads', lead.id),
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
        // Resolve the stored follow-up to a REAL date/time label. Legacy
        // relative text ("Today · 4:00 PM") is anchored to the day it was saved.
        String effectiveFollowUp;
        if (_rescheduledFollowUp != null) {
          final parsed = LeadDateHelper.parseStamp(
            _rescheduledFollowUp!,
            preferPast: false,
          );
          effectiveFollowUp = parsed != null
              ? LeadDateHelper.relativeStamp(parsed.dt)
              : _rescheduledFollowUp!;
        } else if (rawFollowUp.isEmpty) {
          effectiveFollowUp = 'Not scheduled';
        } else {
          final eval = FollowUpTimeHelper.evaluate(
            rawFollowUpTime: rawFollowUp,
            updatedAt: snapData?['updatedAt'],
          );
          effectiveFollowUp =
              '${LeadDateHelper.relativeStamp(eval.scheduledTime)}${eval.isOverdue ? ' · Overdue' : ''}';
        }

        final liveStudentNotes = (snapData != null
                ? (snapData['studentNotes'] ?? snapData['notes'] ?? snapData['additionalNotes'] ?? '')
                : '')
            .toString()
            .trim();
        if (!_studentNotesInitialized && snapData != null) {
          if (liveStudentNotes.isNotEmpty) {
            _studentNotesCtrl.text = liveStudentNotes;
          }
          _studentNotesInitialized = true;
        }

        final liveManagerNotes = (snapData != null
                ? (snapData['managerNotes'] ?? snapData['leadManagerNotes'] ?? '')
                : '')
            .toString()
            .trim();
        if (!_managerNotesInitialized && snapData != null) {
          if (liveManagerNotes.isNotEmpty) {
            _managerNotesCtrl.text = liveManagerNotes;
          }
          _managerNotesInitialized = true;
        }
        final liveName = (snapData != null
                ? (snapData['name'] ?? snapData['studentName'] ?? '')
                : lead.name)
            .toString()
            .trim();
        final isPlaceholderName = liveName.isEmpty ||
            liveName.toLowerCase() == 'unnamed' ||
            liveName.toLowerCase() == 'no name' ||
            liveName.toLowerCase() == 'assigned lead' ||
            RegExp(r'^l0*\d+$', caseSensitive: false).hasMatch(liveName);
        final effectiveName = liveName.isNotEmpty
            ? liveName
            : (lead.name.isNotEmpty ? lead.name : 'No Name');
        final effectiveInitials =
            LeadPhoneValidator.initialsFromName(effectiveName);

        final liveCourse =
            (snapData != null ? (snapData['course'] ?? '') : lead.course)
                .toString()
                .trim();
        final liveBatch =
            (snapData != null ? (snapData['batch'] ?? '') : lead.batch)
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
            : 'Not provided';

        final rawInterests = snapData != null ? snapData['interests'] : null;
        final List<String> interests =
            rawInterests is Iterable && rawInterests.isNotEmpty
            ? rawInterests.map((e) => e.toString()).toList()
            : (liveCourse.isNotEmpty ? [liveCourse] : ['Not specified']);

        // Real dates from Firestore timestamps (never hardcoded).
        DateTime? tsToDate(dynamic v) =>
            v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
        final createdAtDt = tsToDate(snapData?['createdAt']);
        final assignedAtDt = tsToDate(snapData?['assignedAt']);
        final legacyRefDt =
            tsToDate(snapData?['lastContactAt']) ??
            tsToDate(snapData?['lastCalledAt']) ??
            tsToDate(snapData?['updatedAt']);

        final rawTimeline = snapData != null ? snapData['timeline'] : null;
        final List<String> timelineList =
            rawTimeline is Iterable && rawTimeline.isNotEmpty
            ? rawTimeline.map((e) => e.toString()).toList()
            : (lead.timeline.isNotEmpty
                  ? lead.timeline
                  : [
                      if (assignedAtDt != null)
                        '${LeadDateHelper.timelineStamp(assignedAtDt)} · Assigned to ${snapData?['assignedToName'] ?? 'executive'}',
                      if (createdAtDt != null)
                        '${LeadDateHelper.timelineStamp(createdAtDt)} · Registered via ${effectiveCampaign.isNotEmpty ? effectiveCampaign : "Campus outreach"} (Consent recorded)',
                    ]);

        // Parse college / other and branch/year/details
        final parts = effectiveCollegeInfo
            .split(RegExp(r'[·\-]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final collegeDisplay = parts.isNotEmpty ? parts[0] : '—';
        final branchYearDisplay = parts.length > 1
            ? parts.sublist(1).join(' · ')
            : '—';
        final isOtherCategory = const [
          'plus two',
          'business development',
          'career switching',
          'skill upgrading',
        ].any((cat) => collegeDisplay.toLowerCase().startsWith(cat));

        final createdLabel = createdAtDt != null
            ? LeadDateHelper.relativeStamp(createdAtDt, withTime: false)
            : null;
        final sourceDisplay = effectiveCampaign.isNotEmpty
            ? (createdLabel != null
                  ? '$effectiveCampaign · $createdLabel'
                  : effectiveCampaign)
            : (createdLabel ?? '—');

        // Resolve every entry to a real date and show newest first. Legacy
        // entries saved as plain "Today" have no date of their own, so only
        // the newest one is anchored to the lead's last activity date; the
        // rest are labelled "Earlier" instead of showing a wrong date.
        var legacySeen = 0;
        final indexed = <({int i, _ParsedTimelineEntry e})>[];
        for (var i = 0; i < timelineList.length; i++) {
          final isLegacy = _isLegacyRelative(timelineList[i]);
          final useRef = isLegacy && legacySeen == 0;
          if (isLegacy) legacySeen++;
          indexed.add((
            i: i,
            e: _parseTimelineEntry(
              timelineList[i],
              legacyRef: useRef ? legacyRefDt : null,
              createdAt: createdAtDt,
            ),
          ));
        }
        indexed.sort((a, b) {
          final ad = a.e.sortDate;
          final bd = b.e.sortDate;
          if (ad != null && bd != null) {
            final c = bd.compareTo(ad);
            if (c != 0) return c;
          } else if (ad != null) {
            return -1;
          } else if (bd != null) {
            return 1;
          }
          return a.i.compareTo(b.i);
        });
        final parsedTimeline = indexed.map((x) => x.e).toList();

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
              'Lead Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Edit Details',
                icon: SvgPicture.asset(
                  'assets/svgs/list_edit.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF475569),
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: () => _openEditLeadDialog(
                  currentName: effectiveName,
                  currentEmail:
                      effectiveEmail == 'Not provided' ? '' : effectiveEmail,
                  currentCollege: effectiveCollegeInfo,
                  currentCourse: liveCourse,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF475569),
                  size: 20,
                ),
                onSelected: (val) async {
                  if (val == 'opt_out') {
                    await LeadsRds().markLeadOptedOut(lead.id, optedOut: true);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$effectiveName marked "Do Not Contact" (DPDP Opt-out).',
                        ),
                        backgroundColor: const Color(0xFF0F172A),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem<String>(
                    value: 'opt_out',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 18,
                          color: Color(0xFFDC2626),
                        ),
                        Gap(10),
                        Text(
                          'Do Not Contact (DPDP Opt-out)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFF1F5F9)),
            ),
          ),
          body: SelectionContainer.disabled(
            child: StaffWatermarkOverlay(
              child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Lead Header Profile Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF1F5F9),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Avatar circle with Initials
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEEF2FF),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  effectiveInitials,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4F46E5),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const Gap(14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            isPlaceholderName
                                                ? 'No Name'
                                                : effectiveName,
                                            style: TextStyle(
                                              fontSize: 17.5,
                                              fontWeight: FontWeight.w600,
                                              color: isPlaceholderName
                                                  ? const Color(0xFFD97706)
                                                  : const Color(0xFF0F172A),
                                              letterSpacing: -0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Gap(8),
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
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFC2410C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Gap(3),
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
                          const Gap(16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final callingLead = lead.copyWith(
                                        name: effectiveName,
                                        initials: effectiveInitials,
                                        fullPhone: effectivePhone,
                                        maskedPhone:
                                            lead.maskedPhone.isNotEmpty
                                                ? lead.maskedPhone
                                                : effectivePhone,
                                        collegeInfo: effectiveCollegeInfo,
                                        campaignTag: effectiveCampaign,
                                        statusTag: effectiveStatus,
                                        followUpTime: effectiveFollowUp,
                                        course:
                                            liveCourse.isNotEmpty
                                                ? liveCourse
                                                : lead.course,
                                        batch:
                                            liveBatch.isNotEmpty
                                                ? liveBatch
                                                : lead.batch,
                                        fee:
                                            (snapData != null
                                                    ? (snapData['fee'] ?? '')
                                                    : lead.fee)
                                                .toString()
                                                .trim(),
                                      );
                                      AppPhoneCallService.instance.dialLead(
                                        context,
                                        callingLead,
                                      );
                                    },
                                    icon: const Icon(
                                      CupertinoIcons.phone_fill,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Call',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF8144),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Gap(12),
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
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'WhatsApp',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
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

                    const Gap(12),

                    // 2. Converted Enrolment Banner Card (when Converted or Course/Batch present)
                    if (effectiveStatus == 'Converted' || liveCourse.isNotEmpty || liveBatch.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFBBF7D0),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0616A34A),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF86EFAC),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 18,
                                  ),
                                ),
                                const Gap(10),
                                const Expanded(
                                  child: Text(
                                    'CONVERTED ENROLMENT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF166534),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Enrolled',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Course / Workshop',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const Gap(2),
                                      Text(
                                        liveCourse.isNotEmpty ? liveCourse : '—',
                                        style: const TextStyle(
                                          fontSize: 14,
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
                                        'Batch',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const Gap(2),
                                      Text(
                                        liveBatch.isNotEmpty ? liveBatch : '—',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                    ],

                    // 2b. Next Follow-Up Banner Card
                    if (effectiveStatus != 'Converted' || effectiveFollowUp != 'Not scheduled') ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFED7AA).withValues(alpha: 0.8),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06C2410C),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
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
                              CupertinoIcons.calendar,
                              color: Color(0xFFC2410C),
                              size: 20,
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'NEXT FOLLOW-UP · YOU',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFC2410C),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  effectiveFollowUp,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  liveManagerNotes.isNotEmpty
                                      ? 'Manager: $liveManagerNotes'
                                      : (liveStudentNotes.isNotEmpty
                                            ? liveStudentNotes
                                            : (liveCourse.isNotEmpty
                                            ? 'Interested in $liveCourse'
                                            : 'No notes added')),
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
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Reschedule',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: Color(0xFF9A3412),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    ],

                    // 3. Details Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF1F5F9),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const Gap(14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'College / Other',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const Gap(3),
                                    Text(
                                      collegeDisplay,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
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
                                    Text(
                                      isOtherCategory
                                          ? 'Details'
                                          : 'Branch · Year',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const Gap(3),
                                    Text(
                                      branchYearDisplay,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Gap(14),
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
                                    const Gap(3),
                                    Text(
                                      sourceDisplay,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
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
                                    const Gap(3),
                                    Text(
                                      effectiveEmail,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (liveCourse.isNotEmpty || liveBatch.isNotEmpty || effectiveStatus == 'Converted') ...[
                            const Gap(14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Course / Workshop',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const Gap(3),
                                      Text(
                                        liveCourse.isNotEmpty ? liveCourse : '—',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
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
                                        'Batch',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const Gap(3),
                                      Text(
                                        liveBatch.isNotEmpty ? liveBatch : '—',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Gap(14),
                          const Text(
                            'Interests',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const Gap(8),
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
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const Gap(12),

                    // 4. Activity · Visible to whole team Card (Live Data from Firestore)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF1F5F9),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACTIVITY · VISIBLE TO WHOLE TEAM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const Gap(16),
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
                          const Gap(16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const Gap(14),
                          // 1. STUDENT NOTES (Inquiries & Requirements)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 15,
                                    color: Color(0xFF2563EB),
                                  ),
                                  Gap(6),
                                  Text(
                                    'STUDENT NOTES',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E40AF),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isSavingStudentNotes)
                                const SpinKitThreeBounce(
                                  color: Color(0xFF2563EB),
                                  size: 14,
                                )
                              else
                                InkWell(
                                  onTap: _saveStudentNotes,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Color(0xFF2563EB),
                                        ),
                                        Gap(4),
                                        Text(
                                          'Save Student Note',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Gap(8),
                          TextField(
                            controller: _studentNotesCtrl,
                            maxLines: 3,
                            minLines: 2,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Enter student inquiry details, background, or course questions...',
                              hintStyle: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const Gap(16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const Gap(14),

                          // 2. MANAGER NOTES (Lead Manager's Noting & Remarks)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.rate_review_outlined,
                                    size: 15,
                                    color: Color(0xFFD45107),
                                  ),
                                  Gap(6),
                                  Text(
                                    'MANAGER NOTES',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD45107),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isSavingManagerNotes)
                                const SpinKitThreeBounce(
                                  color: Color(0xFFD45107),
                                  size: 14,
                                )
                              else
                                InkWell(
                                  onTap: _saveManagerNotes,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Color(0xFFD45107),
                                        ),
                                        Gap(4),
                                        Text(
                                          'Save Manager Note',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFD45107),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Gap(8),
                          TextField(
                            controller: _managerNotesCtrl,
                            maxLines: 3,
                            minLines: 2,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Lead manager notes, review comments, or assignment directions...',
                              hintStyle: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF94A3B8),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD45107),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(24),
                  ],
                ),
              ),
            ),
          ),
            ),
          ),
        );
      },
    );
  }

  /// True for old entries saved as plain "Today · ..." / "Yesterday · ..."
  /// (no real date inside). "Today, 5 Nov · ..." carries a date, so it is not.
  static bool _isLegacyRelative(String raw) {
    final first = raw.split('·').first.trim().toLowerCase();
    if (!(first.startsWith('today') || first.startsWith('yesterday'))) {
      return false;
    }
    return LeadDateHelper.parseStamp(first) == null;
  }

  static _ParsedTimelineEntry _parseTimelineEntry(
    String raw, {
    DateTime? legacyRef,
    DateTime? createdAt,
  }) {
    final trimmed = raw.trim();
    Color dotColor = const Color(0xFF64748B);
    String title = 'Activity logged';
    String timestamp = '';
    DateTime? sortDate;
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
      final stampText = parts[0];
      final parsed = LeadDateHelper.parseStamp(stampText);
      if (parsed != null) {
        sortDate = parsed.dt;
        timestamp = LeadDateHelper.relativeStamp(
          parsed.dt,
          withTime: parsed.hasTime,
        );
      } else if (_isLegacyRelative(trimmed)) {
        if (legacyRef != null) {
          final isYesterday = stampText.toLowerCase().startsWith('yesterday');
          final d = isYesterday
              ? legacyRef.subtract(const Duration(days: 1))
              : legacyRef;
          sortDate = d;
          timestamp = LeadDateHelper.relativeStamp(d, withTime: !isYesterday);
        } else {
          timestamp = 'Earlier';
        }
      } else {
        timestamp = stampText;
      }
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
        if (createdAt != null) {
          sortDate = createdAt;
          timestamp = LeadDateHelper.relativeStamp(createdAt, withTime: false);
        }
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
      sortDate: sortDate,
    );
  }
}

class _ParsedTimelineEntry {
  final Color dotColor;
  final String title;
  final String timestamp;
  final String subtitle;
  final String? note;
  final DateTime? sortDate;

  const _ParsedTimelineEntry({
    required this.dotColor,
    required this.title,
    required this.timestamp,
    required this.subtitle,
    this.note,
    this.sortDate,
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
                const Gap(4),
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
          const Gap(10),
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
                            fontWeight: FontWeight.w600,
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
                    const Gap(2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  if (note != null && note!.isNotEmpty) ...[
                    const Gap(8),
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

class _EditLeadDialog extends StatefulWidget {
  final String leadId;
  final String initialName;
  final String initialEmail;
  final String initialCollege;
  final String initialCourse;

  const _EditLeadDialog({
    required this.leadId,
    required this.initialName,
    required this.initialEmail,
    required this.initialCollege,
    required this.initialCourse,
  });

  @override
  State<_EditLeadDialog> createState() => _EditLeadDialogState();
}

class _EditLeadDialogState extends State<_EditLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _collegeCtrl;
  late final TextEditingController _courseCtrl;
  bool _isSaving = false;
  String? _errorMessage;

  static bool _isPlaceholderName(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty) return true;
    if (clean == 'no name' ||
        clean == 'unnamed' ||
        clean == 'assigned lead' ||
        clean == 'lead') {
      return true;
    }
    return RegExp(r'^l0*\d+$', caseSensitive: false).hasMatch(clean);
  }

  @override
  void initState() {
    super.initState();
    final nameIsPlaceholder = _isPlaceholderName(widget.initialName);
    _nameCtrl = TextEditingController(
      text: nameIsPlaceholder ? '' : widget.initialName,
    );
    _emailCtrl = TextEditingController(
      text: widget.initialEmail == 'Not provided' ? '' : widget.initialEmail,
    );
    _collegeCtrl = TextEditingController(text: widget.initialCollege);
    _courseCtrl = TextEditingController(text: widget.initialCourse);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _collegeCtrl.dispose();
    _courseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final trimmedName = _nameCtrl.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _errorMessage = 'Please enter a student name');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_collegeCtrl.text.trim().isNotEmpty) {
        await CollegeSelectorField.saveCollegeIfNew(_collegeCtrl.text.trim());
      }

      await LeadsRds().updateLeadBasicDetails(
        leadId: widget.leadId,
        name: trimmedName,
        email: _emailCtrl.text.trim(),
        collegeBranch: _collegeCtrl.text.trim(),
        course: _courseCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lead details saved for $trimmedName'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage =
              e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFFEA580C),
                        size: 22,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Edit Lead Details',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          Gap(1),
                          Text(
                            'Add or update student name and information',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                  ],
                ),
                const Gap(16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const Gap(16),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  const Gap(14),
                ],

                // 1. Student Name Field
                Row(
                  children: const [
                    Text(
                      'Student Name',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Gap(4),
                    Text(
                      '*',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: _nameCtrl.text.isEmpty,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter student name (e.g. Rahul Sharma)',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF8144),
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Student name is required';
                    }
                    return null;
                  },
                ),
                const Gap(14),

                // 2. Email Field
                const Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const Gap(6),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. student@example.com',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF8144),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const Gap(14),

                // 3. College / Other & Details
                CollegeSelectorField(
                  controller: _collegeCtrl,
                  useBentoLeadDetailsStyle: true,
                  label: 'COLLEGE / CATEGORY & BRANCH',
                ),
                const Gap(14),

                // 4. Interested Program / Course
                const Text(
                  'Interested Course / Program',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const Gap(6),
                TextFormField(
                  controller: _courseCtrl,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Python Full Stack, AI & Data Science...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF8144),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const Gap(8),
                // Quick chips for popular programs
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'Python Full Stack',
                    'MERN Stack',
                    'Flutter Mobile',
                    'AI & ML',
                  ].map((prog) {
                    return InkWell(
                      onTap: () => setState(() => _courseCtrl.text = prog),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          prog,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Gap(22),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Gap(10),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF8144),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                      ),
                      child: _isSaving
                          ? const SpinKitThreeBounce(
                              color: Colors.white,
                              size: 14,
                            )
                          : const Text(
                              'Save Details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_cubit.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_state.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/ui/leads/presentation/widgets/lead_call_sheets.dart';

class FollowUpsTabView extends StatelessWidget {
  const FollowUpsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowUpsCubit, FollowUpsState>(
      builder: (context, state) {
        final cubit = context.read<FollowUpsCubit>();
        final pad = context.devicePadding;
        final items = state.activeBucketFollowUps;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top White Header + Segmented Control
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFEAECF0))),
              ),
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Follow-ups',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3-Tab Segmented Bar (Overdue 1 | Today 4 | Upcoming 9)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label: 'Overdue',
                            count: state.overdueFollowUps.length,
                            isSelected:
                                state.selectedFollowUpBucket ==
                                FollowUpBucket.overdue,
                            isAlertBadge: true,
                            onTap: () => cubit.selectFollowUpBucket(
                              FollowUpBucket.overdue,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _SegmentButton(
                            label: 'Today',
                            count: state.todayFollowUps.length,
                            isSelected:
                                state.selectedFollowUpBucket ==
                                FollowUpBucket.today,
                            isAlertBadge: false,
                            onTap: () => cubit.selectFollowUpBucket(
                              FollowUpBucket.today,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _SegmentButton(
                            label: 'Upcoming',
                            count: state.upcomingFollowUps.length,
                            isSelected:
                                state.selectedFollowUpBucket ==
                                FollowUpBucket.upcoming,
                            isAlertBadge: false,
                            onTap: () => cubit.selectFollowUpBucket(
                              FollowUpBucket.upcoming,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Cards List
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF4338CA),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'All follow-ups in this tab are completed!',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _FollowUpCard(
                            item: item,
                            onCallNow: () =>
                                LeadCallSheets.showCallAndOutcomeSheet(
                                  context,
                                  leadId: item.id,
                                  leadName: item.leadName,
                                  maskedPhone: item.maskedPhone,
                                  collegeInfo: item.collegeInfo,
                                  campaignTag: item.note,
                                ),
                            onSnooze: () => _showSnoozeSheet(context, item),
                            onMarkDone: () => cubit.completeFollowUp(item.id),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnoozeSheet(BuildContext context, ExecutiveFollowUpItem item) {
    final cubit = context.read<FollowUpsCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(ctx.devicePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Snooze follow-up · ${item.leadName} (FR-4.5)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Executives can snooze or mark done their own follow-ups; overdue escalations to managers cannot be silenced.',
                style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF4338CA),
                ),
                title: const Text(
                  'In 1 hour (Today · 4:30 PM)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  cubit.snoozeFollowUp(item.id, '4:30 PM');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.wb_twilight_rounded,
                  color: Color(0xFF4338CA),
                ),
                title: const Text(
                  'This evening (Today · 6:30 PM)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  cubit.snoozeFollowUp(item.id, '6:30 PM');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF4338CA),
                ),
                title: const Text(
                  'Tomorrow morning (10:00 AM)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  cubit.snoozeFollowUp(
                    item.id,
                    'Tomorrow · 10:00 AM',
                    moveToUpcoming: true,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isAlertBadge;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isAlertBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeBg = isAlertBadge
        ? const Color(0xFFC2410C)
        : (isSelected ? const Color(0xFFE4E7EC) : const Color(0xFFE4E7EC));
    final badgeFg = isAlertBadge ? Colors.white : const Color(0xFF344054);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF475467),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  final ExecutiveFollowUpItem item;
  final VoidCallback onCallNow;
  final VoidCallback onSnooze;
  final VoidCallback onMarkDone;

  const _FollowUpCard({
    required this.item,
    required this.onCallNow,
    required this.onSnooze,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = item.bucket == FollowUpBucket.overdue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? const Color(0xFFD95D24) : const Color(0xFFEAECF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time + Channel Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.timeLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isOverdue
                      ? const Color(0xFFC2410C)
                      : const Color(0xFF4338CA),
                ),
              ),
              Text(
                item.channelLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF667085),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Student Name
          Text(
            item.leadName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),

          // College Info
          Text(
            item.collegeInfo,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 6),

          // Follow-up Task Note
          Text(
            item.note,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF344054)),
          ),
          const SizedBox(height: 14),

          // Action Row: Call now | Snooze | ✓
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: onCallNow,
                    icon: const Icon(Icons.phone_outlined, size: 17),
                    label: const Text(
                      'Call now',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4338CA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: onSnooze,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text(
                    'Snooze',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onMarkDone,
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFFD0D5DD)),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF15803D),
                    size: 20,
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

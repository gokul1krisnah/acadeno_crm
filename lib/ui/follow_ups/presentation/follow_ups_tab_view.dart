import 'package:flutter/cupertino.dart';
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

        return Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top White Header + Modern Underline Tabs
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Follow-ups',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Flat Tab Headers: OVERDUE | TODAY | UPCOMING
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TabItem(
                          title: 'OVERDUE',
                          isSelected:
                              state.selectedFollowUpBucket ==
                              FollowUpBucket.overdue,
                          onTap: () => cubit.selectFollowUpBucket(
                            FollowUpBucket.overdue,
                          ),
                        ),
                        _TabItem(
                          title: 'TODAY',
                          isSelected:
                              state.selectedFollowUpBucket ==
                              FollowUpBucket.today,
                          onTap: () => cubit.selectFollowUpBucket(
                            FollowUpBucket.today,
                          ),
                        ),
                        _TabItem(
                          title: 'UPCOMING',
                          isSelected:
                              state.selectedFollowUpBucket ==
                              FollowUpBucket.upcoming,
                          onTap: () => cubit.selectFollowUpBucket(
                            FollowUpBucket.upcoming,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable Cards List
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFE86938),
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await context.read<FollowUpsCubit>().refresh();
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
                          padding: EdgeInsets.fromLTRB(pad, 14, pad, 24),
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
          ),
        );
      },
    );
  }

  void _showSnoozeSheet(BuildContext context, ExecutiveFollowUpItem item) {
    final cubit = context.read<FollowUpsCubit>();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: EdgeInsets.all(ctx.devicePadding.clamp(16.0, 22.0)),
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
                    CupertinoIcons.clock,
                    color: Color(0xFFE86938),
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
                    CupertinoIcons.sun_haze,
                    color: Color(0xFFE86938),
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
                    CupertinoIcons.calendar,
                    color: Color(0xFFE86938),
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
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 76,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE86938) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
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
    final info = item.collegeInfo.isNotEmpty
        ? item.collegeInfo
        : (item.note.isNotEmpty ? item.note : 'College inquiry');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Student Name + Time Label (Blue)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.leadName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item.timeLabel.isNotEmpty ? item.timeLabel : 'Today · 5:30 PM',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Row 2: College · Branch · Year
          Text(
            info,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Row 3: Call Now (Orange) | Snooze (Ice-blue) | Checkmark (Ice-blue)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onCallNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE86938),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Call Now',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onSnooze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F6FA),
                      foregroundColor: const Color(0xFF334155),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onMarkDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F6FA),
                      foregroundColor: const Color(0xFF64748B),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
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

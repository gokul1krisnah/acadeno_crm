import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:acadeno_crm/shared/theme/app_svgs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/core/services/app_phone_call_service.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_cubit.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_state.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';

class FollowUpsTabView extends StatefulWidget {
  const FollowUpsTabView({super.key});

  @override
  State<FollowUpsTabView> createState() => _FollowUpsTabViewState();
}

class _FollowUpsTabViewState extends State<FollowUpsTabView> {
  late final PageController _pageController;
  bool _isProgrammaticScroll = false;
  int? _targetPageIndex;

  @override
  void initState() {
    super.initState();
    final initialIndex = context
        .read<FollowUpsCubit>()
        .state
        .selectedFollowUpBucket
        .index;
    _pageController = PageController(initialPage: initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(FollowUpsCubit cubit, FollowUpBucket bucket) {
    final target = bucket.index;
    if (_pageController.hasClients &&
        _pageController.page?.round() == target &&
        !_isProgrammaticScroll) {
      return;
    }
    setState(() {
      _isProgrammaticScroll = true;
      _targetPageIndex = target;
    });
    cubit.selectFollowUpBucket(bucket);
    if (_pageController.hasClients) {
      _pageController
          .animateToPage(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
          )
          .then((_) {
            if (mounted) {
              setState(() {
                _isProgrammaticScroll = false;
                _targetPageIndex = null;
              });
            }
          });
    } else {
      _isProgrammaticScroll = false;
      _targetPageIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FollowUpsCubit, FollowUpsState>(
      listener: (context, state) {
        final targetPage = state.selectedFollowUpBucket.index;
        if (!_isProgrammaticScroll &&
            _pageController.hasClients &&
            _pageController.page?.round() != targetPage) {
          _pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<FollowUpsCubit>();
        final pad = context.devicePadding;

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
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Gap(18),

                    // Flat Tab Headers: OVERDUE | TODAY | UPCOMING (Equally distributed)
                    Row(
                      children: [
                        Expanded(
                          child: _TabItem(
                            title: 'OVERDUE',
                            isSelected:
                                state.selectedFollowUpBucket ==
                                FollowUpBucket.overdue,
                            onTap: () => _onTabTapped(
                              cubit,
                              FollowUpBucket.overdue,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _TabItem(
                            title: 'TODAY',
                            isSelected:
                                state.selectedFollowUpBucket ==
                                FollowUpBucket.today,
                            onTap: () => _onTabTapped(
                              cubit,
                              FollowUpBucket.today,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _TabItem(
                            title: 'UPCOMING',
                            isSelected:
                                state.selectedFollowUpBucket ==
                                FollowUpBucket.upcoming,
                            onTap: () => _onTabTapped(
                              cubit,
                              FollowUpBucket.upcoming,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(6),
                    // Single continuous sliding indicator (prevents blinking when crossing intermediate tabs)
                    SizedBox(
                      height: 3,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 1,
                              color: const Color(0xFFF1F5F9),
                            ),
                          ),
                          AnimatedAlign(
                            alignment: switch (state.selectedFollowUpBucket) {
                              FollowUpBucket.overdue =>
                                const Alignment(-1.0, 0.0),
                              FollowUpBucket.today =>
                                const Alignment(0.0, 0.0),
                              FollowUpBucket.upcoming =>
                                const Alignment(1.0, 0.0),
                            },
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOutCubic,
                            child: FractionallySizedBox(
                              widthFactor: 1 / 3,
                              child: Center(
                                child: Container(
                                  height: 3,
                                  width: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE86938),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal Swipe PageView (Gesture Support between Overdue, Today, Upcoming)
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  onPageChanged: (pageIndex) {
                    if (_isProgrammaticScroll) {
                      if (_targetPageIndex != null &&
                          pageIndex == _targetPageIndex) {
                        setState(() {
                          _isProgrammaticScroll = false;
                          _targetPageIndex = null;
                        });
                      }
                      return;
                    }
                    final bucket = FollowUpBucket.values[pageIndex];
                    cubit.selectFollowUpBucket(bucket);
                  },
                  children: [
                    _buildBucketList(
                      context: context,
                      items: state.overdueFollowUps,
                      cubit: cubit,
                      pad: pad,
                    ),
                    _buildBucketList(
                      context: context,
                      items: state.todayFollowUps,
                      cubit: cubit,
                      pad: pad,
                    ),
                    _buildBucketList(
                      context: context,
                      items: state.upcomingFollowUps,
                      cubit: cubit,
                      pad: pad,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBucketList({
    required BuildContext context,
    required List<ExecutiveFollowUpItem> items,
    required FollowUpsCubit cubit,
    required double pad,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
      child: RefreshIndicator.adaptive(
        color: const Color(0xFF4338CA),
        backgroundColor: Colors.white,
        onRefresh: () async {
          cubit.refresh();
          await Future.delayed(const Duration(milliseconds: 1000));
        },
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
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
                separatorBuilder: (_, _) => const Gap(12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _FollowUpCard(
                    key: ValueKey(item.id),
                    item: item,
                    onCallNow: () => AppPhoneCallService.instance
                        .dialFollowUpItem(context, item),
                    onSnooze: () => _showSnoozeSheet(context, item),
                    onMarkDone: () {
                      cubit.completeFollowUp(item.id);
                      SnackBarAlert.showToast(
                        context: context,
                        message: 'Follow-up for ${item.leadName} marked completed',
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  void _showSnoozeSheet(BuildContext context, ExecutiveFollowUpItem item) {
    final cubit = context.read<FollowUpsCubit>();
    final now = DateTime.now();
    final inOneHour = now.add(const Duration(hours: 1));
    final oneHourFormatted = DateFormat('h:mm a').format(inOneHour);
    final inOneHourDay = inOneHour.day == now.day ? 'Today' : 'Tomorrow';
    final oneHourLabel = '$inOneHourDay · $oneHourFormatted';

    const eveningFormatted = '4:00 PM';
    const eveningLabel = 'Today · $eveningFormatted';

    const tomorrowLabel = 'Tomorrow · 10:00 AM';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
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
                  'Snooze follow-up · ${item.leadName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Gap(4),
                const Text(
                  'Executives can snooze or mark done their own follow-ups; overdue escalations to managers cannot be silenced.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                ),
                const Gap(12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    CupertinoIcons.clock,
                    color: Color(0xFFE86938),
                  ),
                  title: Text(
                    'In 1 hour ($oneHourLabel)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    cubit.snoozeFollowUp(
                      item.id,
                      oneHourLabel,
                      moveToUpcoming: inOneHourDay == 'Tomorrow',
                    );
                    SnackBarAlert.showToast(
                      context: context,
                      message:
                          'Follow-up for ${item.leadName} snoozed ($oneHourLabel)',
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    CupertinoIcons.sun_haze,
                    color: Color(0xFFE86938),
                  ),
                  title: const Text(
                    'This evening (Today · 4:00 PM)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    cubit.snoozeFollowUp(item.id, eveningLabel);
                    SnackBarAlert.showToast(
                      context: context,
                      message:
                          'Follow-up for ${item.leadName} snoozed ($eveningLabel)',
                    );
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
                      tomorrowLabel,
                      moveToUpcoming: true,
                    );
                    SnackBarAlert.showToast(
                      context: context,
                      message:
                          'Follow-up for ${item.leadName} snoozed ($tomorrowLabel)',
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.8,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
              ),
              child: Text(title, maxLines: 1),
            ),
          ),
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
    super.key,
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
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
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
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(10),
              Flexible(
                child: Text(
                  item.timeLabel.isNotEmpty
                      ? item.timeLabel
                      : 'Today · ${DateFormat('h:mm a').format(DateTime.now())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const Gap(5),

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
          const Gap(16),

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
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Call Now',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(10),
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
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Snooze',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(10),
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
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: SvgPicture.asset(
                      AppSvgs.tick,
                      width: 14,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF64748B),
                        BlendMode.srcIn,
                      ),
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

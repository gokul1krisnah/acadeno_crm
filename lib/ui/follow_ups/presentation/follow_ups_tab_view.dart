import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
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
        final media = MediaQuery.of(context);
        final screenWidth = media.size.width;
        final isLandscape = media.orientation == Orientation.landscape;
        final isCompact = screenWidth < 360;
        final hPad = isCompact ? 16.0 : 24.0;
        final topPad = isLandscape ? 12.0 : 20.0;
        final headerToTabsGap = isLandscape ? 14.0 : 25.0;

        return ColoredBox(
          color: const Color(0xFFF8FAFC),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header + Underline Tabs (Figma 1395:617 & 1395:760)
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Follow-ups',
                          style: GoogleFonts.inter(
                            fontSize: isCompact ? 22 : 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            height: 36 / 24,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Gap(headerToTabsGap),

                        // Flat Tab Headers: OVERDUE | TODAY | UPCOMING
                        Row(
                          children: [
                            Expanded(
                              child: _TabItem(
                                title: 'OVERDUE',
                                alignment: Alignment.centerLeft,
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
                                alignment: Alignment.center,
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
                                alignment: Alignment.centerRight,
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
                        const Gap(8),
                        // Single continuous sliding 2px indicator matching Figma 1395:764 / 1395:768 / 1395:772
                        SizedBox(
                          height: 2,
                          width: double.infinity,
                          child: AnimatedAlign(
                            alignment: switch (state.selectedFollowUpBucket) {
                              FollowUpBucket.overdue => Alignment.centerLeft,
                              FollowUpBucket.today => Alignment.center,
                              FollowUpBucket.upcoming => Alignment.centerRight,
                            },
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOutCubic,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeInOutCubic,
                              height: 2,
                              width: switch (state.selectedFollowUpBucket) {
                                FollowUpBucket.overdue =>
                                  isCompact ? 64.0 : 71.0,
                                FollowUpBucket.today =>
                                  isCompact ? 54.0 : 62.0,
                                FollowUpBucket.upcoming =>
                                  isCompact ? 70.0 : 78.0,
                              },
                              decoration: BoxDecoration(
                                color: const Color(0xFFE86938),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
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
                          pad: hPad,
                          isLandscape: isLandscape,
                        ),
                        _buildBucketList(
                          context: context,
                          items: state.todayFollowUps,
                          cubit: cubit,
                          pad: hPad,
                          isLandscape: isLandscape,
                        ),
                        _buildBucketList(
                          context: context,
                          items: state.upcomingFollowUps,
                          cubit: cubit,
                          pad: hPad,
                          isLandscape: isLandscape,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
    required bool isLandscape,
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
                padding: EdgeInsets.fromLTRB(
                  pad,
                  isLandscape ? 14 : 24,
                  pad,
                  24,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Gap(16),
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
                        message:
                            'Follow-up for ${item.leadName} marked completed',
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
  final Alignment alignment;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.title,
    required this.alignment,
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.6,
                height: 17 / 12,
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;
    final cardHPad = isCompact ? 16.0 : 21.0;
    final btnGap1 = isCompact ? 8.0 : 11.0;
    final btnGap2 = isCompact ? 8.0 : 12.0;

    final info = item.collegeInfo.isNotEmpty
        ? item.collegeInfo
        : (item.note.isNotEmpty ? item.note : 'College inquiry');

    return Container(
      padding: EdgeInsets.fromLTRB(cardHPad, 16, cardHPad, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Student Name (1395:645) + Time Label (1395:642)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item.leadName,
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 16.5 : 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    height: 28 / 18,
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                    height: 16 / 12,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),

          // Row 2: College · Branch · Year (1395:647)
          Text(
            info,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
              height: 19.5 / 12.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(8),

          // Row 3: HorizontalBorder Container (1395:652) + 3 Action Buttons
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF8FAFC), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Button 1: Call Now (1418:592 — width: 96, height: 33)
                Expanded(
                  flex: 96,
                  child: SizedBox(
                    height: 33,
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Call Now',
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 20 / 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Gap(btnGap1),
                // Button 2: Snooze (1395:660 — width: 81, height: 33)
                Expanded(
                  flex: 81,
                  child: SizedBox(
                    height: 33,
                    child: ElevatedButton(
                      onPressed: onSnooze,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0F4F8),
                        foregroundColor: const Color(0xFF334155),
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Snooze',
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                              height: 20 / 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Gap(btnGap2),
                // Button 3: Mark Done Checkmark (1395:663 — width: 85, height: 33)
                Expanded(
                  flex: 85,
                  child: SizedBox(
                    height: 33,
                    child: ElevatedButton(
                      onPressed: onMarkDone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0F4F8),
                        foregroundColor: const Color(0xFF94A3B8),
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: SvgPicture.asset(
                        AppSvgs.tick,
                        width: 14,
                        height: 16,
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
  }
}

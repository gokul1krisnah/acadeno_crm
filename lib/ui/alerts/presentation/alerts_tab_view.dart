import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:acadeno_crm/ui/alerts/application/alerts_cubit.dart';
import 'package:acadeno_crm/ui/home/application/home_cubit.dart';
import 'package:acadeno_crm/ui/alerts/application/alerts_state.dart';
import 'package:acadeno_crm/ui/alerts/data/model/alert_models.dart';
import 'package:acadeno_crm/ui/leads/presentation/widgets/lead_call_sheets.dart';

class AlertsTabView extends StatelessWidget {
  const AlertsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertsCubit, AlertsState>(
      builder: (context, state) {
        final cubit = context.read<AlertsCubit>();
        final pad = context.devicePadding;
        final todayList = state.todayAlerts;
        final yesterdayList = state.yesterdayAlerts;
        final earlierList = state.earlierAlerts;

        return Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: RefreshIndicator.adaptive(
            color: const Color(0xFF4338CA),
            backgroundColor: Colors.white,
            onRefresh: () async {
              await cubit.refresh();
              await Future.delayed(const Duration(seconds: 3));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clean header matching Figma (seamless white background)
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(pad, 16, pad, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              AppImages.acadenoALogo,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Alerts',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: cubit.markAllAlertsRead,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              'Mark all read',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4338CA),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body Content
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (todayList.isEmpty &&
                            yesterdayList.isEmpty &&
                            earlierList.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 48,
                              horizontal: 20,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 48,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'All caught up!',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No pending alerts or overdue tasks right now.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // 1. TODAY Section
                          if (todayList.isNotEmpty) ...[
                            Text(
                              'TODAY',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: const Color(0xFF8E8EA9),
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final item in todayList)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AlertCard(
                                  item: item,
                                  onTap: () => _handleAlertTap(context, item),
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],

                          // 2. YESTERDAY Section
                          if (yesterdayList.isNotEmpty) ...[
                            Text(
                              'YESTERDAY',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: const Color(0xFF8E8EA9),
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final item in yesterdayList)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AlertCard(
                                  item: item,
                                  onTap: () => _handleAlertTap(context, item),
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],

                          // 3. EARLIER Section
                          if (earlierList.isNotEmpty) ...[
                            Text(
                              'EARLIER',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: const Color(0xFF8E8EA9),
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final item in earlierList)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AlertCard(
                                  item: item,
                                  onTap: () => _handleAlertTap(context, item),
                                ),
                              ),
                          ],
                        ],
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

  void _handleAlertTap(BuildContext context, ExecutiveAlertItem item) {
    context.read<AlertsCubit>().markSingleAlertRead(item.id);
    if (item.targetLeadName != null) {
      LeadCallSheets.showCallAndOutcomeSheet(
        context,
        leadName: item.targetLeadName!,
      );
    } else if (item.targetTabIndex != null) {
      context.read<HomeCubit>().selectBottomNav(item.targetTabIndex!);
    }
  }
}

class _AlertCard extends StatelessWidget {
  final ExecutiveAlertItem item;
  final VoidCallback onTap;

  const _AlertCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 395),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE9E9F0),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category SVG Icon Container (Figma design: 48x48 rounded square #D1D1E0)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D1E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _buildCategorySvg(item.iconType),
                ),
                const SizedBox(width: 12), // gap: 12px
                // Text column: Heading & Subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Heading row: Title & Time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 18.75 / 15,
                                letterSpacing: 15 * 0.001,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.timeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8C8CA1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Subtitle text
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 20 / 12,
                          letterSpacing: 0,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySvg(AlertIconType type) {
    final assetPath = switch (type) {
      AlertIconType.phone ||
      AlertIconType.list => 'assets/svgs/alert_phone.svg',
      AlertIconType.reassign => 'assets/svgs/alert_reassign.svg',
      AlertIconType.sun => 'assets/svgs/alert_sun.svg',
      AlertIconType.clock => 'assets/svgs/alert_clock.svg',
      AlertIconType.warning => 'assets/svgs/alert_warning.svg',
    };

    return SvgPicture.asset(
      assetPath,
      width: 22,
      height: 22,
      fit: BoxFit.contain,
    );
  }
}

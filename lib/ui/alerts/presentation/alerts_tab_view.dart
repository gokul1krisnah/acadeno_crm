import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
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

        return RefreshIndicator(
          color: const Color(0xFF4338CA),
          backgroundColor: Colors.white,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top White Header
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEAECF0)),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alerts',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      InkWell(
                        onTap: cubit.markAllAlertsRead,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            'Mark all read',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body Content
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 18, pad, 24),
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
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'All caught up!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'No pending alerts or overdue tasks right now.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // 1. TODAY Section (Strictly today's notifications, newest first)
                        if (todayList.isNotEmpty) ...[
                          const Text(
                            'TODAY',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                              color: Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...todayList.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AlertCard(
                                item: item,
                                onTap: () => _handleAlertTap(context, item),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 2. YESTERDAY Section (Strictly yesterday's notifications, newest first)
                        if (yesterdayList.isNotEmpty) ...[
                          const Text(
                            'YESTERDAY',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                              color: Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...yesterdayList.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AlertCard(
                                item: item,
                                onTap: () => _handleAlertTap(context, item),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 3. EARLIER Section (Past notifications, newest first)
                        if (earlierList.isNotEmpty) ...[
                          const Text(
                            'EARLIER',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                              color: Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...earlierList.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AlertCard(
                                item: item,
                                onTap: () => _handleAlertTap(context, item),
                              ),
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
    final (iconData, iconBg, iconFg) = switch (item.iconType) {
      AlertIconType.clock => (
        Icons.access_time_rounded,
        const Color(0xFFFDECE3),
        const Color(0xFFB45309),
      ),
      AlertIconType.list => (
        Icons.format_list_bulleted_rounded,
        const Color(0xFFEEEDFD),
        const Color(0xFF4338CA),
      ),
      AlertIconType.sun => (
        Icons.wb_sunny_outlined,
        const Color(0xFFFEF6E0),
        const Color(0xFFB45309),
      ),
      AlertIconType.warning => (
        Icons.warning_amber_rounded,
        const Color(0xFFFEE4E2),
        const Color(0xFFB42318),
      ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rounded square icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconFg, size: 20),
            ),
            const SizedBox(width: 12),

            // Title + Time + Orange Dot + Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.timeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                          if (item.isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD95D24),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475467),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../home/application/home_cubit.dart';
import '../application/leads_cubit.dart';
import '../application/leads_state.dart';

/// Full tab view for "My Records" & performance logs.
class MyRecordsTabView extends StatelessWidget {
  const MyRecordsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeadsCubit, LeadsState>(
      builder: (context, state) {
        final user = context.read<HomeCubit>().state.user;
        final totalCalls = state.callRecords.length;
        final interestedCount = state.callRecords
            .where((r) => r.outcome.trim().toLowerCase() == 'interested')
            .length;
        final convertedCount = state.callRecords
            .where((r) => r.outcome.trim().toLowerCase() == 'converted')
            .length;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<LeadsCubit>().refresh();
            },
            color: const Color(0xFF6366F1),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Top Header
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Records',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                user.roleLabel.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4F46E5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(4),
                        Text(
                          '${user.displayName} · Personal performance & call activity',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const Gap(16),
                        // Summary metric cards
                        Row(
                          children: [
                            Expanded(
                              child: _metricBox(
                                value: '$totalCalls',
                                label: 'Total Calls',
                                color: const Color(0xFF0F172A),
                                bg: const Color(0xFFF3E8FF),
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: _metricBox(
                                value: '$interestedCount',
                                label: 'Interested',
                                color: const Color(0xFF0284C7),
                                bg: const Color(0xFFE0F2FE),
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: _metricBox(
                                value: '$convertedCount',
                                label: 'Converted',
                                color: const Color(0xFF16A34A),
                                bg: const Color(0xFFDCFCE7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: Gap(16)),

                // Call Logs Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'PERMANENT CALL LOGS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: Gap(10)),

                // List of Call Logs
                if (state.callRecords.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_disabled_rounded,
                            size: 44,
                            color: Colors.grey.shade400,
                          ),
                          const Gap(12),
                          Text(
                            'No call records logged yet',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475467),
                            ),
                          ),
                          const Gap(4),
                          Text(
                            'Outbound calls made to leads will appear here automatically.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final rec = state.callRecords[index];
                          final outcome = rec.outcome.trim();
                          final isConverted =
                              outcome.toLowerCase() == 'converted';
                          final isInterested =
                              outcome.toLowerCase() == 'interested';

                          final badgeBg = isConverted
                              ? const Color(0xFFDCFCE7)
                              : (isInterested
                                  ? const Color(0xFFE0F2FE)
                                  : const Color(0xFFF1F5F9));
                          final badgeText = isConverted
                              ? const Color(0xFF166534)
                              : (isInterested
                                  ? const Color(0xFF0369A1)
                                  : const Color(0xFF475467));

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x05000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.call_rounded,
                                    size: 18,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              rec.leadName.isNotEmpty
                                                  ? rec.leadName
                                                  : 'Lead Contact',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeBg,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              outcome.toUpperCase(),
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: badgeText,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Gap(4),
                                      Text(
                                        '${rec.collegeInfo} · Duration: ${rec.duration} · ${rec.timestamp}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      if (rec.notes.isNotEmpty) ...[
                                        const Gap(6),
                                        Text(
                                          rec.notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: const Color(0xFF475467),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: state.callRecords.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: Gap(24)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricBox({
    required String value,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Gap(2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

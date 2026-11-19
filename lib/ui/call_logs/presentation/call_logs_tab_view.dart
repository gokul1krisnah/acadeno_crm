import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/extensions/build_context_extension.dart';
import '../../../shared/snackbar_alerts/snack_alert.dart';
import '../../alerts/presentation/widgets/alerts_header_button.dart';
import '../../leads/data/model/lead_models.dart';
import '../../leads/presentation/widgets/lead_call_sheets.dart';
import '../application/call_logs_cubit.dart';
import '../application/call_logs_state.dart';
import '../data/model/call_log_model.dart';
import '../data/repository/call_logs_repo.dart';
import '../data/sources/call_logs_rds.dart';

class CallLogsTabView extends StatelessWidget {
  const CallLogsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CallLogsCubit(CallLogsRepository(CallLogsRds())),
      child: const _CallLogsBody(),
    );
  }
}

class _CallLogsBody extends StatefulWidget {
  const _CallLogsBody();

  @override
  State<_CallLogsBody> createState() => _CallLogsBodyState();
}

class _CallLogsBodyState extends State<_CallLogsBody> with WidgetsBindingObserver {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed && mounted) {
      context.read<CallLogsCubit>().refresh();
    }
  }

  void _openDialer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openWhatsApp(String phone) async {
    final norm = LeadPhoneValidator.normalize10Digits(phone);
    if (norm.isEmpty) return;
    final uri = Uri.parse('https://wa.me/91$norm');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleOtherCategory(BuildContext context, DeviceCallLogItem item) async {
    final cubit = context.read<CallLogsCubit>();
    final norm = item.normalizedPhone;
    final masked = LeadPhoneValidator.maskPhone(item.number);

    // Mark as 'Other' immediately
    cubit.setCategory(item, CallCategory.other);

    // Open existing white after-call outcome popup directly
    await LeadCallSheets.showCallAndOutcomeSheet(
      context,
      leadId: norm.isNotEmpty ? norm : item.id,
      leadName: 'Caller',
      maskedPhone: masked,
      initialDuration: item.formattedDuration,
      collegeInfo: 'Call Log Inquiry',
      campaignTag: 'Call Log',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallLogsCubit, CallLogsState>(
      listener: (context, state) {
        if (state.toastMessage != null) {
          SnackBarAlert.showToast(
            context: context,
            message: state.toastMessage!,
            isWarning: state.isToastError,
          );
          context.read<CallLogsCubit>().clearToast();
        }
      },
      builder: (context, state) {
        final cubit = context.read<CallLogsCubit>();
        final pad = context.devicePadding;

        return RefreshIndicator.adaptive(
          color: const Color(0xFF4338CA),
          backgroundColor: Colors.white,
          onRefresh: cubit.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // 1. Header Section
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(pad, 16, pad, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Call Logs',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: cubit.refresh,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
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
                                  child: const Icon(
                                    CupertinoIcons.arrow_clockwise,
                                    size: 18,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const Gap(8),
                              const AlertsHeaderButton(),
                            ],
                          ),
                        ],
                      ),
                      const Gap(10),

                      // Info banner matching screenshot 1: "Showing logs for: BSNL Mobile"
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFBAE6FD),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Color(0xFF0284C7),
                            ),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                state.isPlatformSupported
                                    ? 'Showing logs for: ${state.simName.isNotEmpty ? state.simName : "Mobile"}'
                                    : 'Showing categorized records (Web / Desktop preview)',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),

                      // Search bar
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: cubit.search,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by phone number...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              CupertinoIcons.search,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      cubit.search('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                          ),
                        ),
                      ),
                      const Gap(12),

                      // Category Filter Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'All (${state.allLogs.length})',
                              isSelected: state.activeCategoryFilter == 'all',
                              onTap: () => cubit.setFilter('all'),
                            ),
                            const Gap(8),
                            _buildFilterChip(
                              label: '🔥 Hot Leads',
                              isSelected: state.activeCategoryFilter == 'hot_lead',
                              onTap: () => cubit.setFilter('hot_lead'),
                            ),
                            const Gap(8),
                            _buildFilterChip(
                              label: '👤 Follow-ups',
                              isSelected: state.activeCategoryFilter == 'follow_up',
                              onTap: () => cubit.setFilter('follow_up'),
                            ),
                            const Gap(8),
                            _buildFilterChip(
                              label: '⏰ Reminders',
                              isSelected: state.activeCategoryFilter == 'reminder',
                              onTap: () => cubit.setFilter('reminder'),
                            ),
                            const Gap(8),
                            _buildFilterChip(
                              label: '⚙️ Other',
                              isSelected: state.activeCategoryFilter == 'other',
                              onTap: () => cubit.setFilter('other'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Content Body
              if (state.isLoading && state.allLogs.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4338CA),
                    ),
                  ),
                )
              else if (!state.isPlatformSupported)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: _buildUnsupportedCard(context),
                  ),
                )
              else if (!state.hasPermission)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: _buildPermissionRequestCard(context, cubit, state),
                  ),
                )
              else if (state.displayedLogs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: _buildEmptyState(),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 14, pad, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = state.displayedLogs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CallLogCard(
                            item: item,
                            onSelectCategory: (cat) {
                              if (cat == CallCategory.other) {
                                _handleOtherCategory(context, item);
                              } else {
                                cubit.setCategory(item, cat);
                              }
                            },
                            onCall: () => _openDialer(item.number),
                            onWhatsApp: () => _openWhatsApp(item.number),
                            onOther: () => _handleOtherCategory(context, item),
                          ),
                        );
                      },
                      childCount: state.displayedLogs.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4338CA) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4338CA) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.phone_iphone_rounded,
              color: Color(0xFF4338CA),
              size: 28,
            ),
          ),
          const Gap(16),
          Text(
            'Device Call Logs (Android Only)',
            style: GoogleFonts.inter(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Gap(8),
          Text(
            'Fetching real local carrier call history requires native Android permissions (READ_CALL_LOG). Browsers and non-Android systems do not provide direct hardware access to carrier call logs.\n\nAll category flows (Hot Leads, Follow-ups, and Reminders) are fully connected and will show records once categorized on Android.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequestCard(
    BuildContext context,
    CallLogsCubit cubit,
    CallLogsState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.phone_locked_rounded,
              color: Color(0xFFEA580C),
              size: 28,
            ),
          ),
          const Gap(16),
          Text(
            state.isPermissionDenied
                ? 'Call Log Permission Denied'
                : 'Call Log Permission Required',
            style: GoogleFonts.inter(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Gap(8),
          Text(
            state.isPermissionDenied
                ? 'Access was denied. Please grant call log permissions in Android Settings so Acadeno CRM can fetch incoming, outgoing, and missed inquiries.'
                : 'Acadeno CRM accesses device call history to help you instantly tag Hot Leads, schedule Follow-ups, and log Reminders right after student calls.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const Gap(20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: cubit.requestPermission,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(
              state.isPermissionDenied ? 'Retry Permission' : 'Grant Permission',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.phone_missed_rounded,
              color: Color(0xFF94A3B8),
              size: 26,
            ),
          ),
          const Gap(14),
          Text(
            'No Call Logs Found',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Gap(6),
          Text(
            'No matching calls found in device call history.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallLogCard extends StatelessWidget {
  final DeviceCallLogItem item;
  final ValueChanged<CallCategory> onSelectCategory;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onOther;

  const _CallLogCard({
    required this.item,
    required this.onSelectCategory,
    required this.onCall,
    required this.onWhatsApp,
    required this.onOther,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top row: Call direction icon, Phone number, timestamp/duration, 3-dot menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCallTypeIcon(item.callType),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone Number ONLY (Contact name explicitly suppressed per instructions)
                    Text(
                      item.formattedNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      '${item.formattedDateTime} • ${item.formattedDuration}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) {
                  if (val == 'call') {
                    onCall();
                  } else if (val == 'whatsapp') {
                    onWhatsApp();
                  } else if (val == 'other') {
                    onOther();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'call',
                    child: Row(
                      children: const [
                        Icon(Icons.call_rounded, size: 16, color: Color(0xFF059669)),
                        Gap(10),
                        Text('Call Number'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'whatsapp',
                    child: Row(
                      children: const [
                        Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                        Gap(10),
                        Text('WhatsApp'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'other',
                    child: Row(
                      children: const [
                        Icon(Icons.assignment_outlined, size: 16, color: Color(0xFFD97706)),
                        Gap(10),
                        Text('Outcome Sheet (Other)'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(14),

          // 2. Action Pills Row matching Screenshot 2: Hot leads, Follow ups, Reminders, Other
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryPill(
                    label: 'Hot leads',
                    icon: Icons.local_fire_department_rounded,
                    activeColor: const Color(0xFFE11D48),
                    activeGradient: const LinearGradient(
                      colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                    ),
                    inactiveColor: const Color(0xFFE11D48),
                    isSelected: item.category == CallCategory.hotLead,
                    onTap: () => onSelectCategory(CallCategory.hotLead),
                  ),
                  _CategoryPill(
                    label: 'Follow ups',
                    icon: Icons.person_add_alt_1_rounded,
                    activeColor: const Color(0xFF0D9488),
                    activeGradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF059669)],
                    ),
                    inactiveColor: const Color(0xFF0D9488),
                    isSelected: item.category == CallCategory.followUp,
                    onTap: () => onSelectCategory(CallCategory.followUp),
                  ),
                  _CategoryPill(
                    label: 'Reminders',
                    icon: Icons.access_time_rounded,
                    activeColor: const Color(0xFF78350F),
                    activeGradient: const LinearGradient(
                      colors: [Color(0xFF78350F), Color(0xFF92400E)],
                    ),
                    inactiveColor: const Color(0xFF78350F),
                    isSelected: item.category == CallCategory.reminder,
                    onTap: () => onSelectCategory(CallCategory.reminder),
                  ),
                  _CategoryPill(
                    label: 'Other',
                    icon: Icons.more_horiz_rounded,
                    activeColor: const Color(0xFF475569),
                    activeGradient: const LinearGradient(
                      colors: [Color(0xFF475569), Color(0xFF334155)],
                    ),
                    inactiveColor: const Color(0xFF64748B),
                    isSelected: item.category == CallCategory.other,
                    onTap: () => onSelectCategory(CallCategory.other),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCallTypeIcon(CallType type) {
    Color bg;
    IconData icon;
    Color iconColor;

    switch (type) {
      case CallType.outgoing:
        bg = const Color(0xFFEFF6FF);
        icon = Icons.arrow_outward_rounded;
        iconColor = const Color(0xFF2563EB);
        break;
      case CallType.incoming:
        bg = const Color(0xFFECFDF5);
        icon = Icons.call_received_rounded;
        iconColor = const Color(0xFF059669);
        break;
      case CallType.missed:
        bg = const Color(0xFFFEF2F2);
        icon = Icons.call_missed_rounded;
        iconColor = const Color(0xFFDC2626);
        break;
      case CallType.rejected:
        bg = const Color(0xFFFFF1F2);
        icon = Icons.call_end_rounded;
        iconColor = const Color(0xFFE11D48);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        icon = Icons.phone_rounded;
        iconColor = const Color(0xFF64748B);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: 22),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final Gradient? activeGradient;
  final Color inactiveColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.icon,
    required this.activeColor,
    this.activeGradient,
    required this.inactiveColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            gradient: isSelected ? activeGradient : null,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : inactiveColor,
              ),
              const Gap(6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

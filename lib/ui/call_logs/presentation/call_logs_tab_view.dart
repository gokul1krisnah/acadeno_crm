import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/extensions/build_context_extension.dart';
import '../../../shared/snackbar_alerts/snack_alert.dart';
import '../../../shared/theme/app_svgs.dart';
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
    final masked = LeadPhoneValidator.maskPhone(item.number);

    // Open existing white outcome popup and keep it open until saved or cancelled.
    await LeadCallSheets.showCallAndOutcomeSheet(
      context,
      leadName: item.hasContactName ? item.contactName : item.formattedNumber,
      maskedPhone: masked,
      initialDuration: item.formattedDuration,
      collegeInfo: 'Call Log Inquiry',
      campaignTag: 'Call Log',
      onSave: ({
        required String outcome,
        required String notes,
        String? courseEnrolled,
        String? batch,
        String? followUpTime,
      }) async {
        await cubit.saveOtherOutcome(
          item: item,
          outcome: outcome,
          notes: notes,
          courseEnrolled: courseEnrolled,
          batch: batch,
          followUpTime: followUpTime,
        );
      },
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
        final media = MediaQuery.of(context);
        final screenWidth = media.size.width;
        final isLandscape = media.orientation == Orientation.landscape;
        final isCompact = screenWidth < 360;
        final pad = isCompact ? 14.0 : context.devicePadding;
        final topPad = isLandscape ? 12.0 : 16.0;
        final bottomHeaderPad = isLandscape ? 12.0 : 16.0;

        return Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: RefreshIndicator.adaptive(
            color: const Color(0xFF4338CA),
            backgroundColor: Colors.white,
            displacement: 24,
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
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      topPad,
                      pad,
                      bottomHeaderPad,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Call Logs',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: isCompact ? 22 : 25,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                      height: 30 / 25,
                                    ),
                                  ),
                                ),
                                const Gap(8),
                                const AlertsHeaderButton(),
                              ],
                            ),
                            Gap(isLandscape ? 10 : 14),

                            // SIM info banner ("Showing logs for: ...")
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 12 : 14,
                                vertical: isCompact ? 9 : 11,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4FD),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                state.isPlatformSupported
                                    ? 'Showing logs for: ${state.simName.isNotEmpty ? state.simName : "Mobile"}'
                                    : 'Showing categorized records (Web / Desktop preview)',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: isCompact ? 12.5 : 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF0C4A6E),
                                ),
                              ),
                            ),
                            if (state.isPlatformSupported &&
                                state.hasPermission &&
                                !state.hasContactsPermission) ...[
                              const Gap(8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.person_crop_circle,
                                      size: 17,
                                      color: Color(0xFFB45309),
                                    ),
                                    const Gap(8),
                                    Expanded(
                                      child: Text(
                                        'Allow Contacts access to display saved contact names.',
                                        style: GoogleFonts.inter(
                                          fontSize: isCompact ? 11.5 : 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                    const Gap(8),
                                    TextButton(
                                      onPressed:
                                          cubit.requestContactsPermission,
                                      style: TextButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFB45309,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Allow',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Gap(isLandscape ? 10 : 12),

                            // Search bar (adaptive minHeight so large text scales never clip)
                            Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: cubit.search,
                                style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone number',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                            prefixIcon: const Icon(
                              CupertinoIcons.search,
                              size: 19,
                              color: Color(0xFF64748B),
                            ),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 17),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      cubit.search('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const Gap(14),

                      // Category Filter Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'All (${state.allLogs.length})',
                              svgAsset: AppSvgs.all,
                              isSelected: state.activeCategoryFilter == 'all',
                              onTap: () => cubit.setFilter('all'),
                            ),
                            const Gap(8),
                            _buildFilterChip(
                              label: 'Hot leads',
                              svgAsset: AppSvgs.flame,
                              iconColor: const Color(0xFFEF4444),
                              isSelected:
                                  state.activeCategoryFilter == 'hot_lead',
                              onTap: () => cubit.setFilter('hot_lead'),
                            ),
                            const Gap(8),
                            _buildFilterChip(
                              label: 'Follow-ups',
                              svgAsset: AppSvgs.followup,
                              iconColor: const Color(0xFF0D9488),
                              isSelected:
                                  state.activeCategoryFilter == 'follow_up',
                              onTap: () => cubit.setFilter('follow_up'),
                            ),
                            const Gap(8),
                            _buildFilterChip(
                              label: 'Reminders',
                              svgAsset: AppSvgs.reminder,
                              iconColor: const Color(0xFFB45309),
                              isSelected:
                                  state.activeCategoryFilter == 'reminder',
                              onTap: () => cubit.setFilter('reminder'),
                            ),
                            const Gap(8),
                            _buildFilterChip(
                              label: 'Other',
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
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Padding(
                          padding: EdgeInsets.all(pad),
                          child: _buildUnsupportedCard(context),
                        ),
                      ),
                    ),
                  )
                else if (!state.hasPermission)
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Padding(
                          padding: EdgeInsets.all(pad),
                          child: _buildPermissionRequestCard(
                            context,
                            cubit,
                            state,
                          ),
                        ),
                      ),
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
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: Padding(
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
                                  onOther: () =>
                                      _handleOtherCategory(context, item),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: state.displayedLogs.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    String? svgAsset,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4338CA) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4338CA)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (svgAsset != null) ...[
              SvgPicture.asset(
                svgAsset,
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(
                  isSelected
                      ? Colors.white
                      : (iconColor ?? const Color(0xFF64748B)),
                  BlendMode.srcIn,
                ),
              ),
              const Gap(6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
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
    final screenW = MediaQuery.sizeOf(context).width;
    final isCompact = screenW < 360;
    final cardPad = isCompact ? 12.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top row: Call direction icon, Contact name / Phone number, timestamp/duration, 3-dot menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCallTypeIcon(item.callType, isCompact: isCompact),
              Gap(isCompact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.hasContactName) ...[
                      Text(
                        item.contactName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 15 : 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                          height: 21 / 16,
                        ),
                      ),
                      const Gap(1),
                      Text(
                        item.formattedNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 12.5 : 13.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                          height: 18 / 13.5,
                        ),
                      ),
                    ] else
                      Text(
                        item.formattedNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 15.5 : 16.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                          height: 22 / 16.5,
                        ),
                      ),
                    const Gap(2),
                    Text(
                      '${item.formattedDateTime} · ${item.formattedDuration}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                        height: 18 / 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF475569),
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
                        Icon(
                          Icons.call_rounded,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                        Gap(10),
                        Text('Call Number'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'whatsapp',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        Gap(10),
                        Text('WhatsApp'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'other',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.assignment_outlined,
                          size: 16,
                          color: Color(0xFFD97706),
                        ),
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

          // 2. Responsive category buttons (single row on phones, 2x2 grid on ultra-narrow widths)
          LayoutBuilder(
            builder: (context, constraints) {
              final hotLeadBtn = _CategoryPill(
                label: 'Hot lead',
                svgAsset: AppSvgs.flame,
                inactiveBg: const Color(0xFFFCE7EC),
                inactiveTextColor: const Color(0xFFBE123C),
                activeBg: const Color(0xFFE11D48),
                isSelected: item.category == CallCategory.hotLead,
                onTap: () => onSelectCategory(CallCategory.hotLead),
              );
              final followUpBtn = _CategoryPill(
                label: 'Follow up',
                svgAsset: AppSvgs.followup,
                inactiveBg: const Color(0xFFE6F7F0),
                inactiveTextColor: const Color(0xFF047857),
                activeBg: const Color(0xFF059669),
                isSelected: item.category == CallCategory.followUp,
                onTap: () => onSelectCategory(CallCategory.followUp),
              );
              final reminderBtn = _CategoryPill(
                label: 'Reminder',
                svgAsset: AppSvgs.reminder,
                inactiveBg: const Color(0xFFFEF3DC),
                inactiveTextColor: const Color(0xFFB45309),
                activeBg: const Color(0xFFD97706),
                isSelected: item.category == CallCategory.reminder,
                onTap: () => onSelectCategory(CallCategory.reminder),
              );
              final otherBtn = _CategoryPill(
                label: 'Other',
                inactiveBg: const Color(0xFFF1F5F9),
                inactiveTextColor: const Color(0xFF334155),
                activeBg: const Color(0xFF334155),
                isSelected: item.category == CallCategory.other,
                onTap: () => onSelectCategory(CallCategory.other),
              );

              if (constraints.maxWidth < 300) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: hotLeadBtn),
                        const Gap(6),
                        Expanded(child: followUpBtn),
                      ],
                    ),
                    const Gap(6),
                    Row(
                      children: [
                        Expanded(child: reminderBtn),
                        const Gap(6),
                        Expanded(child: otherBtn),
                      ],
                    ),
                  ],
                );
              }

              final gap = isCompact ? 6.0 : 8.0;
              return Row(
                children: [
                  Expanded(child: hotLeadBtn),
                  Gap(gap),
                  Expanded(child: followUpBtn),
                  Gap(gap),
                  Expanded(child: reminderBtn),
                  Gap(gap),
                  Expanded(child: otherBtn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCallTypeIcon(CallType type, {bool isCompact = false}) {
    Color bg;
    IconData icon;
    Color iconColor;

    switch (type) {
      case CallType.outgoing:
        bg = const Color(0xFFEEF2FF);
        icon = Icons.arrow_outward_rounded;
        iconColor = const Color(0xFF3730A3);
        break;
      case CallType.incoming:
        bg = const Color(0xFFE6F7F0);
        icon = Icons.call_received_rounded;
        iconColor = const Color(0xFF047857);
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

    final size = isCompact ? 38.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: isCompact ? 18 : 20),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final String? svgAsset;
  final Color inactiveBg;
  final Color inactiveTextColor;
  final Color activeBg;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    this.svgAsset,
    required this.inactiveBg,
    required this.inactiveTextColor,
    required this.activeBg,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected ? Colors.white : inactiveTextColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeBg.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (svgAsset != null) ...[
                  SvgPicture.asset(
                    svgAsset!,
                    width: 12,
                    height: 12,
                    colorFilter: ColorFilter.mode(fgColor, BlendMode.srcIn),
                  ),
                  const Gap(4),
                ],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                    height: 16 / 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

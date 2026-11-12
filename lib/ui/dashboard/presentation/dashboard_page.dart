import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:gap/gap.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_time_helper.dart';
import 'package:acadeno_crm/core/utils/url_dialer_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:acadeno_crm/shared/utilities/link_launcher.dart';
import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:acadeno_crm/shared/theme/app_typography.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/dashboard_cubit.dart';
import '../application/dashboard_state.dart';
import '../data/model/dashboard_user_model.dart';
import '../data/repository/dashboard_repo.dart';
import '../data/sources/dashboard_rds.dart';

import 'package:acadeno_crm/ui/leads/application/admin_leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/data/repository/leads_repo.dart';
import 'package:acadeno_crm/ui/leads/data/sources/leads_rds.dart';

import 'widgets/campaigns_view.dart';
import 'widgets/college_visits_view.dart';
import 'widgets/follow_ups_view.dart';
import 'widgets/import_leads_view.dart';
import 'widgets/leads_assign_view.dart';
import 'widgets/team_management_view.dart';
import 'widgets/user_management_view.dart';
import 'widgets/settings_view.dart';

const _primary = Color(0xFF3F37C9);
const _orangeAccent = Color(0xFFEF8144);
const _bg = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _muted = Color(0xFF64748B);
const _text = Color(0xFF0F172A);

@RoutePage()
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final rds = DashboardRds();
    final repository = DashboardRepository(rds);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DashboardCubit(repository)),
        BlocProvider(
          create: (_) => AdminLeadsCubit(LeadsRepository(LeadsRds())),
        ),
      ],
      child: const _DashboardView(),
    );
  }
}

class _NavItem {
  final String svgAsset;
  final IconData fallbackIcon;
  final String label;

  const _NavItem({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.label,
  });
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasAutoHealedRole = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _primaryNav = [
    _NavItem(
      svgAsset: 'assets/svgs/dashboard.svg',
      fallbackIcon: Icons.tag_rounded,
      label: 'Dashboard',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/leads.svg',
      fallbackIcon: Icons.format_list_bulleted_rounded,
      label: 'Leads & Assign',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/campaigns.svg',
      fallbackIcon: Icons.view_agenda_outlined,
      label: 'Campaigns',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/followups.svg',
      fallbackIcon: Icons.subdirectory_arrow_right_rounded,
      label: 'Follow-ups',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/collegevisits.svg',
      fallbackIcon: Icons.people_alt_outlined,
      label: 'College Visits',
    ),
  ];

  static const _generalNav = [
    _NavItem(
      svgAsset: 'assets/svgs/import.svg',
      fallbackIcon: Icons.file_upload_outlined,
      label: 'Import',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/teammanagement.svg',
      fallbackIcon: Icons.help_outline_rounded,
      label: 'Team Management',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/usermanagement.svg',
      fallbackIcon: Icons.badge_outlined,
      label: 'User Management',
    ),
    _NavItem(
      svgAsset: 'assets/svgs/settings.svg',
      fallbackIcon: Icons.settings_outlined,
      label: 'Settings',
    ),
  ];

  DateTime? _selectedDashboardDate;

  String get _today {
    final n = _selectedDashboardDate ?? DateTime.now();
    return DateFormat('EEEE, d MMMM').format(n);
  }

  bool _isResettingData = false;

  Future<void> _confirmAndResetCrmData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 26,
              ),
              Gap(10),
              Expanded(
                child: Text(
                  'Reset CRM Database?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete all operational data:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              Gap(8),
              Text(
                '• All Leads & student records\n• All Campaigns & source events\n• All Follow-ups & assignments\n• All Call logs & duration records\n• All College visits\n• Phone index & in-app alerts',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF4B5563),
                ),
              ),
              Gap(14),
              Text(
                '🔒 All Admin & User accounts will remain 100% untouched.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Yes, Reset CRM Data',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isResettingData = true);
    _toast('Starting CRM data reset...');

    try {
      final collectionsToClear = [
        'leads',
        'campaigns',
        'lead_assignments',
        'assignments',
        'college_visits',
        'call_logs',
        'lead_phones',
        'alerts',
        'notification_queue',
        'colleges',
      ];

      int totalDeleted = 0;
      final firestore = FirebaseFirestore.instance;

      for (final col in collectionsToClear) {
        try {
          final snapshot = await firestore.collection(col).get();
          final docs = snapshot.docs;
          if (docs.isEmpty) continue;

          for (var i = 0; i < docs.length; i += 400) {
            final batch = firestore.batch();
            final end = (i + 400 < docs.length) ? i + 400 : docs.length;
            final chunk = docs.sublist(i, end);
            for (final doc in chunk) {
              batch.delete(doc.reference);
            }
            await batch.commit();
            totalDeleted += chunk.length;
          }
        } catch (e) {
          debugPrint('Notice clearing $col: $e');
        }
      }

      if (mounted) {
        _toast('CRM Data cleared ($totalDeleted records removed). Fresh CRM initialized!');
      }
    } catch (e) {
      if (mounted) {
        _toast('Error clearing CRM data: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isResettingData = false);
      }
    }
  }

  Future<void> _pickDashboardDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDashboardDate ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _orangeAccent,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDashboardDate = picked;
      });
      if (mounted) {
        context.read<AdminLeadsCubit>().selectCustomAssignmentDate(picked);
      }
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    SnackBarAlert.showToast(context: context, message: msg, isWarning: error);
  }

  void _logout() {
    final cubit = context.read<DashboardCubit>();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 22,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                const Text(
                  'Sign out of Dashboard?',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Gap(6),
                const Text(
                  'Are you sure you want to end your current dashboard administrative session?',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const Gap(24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            textAlign: TextAlign.center,
                            style: AppTypography.figmaButton(
                              color: const Color(0xFF475467),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await cubit.signOut();
                          },
                          child: Text(
                            'Sign out',
                            textAlign: TextAlign.center,
                            style: AppTypography.figmaButton(
                              color: Colors.white,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return BlocConsumer<DashboardCubit, DashboardState>(
      listener: (context, state) {
        if (state is DashboardActionSuccess) {
          _toast(state.message);
        } else if (state is DashboardActionFailure) {
          _toast(state.message, error: true);
        } else if (state is DashboardSignedOut) {
          context.router.replaceAll([const LoginRoute()]);
        }
      },
      builder: (context, state) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: cubit.watchCurrentUserDoc(),
          builder: (context, snap) {
            final me = snap.data?.data() ?? {};
            return LayoutBuilder(
              builder: (context, c) {
                final showSidebar = c.maxWidth >= 960;
                final pad = context.devicePadding;

                return Scaffold(
                  key: _scaffoldKey,
                  backgroundColor: _bg,
                  drawer: showSidebar
                      ? null
                      : Drawer(
                          width: 240,
                          backgroundColor: Colors.white,
                          child: SafeArea(
                            child: _sidebar(
                              me,
                              state.selectedNavIndex,
                              inDrawer: true,
                            ),
                          ),
                        ),
                  body: SafeArea(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showSidebar) _sidebar(me, state.selectedNavIndex),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: pad.clamp(16.0, 32.0),
                              vertical: pad.clamp(16.0, 32.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!showSidebar &&
                                    state.selectedNavIndex != 0) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      onTap: () => _scaffoldKey.currentState
                                          ?.openDrawer(),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(color: _border),
                                        ),
                                        child: const Icon(
                                          Icons.menu_rounded,
                                          color: _text,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Gap(14),
                                ],
                                if (state.selectedNavIndex == 0) ...[
                                  StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: cubit.watchAllUsers(),
                                    builder: (context, usersSnap) {
                                      return StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >(
                                        stream: cubit.watchAllLeads(),
                                        builder: (context, leadsSnap) {
                                          final allUsers = cubit
                                              .mapAndSortUsers(usersSnap.data);
                                          final activeUsers = allUsers
                                              .where((u) => u.isActive)
                                              .toList();
                                          final rawLeads =
                                              leadsSnap.data?.docs
                                                  .map((d) => d.data())
                                                  .toList() ??
                                              <Map<String, dynamic>>[];

                                          return LayoutBuilder(
                                            builder: (context, contentBox) {
                                              final contentWidth =
                                                  contentBox.maxWidth;
                                              final isWideContent =
                                                  contentWidth >= 1080;

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _header(
                                                    me: me,
                                                    contentWidth: contentWidth,
                                                    showMenuButton:
                                                        !showSidebar,
                                                  ),
                                                  const Gap(24),
                                              if (_searchQuery
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                _buildLiveSearchResults(
                                                  query: _searchQuery.trim(),
                                                  leads: rawLeads,
                                                  users: allUsers,
                                                  onClear: () {
                                                    setState(() {
                                                      _searchCtrl.clear();
                                                      _searchQuery = '';
                                                    });
                                                    context
                                                        .read<AdminLeadsCubit>()
                                                        .setSearchQuery('');
                                                  },
                                                ),
                                                const Gap(24),
                                              ],
                                              _stats(rawLeads, activeUsers),
                                              const Gap(24),
                                              if (isWideContent)
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      flex: 58,
                                                      child: Column(
                                                        children: [
                                                          _TeamToday(
                                                            activeUsers:
                                                                activeUsers,
                                                            leads: rawLeads,
                                                          ),
                                                          const Gap(24),
                                                          _OverdueFollowUps(
                                                            leads: rawLeads,
                                                            onReassign: () =>
                                                                cubit.selectNav(
                                                                  1,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const Gap(24),
                                                    Expanded(
                                                      flex: 42,
                                                      child: Column(
                                                        children: [
                                                          _Conversions(
                                                            leads: rawLeads,
                                                          ),
                                                          const Gap(24),
                                                          _CollegeVisits(
                                                            onPlanVisit: () =>
                                                                cubit.selectNav(
                                                                  4,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                Column(
                                                  children: [
                                                    _TeamToday(
                                                      activeUsers: activeUsers,
                                                      leads: rawLeads,
                                                    ),
                                                    const Gap(16),
                                                    _Conversions(
                                                      leads: rawLeads,
                                                    ),
                                                    const Gap(16),
                                                    _OverdueFollowUps(
                                                      leads: rawLeads,
                                                      onReassign: () =>
                                                          cubit.selectNav(1),
                                                    ),
                                                    const Gap(16),
                                                    _CollegeVisits(
                                                      onPlanVisit: () =>
                                                          cubit.selectNav(4),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ] else if (state.selectedNavIndex == 1)
                                  const LeadsAssignView()
                                else if (state.selectedNavIndex == 2)
                                  const CampaignsView()
                                else if (state.selectedNavIndex == 3)
                                  const FollowUpsView()
                                else if (state.selectedNavIndex == 4)
                                  const CollegeVisitsView()
                                else if (state.selectedNavIndex == 5)
                                  const ImportLeadsView()
                                else if (state.selectedNavIndex == 6)
                                  const TeamManagementView()
                                else if (state.selectedNavIndex == 7)
                                  UserManagementView(
                                    onOpenSettings: () => cubit.selectNav(8),
                                  )
                                else if (state.selectedNavIndex == 8)
                                  SettingsView(onLogout: _logout),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sidebar(
    Map<String, dynamic> me,
    int selectedIndex, {
    bool inDrawer = false,
  }) {
    final cubit = context.read<DashboardCubit>();
    final user = cubit.currentUser;
    final rawName = (me['name'] ?? user?.displayName ?? '').toString().trim();
    final name = rawName.isNotEmpty
        ? rawName
        : (user?.email?.split('@').first ?? 'Admin');

    if (!_hasAutoHealedRole &&
        (me['role'] != 'admin' || me['email'] == null) &&
        cubit.currentUserId != null) {
      _hasAutoHealedRole = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(cubit.currentUserId)
            .set({
              'role': 'admin',
              'name': name,
              if (user?.email != null) 'email': user!.email,
              'isActive': true,
            }, SetOptions(merge: true));
      });
    }

    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((e) => e.isEmpty ? '' : e[0].toUpperCase())
        .join();

    return Container(
      width: inDrawer ? double.infinity : 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: inDrawer
            ? null
            : const Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Image.asset(
              AppImages.logo,
              height: 56,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, _, _) => const Text(
                'ACADENO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                // Dynamically scale vertical gaps between items based on viewport height:
                // Taller screens get generous 10-12px gaps so items breathe and don't leave a huge void below.
                final itemGap = h > 900
                    ? 12.0
                    : (h > 760 ? 8.0 : (h > 640 ? 5.0 : 2.0));
                final sectionGap = h > 900
                    ? 32.0
                    : (h > 760 ? 24.0 : 16.0);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _primaryNav.length; i++) ...[
                        if (i > 0) Gap(itemGap),
                        _buildNavItem(
                          item: _primaryNav[i],
                          index: i,
                          selectedIndex: selectedIndex,
                          inDrawer: inDrawer,
                        ),
                      ],
                      Gap(sectionGap),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 16, 10),
                        child: Text(
                          'GENERAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      for (var i = 0; i < _generalNav.length; i++) ...[
                        if (i > 0) Gap(itemGap),
                        _buildNavItem(
                          item: _generalNav[i],
                          index: i + 5,
                          selectedIndex: selectedIndex,
                          inDrawer: inDrawer,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials.isNotEmpty ? initials[0] : 'U',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.center,
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Center(
                      child: Text(
                        'Logout',
                        textAlign: TextAlign.center,
                        style: AppTypography.figmaButton(
                          color: const Color(0xFFDC2626),
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
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required int index,
    required int selectedIndex,
    required bool inDrawer,
  }) {
    final cubit = context.read<DashboardCubit>();
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: isSelected ? const Color(0xFFFFF4ED) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            cubit.selectNav(index);
            if (inDrawer) {
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(
                    child: SvgPicture.asset(
                      item.svgAsset,
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        isSelected ? _orangeAccent : const Color(0xFF64748B),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? _orangeAccent
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({
    required Map<String, dynamic> me,
    required double contentWidth,
    required bool showMenuButton,
  }) {
    if (contentWidth < 680) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showMenuButton) ...[
                InkWell(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: _text,
                      size: 22,
                    ),
                  ),
                ),
                const Gap(10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D312E),
                        letterSpacing: -0.4102,
                      ),
                    ),
                    const Gap(2),
                    InkWell(
                      onTap: _pickDashboardDate,
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        '$_today ·',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF718096),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.3418,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),
          _buildFigmaSearchBar(),
          const Gap(12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                alignment: Alignment.center,
                backgroundColor: const Color(0xFFEF8144),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.read<DashboardCubit>().selectNav(1),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 16, color: Colors.white),
                    const Gap(8),
                    Text(
                      "Assign Today's Leads",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (contentWidth < 1080) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showMenuButton) ...[
                IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu_rounded, color: _text),
                ),
                const Gap(8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D312E),
                        letterSpacing: -0.4102,
                      ),
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        InkWell(
                          onTap: _pickDashboardDate,
                          borderRadius: BorderRadius.circular(6),
                          child: Text(
                            '$_today ·',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF718096),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const Gap(6),
                        InkWell(
                          onTap: _isResettingData ? null : _confirmAndResetCrmData,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _isResettingData
                                    ? const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                                      )
                                    : const Icon(Icons.delete_sweep_rounded, size: 12, color: Color(0xFFDC2626)),
                                const Gap(3),
                                Text(
                                  _isResettingData ? 'Resetting...' : 'Clear Data',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFDC2626),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    alignment: Alignment.center,
                    backgroundColor: const Color(0xFFEF8144),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => context.read<DashboardCubit>().selectNav(1),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 16, color: Colors.white),
                        const Gap(8),
                        Text(
                          "Assign Today's Leads",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(14),
          _buildFigmaSearchBar(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showMenuButton) ...[
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: _text),
          ),
          const Gap(8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D312E),
                  letterSpacing: -0.4102,
                  height: 36 / 30,
                ),
              ),
              const Gap(4),
              Row(
                children: [
                  InkWell(
                    onTap: _pickDashboardDate,
                    borderRadius: BorderRadius.circular(6),
                    child: Text(
                      '$_today ·',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF718096),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.3418,
                        height: 20 / 14,
                      ),
                    ),
                  ),
                  const Gap(8),
                  InkWell(
                    onTap: _isResettingData ? null : _confirmAndResetCrmData,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isResettingData
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFDC2626),
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_sweep_rounded,
                                  size: 14,
                                  color: Color(0xFFDC2626),
                                ),
                          const Gap(4),
                          Text(
                            _isResettingData
                                ? 'Resetting...'
                                : 'Clear CRM Data (Keep Users)',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFDC2626),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, minWidth: 220),
          child: _buildFigmaSearchBar(),
        ),
        const Gap(16),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              alignment: Alignment.center,
              backgroundColor: const Color(0xFFEF8144),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => context.read<DashboardCubit>().selectNav(1),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 16, color: Colors.white),
                  const Gap(8),
                  Text(
                    "Assign Today's Leads",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaSearchBar({double? width}) {
    return Container(
      width: width,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8E5), width: 1),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _searchCtrl,
        textAlignVertical: TextAlignVertical.center,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
          context.read<AdminLeadsCubit>().setSearchQuery(val.trim());
        },
        style: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF111827),
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.search_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 46,
            minHeight: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _searchQuery = '';
                    });
                    context.read<AdminLeadsCubit>().setSearchQuery('');
                  },
                )
              : null,
          hintText: 'Search',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSearchResults({
    required String query,
    required List<Map<String, dynamic>> leads,
    required List<DashboardUserModel> users,
    required VoidCallback onClear,
  }) {
    final q = query.toLowerCase();

    // 1. Matched Leads
    final matchedLeads = leads.where((l) {
      final name = (l['name'] ?? l['studentName'] ?? l['candidateName'] ?? '')
          .toString()
          .toLowerCase();
      final phone = (l['phone'] ?? l['phoneNumber'] ?? '')
          .toString()
          .toLowerCase();
      final college = (l['college'] ?? l['collegeName'] ?? '')
          .toString()
          .toLowerCase();
      final course = (l['course'] ?? l['program'] ?? '')
          .toString()
          .toLowerCase();
      final assigned = (l['assignedName'] ?? l['assignedTo'] ?? '')
          .toString()
          .toLowerCase();
      final status = (l['status'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          phone.contains(q) ||
          college.contains(q) ||
          course.contains(q) ||
          assigned.contains(q) ||
          status.contains(q);
    }).toList();

    // 2. Matched Team Members
    final matchedUsers = users.where((u) {
      final name = u.name.toLowerCase();
      final email = u.email.toLowerCase();
      final role = u.role.toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q);
    }).toList();

    // 3. Matched College Visits
    final matchedVisits = _CollegeVisits._figmaVisits.where((v) {
      final name = (v['collegeName'] ?? '').toString().toLowerCase();
      final purpose = (v['purpose'] ?? '').toString().toLowerCase();
      return name.contains(q) || purpose.contains(q);
    }).toList();

    final totalMatches =
        matchedLeads.length + matchedUsers.length + matchedVisits.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: _orangeAccent,
                  size: 20,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Search results for "$query"',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                        ),
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$totalMatches ${totalMatches == 1 ? 'match' : 'matches'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    const Text(
                      'Live lookup across Leads, Team Directory, and Campus Visits',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const Gap(16),
          if (totalMatches == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: Color(0xFFCBD5E1),
                    ),
                    const Gap(10),
                    Text(
                      'No results found matching "$query"',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Gap(4),
                    const Text(
                      'Try searching by student name, mobile number, college, or team member name.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // LEADS SECTION
            if (matchedLeads.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LEADS (${matchedLeads.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      context.read<AdminLeadsCubit>().setSearchQuery(query);
                      context.read<DashboardCubit>().selectNav(1);
                    },
                    child: const Text(
                      'View all in Leads & Assign →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              ...matchedLeads.take(5).map((l) {
                final name = (l['name'] ?? l['studentName'] ?? 'Lead')
                    .toString();
                final phone = (l['phone'] ?? l['phoneNumber'] ?? '').toString();
                final college = (l['college'] ?? l['collegeName'] ?? 'Campus')
                    .toString();
                final course = (l['course'] ?? l['program'] ?? '').toString();
                final assigned =
                    (l['assignedName'] ?? l['assignedTo'] ?? 'Unassigned')
                        .toString();
                final status = (l['status'] ?? 'New').toString();

                Color badgeBg = const Color(0xFFEEF2FF);
                Color badgeFg = _primary;
                if (status.toLowerCase().contains('convert')) {
                  badgeBg = const Color(0xFFDCFCE7);
                  badgeFg = const Color(0xFF15803D);
                } else if (status.toLowerCase().contains('interest')) {
                  badgeBg = const Color(0xFFEFF6FF);
                  badgeFg = const Color(0xFF2563EB);
                } else if (status.toLowerCase().contains('overdue')) {
                  badgeBg = const Color(0xFFFEE2E2);
                  badgeFg = const Color(0xFFB91C1C);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'L',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _text,
                                    ),
                                  ),
                                ),
                                const Gap(8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: badgeFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(2),
                            Text(
                              '$college${course.isNotEmpty ? ' · $course' : ''} · Assigned: $assigned',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(10),
                      if (phone.isNotEmpty)
                        IconButton(
                          tooltip: 'Call $name',
                          icon: const Icon(
                            Icons.phone_outlined,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                          onPressed: () => UrlDialerHelper.openDialer(phone),
                        ),
                      OutlinedButton(
                        onPressed: () {
                          context.read<AdminLeadsCubit>().setSearchQuery(name);
                          context.read<DashboardCubit>().selectNav(1);
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // TEAM SECTION
            if (matchedUsers.isNotEmpty) ...[
              const Gap(12),
              Text(
                'TEAM MEMBERS (${matchedUsers.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const Gap(8),
              ...matchedUsers.take(3).map((u) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFDBEAFE),
                        child: Text(
                          u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                            Text(
                              '${u.email} · ${u.role}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            context.read<DashboardCubit>().selectNav(7),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'View User',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // COLLEGE VISITS SECTION
            if (matchedVisits.isNotEmpty) ...[
              const Gap(12),
              Text(
                'CAMPUS VISITS (${matchedVisits.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const Gap(8),
              ...matchedVisits.map((v) {
                final name = (v['collegeName'] ?? 'College').toString();
                final purpose = (v['purpose'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 20,
                        color: _primary,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                            Text(
                              purpose,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            LinkLauncher.launchCollegeMapsDirections(name),
                        icon: const Icon(Icons.directions_outlined, size: 14),
                        label: const Text('Directions'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stats(
    List<Map<String, dynamic>> leads,
    List<DashboardUserModel> activeUsers,
  ) {
    final totalLeads = leads.length;
    final totalAssigned = leads.where((l) {
      final uid = l['assignedToUid'];
      final name = l['assignedToName'] ?? l['assignedTo'];
      return (uid != null && uid.toString().trim().isNotEmpty) ||
          (name != null && name.toString().trim().isNotEmpty && name != '—');
    }).length;

    final contactedCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      final isDone = (l['isDone'] as bool?) ?? false;
      return status != 'new' && status != 'unassigned' || isDone;
    }).length;
    final contactedPct = totalAssigned > 0
        ? (contactedCount / totalAssigned * 100).round()
        : (totalLeads > 0 ? (contactedCount / totalLeads * 100).round() : 0);

    final evaluatedFollowUps = leads
        .where((l) {
          final isDone = (l['isDone'] as bool?) ?? false;
          return !isDone;
        })
        .map((l) {
          final eval = FollowUpTimeHelper.evaluate(
            rawFollowUpTime: l['followUpTime'],
            assignedDateKey: l['assignedDateKey'],
            assignedDateLabel: l['assignedDateLabel'],
            assignedAt: l['assignedAt'],
            updatedAt: l['updatedAt'],
            createdAt: l['createdAt'],
            status: (l['status'] ?? '').toString(),
          );
          return (lead: l, eval: eval);
        })
        .toList();

    final followUpsCount = evaluatedFollowUps.where((e) {
      final s = (e.lead['status'] ?? '').toString().toLowerCase();
      return e.eval.bucket == FollowUpBucket.today ||
          s == 'follow-up' ||
          s == 'claimed';
    }).length;

    final overdueCount = evaluatedFollowUps
        .where((e) => e.eval.isOverdue)
        .length;

    final convertedCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      return status.contains('convert');
    }).length;
    final conversionPct = totalLeads > 0
        ? (convertedCount / totalLeads * 100).round()
        : 0;

    final cards = [
      _StatCard(
        label: 'Total Leads',
        value: '$totalLeads',
        sub: '$totalAssigned assigned to team',
        color: const Color(0xFF4338CA),
        valueColor: Colors.white,
        svgAsset: 'assets/svgs/stat_total_leads.svg',
        icon: Icons.groups_rounded,
        isSolidHero: true,
      ),
      _StatCard(
        label: 'Calls / Contacted',
        value: '$contactedCount/$totalAssigned',
        sub: '$contactedPct% of assigned',
        color: const Color(0xFF3F3FB4),
        valueColor: const Color(0xFF3F3FB4),
        svgAsset: 'assets/svgs/stat_phone.svg',
        icon: Icons.phone_rounded,
      ),
      _StatCard(
        label: 'Follow-ups Due',
        value: '$followUpsCount',
        sub: 'Across ${activeUsers.length} active members',
        color: const Color(0xFFE96849),
        valueColor: const Color(0xFFE96849),
        svgAsset: 'assets/svgs/stat_calendar_check.svg',
        icon: Icons.calendar_today_rounded,
      ),
      _StatCard(
        label: 'Overdue / Pending',
        value: '$overdueCount',
        sub: 'Requires team attention',
        color: const Color(0xFF4C0CBF),
        valueColor: const Color(0xFF4C0CBF),
        svgAsset: 'assets/svgs/stat_hourglass.svg',
        icon: Icons.hourglass_full_rounded,
      ),
      _StatCard(
        label: 'Converted Leads',
        value: '$convertedCount',
        sub: '$conversionPct% conversion rate',
        color: const Color(0xFF22C55E),
        valueColor: const Color(0xFF22C55E),
        svgAsset: 'assets/svgs/stat_star.svg',
        icon: Icons.star_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 1140) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const Gap(16),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        if (w >= 740) {
          final cardW = ((w - 2 * 16) / 3).floorToDouble() - 1;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards
                .map((c) => SizedBox(width: cardW, child: c))
                .toList(),
          );
        }

        if (w >= 480) {
          final cardW = ((w - 12) / 2).floorToDouble() - 1;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < cards.length; i++)
                SizedBox(
                  width: i == cards.length - 1 ? w : cardW,
                  child: cards[i],
                ),
            ],
          );
        }

        final cardW = ((w - 10) / 2).floorToDouble() - 1;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < cards.length; i++)
              SizedBox(
                width: i == cards.length - 1 ? w : (w < 320 ? w : cardW),
                child: cards[i],
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final Color? valueColor;
  final IconData? icon;
  final String? svgAsset;
  final bool isSolidHero;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.valueColor,
    this.icon,
    this.svgAsset,
    this.isSolidHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final cardPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
        : const EdgeInsets.all(20);

    if (isSolidHero) {
      return Container(
        constraints: const BoxConstraints(minHeight: 125),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -48,
              top: -48,
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x0DFFFFFF),
                ),
              ),
            ),
            Padding(
              padding: cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xE6FFFFFF),
                            fontSize: isMobile ? 12.5 : 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.5195,
                          ),
                        ),
                      ),
                      if (svgAsset != null)
                        SvgPicture.asset(
                          svgAsset!,
                          width: isMobile ? 15 : 18,
                          height: isMobile ? 15 : 18,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        )
                      else if (icon != null)
                        Icon(icon, color: Colors.white, size: isMobile ? 14 : 16),
                    ],
                  ),
                  const Gap(8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 28 : 34,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Gap(4),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xCCFFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2344,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 125),
      padding: cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF718096),
                    fontSize: isMobile ? 12.5 : 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (svgAsset != null)
                SvgPicture.asset(
                  svgAsset!,
                  width: isMobile ? 15 : 18,
                  height: isMobile ? 15 : 18,
                )
              else if (icon != null)
                Icon(icon, color: color, size: isMobile ? 14 : 16),
            ],
          ),
          const Gap(8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 28 : 34,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? color,
                  ),
                ),
              ),
              const Gap(4),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFFA0AEC0),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Main Cards
// ============================================================================

class _TeamToday extends StatelessWidget {
  final List<DashboardUserModel> activeUsers;
  final List<Map<String, dynamic>> leads;

  const _TeamToday({required this.activeUsers, required this.leads});

  @override
  Widget build(BuildContext context) {
    final rows = activeUsers.map((user) {
      final userLeads = leads.where((l) {
        final assignedUid = l['assignedToUid'];
        final assignedName = l['assignedToName'] ?? l['assignedTo'];
        final ownerUid = l['ownerUid'];
        return assignedUid == user.uid ||
            ownerUid == user.uid ||
            (assignedName != null &&
                assignedName.toString().trim().toLowerCase() ==
                    user.name.trim().toLowerCase());
      }).toList();

      final assigned = userLeads.length;
      final called = userLeads.where((l) {
        final status = (l['status'] ?? '').toString().toLowerCase();
        final isDone = (l['isDone'] as bool?) ?? false;
        return status != 'new' && status != 'unassigned' || isDone;
      }).length;
      final interested = userLeads.where((l) {
        return (l['status'] ?? '').toString().toLowerCase() == 'interested';
      }).length;
      final converted = userLeads.where((l) {
        return (l['status'] ?? '').toString().toLowerCase().contains('convert');
      }).length;
      final overdue = userLeads.where((l) {
        final isDone = (l['isDone'] as bool?) ?? false;
        final status = (l['status'] ?? '').toString().toLowerCase();
        return !isDone &&
            (status == 'new' || status == 'claimed' || status == 'follow-up');
      }).length;

      return (
        name: user.name,
        role: user.roleLabel,
        called: called,
        assigned: assigned,
        interested: interested,
        converted: converted,
        overdue: overdue,
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF9FAFB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Team Today',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    letterSpacing: 0.0527,
                    height: 28 / 18,
                  ),
                ),
                const Gap(12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const Gap(6),
                      Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF15803D),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3027,
                          height: 15 / 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No active team members registered yet.',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Gap(32),
                        Builder(
                          builder: (_) {
                            final r = rows[i];
                            final progress = r.assigned > 0
                                ? (r.called / r.assigned).clamp(0.0, 1.0)
                                : 0.0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: const Color(0xFF111827),
                                          letterSpacing: 0.0156,
                                        ),
                                      ),
                                    ),
                                    const Gap(8),
                                    Text(
                                      '${r.called} / ${r.assigned} leads',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF3F3FB4),
                                        letterSpacing: -0.0957,
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(9999),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    color: const Color(0xFF3F3FB4),
                                    backgroundColor: const Color(0xFFF3F4F6),
                                  ),
                                ),
                                const Gap(8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFDBEAFE),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'INTERESTED: ${r.interested}',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF2563EB),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          height: 16.5 / 11,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFDCFCE7),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'CONVERTED: ${r.converted}',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF16A34A),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          height: 16.5 / 11,
                                        ),
                                      ),
                                    ),
                                    if (r.overdue > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFFFEDD5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'OVERDUE: ${r.overdue}',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFEA580C),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            height: 16.5 / 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Conversions extends StatelessWidget {
  final List<Map<String, dynamic>> leads;

  const _Conversions({required this.leads});

  static String _normalizeSource(dynamic raw) {
    if (raw == null) return 'Direct Visit';
    final trimmed = raw.toString().trim();
    if (trimmed.isEmpty) return 'Direct Visit';
    final lower = trimmed.toLowerCase();
    if (lower == 'direct visit' ||
        lower == 'direct_visit' ||
        lower == 'direct' ||
        lower == 'walk-in' ||
        lower == 'direct walk-in') {
      return 'Direct Visit';
    }
    // Clean capitalized title
    return trimmed
        .split(RegExp(r'[\s_]+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static bool _isConverted(dynamic statusVal) {
    final s = (statusVal ?? '').toString().toLowerCase();
    return s.contains('convert') ||
        s.contains('enrolled') ||
        s.contains('admission');
  }

  @override
  Widget build(BuildContext context) {
    final sourcesMap = <String, (int converted, int total)>{};
    for (final l in leads) {
      final rawSource =
          l['source'] ??
          l['sourceEvent'] ??
          l['campaign'] ??
          l['campaignTag'] ??
          l['lead_source'] ??
          'Direct Visit';
      final src = _normalizeSource(rawSource);
      final statusVal = l['status'] ?? l['leadStatus'] ?? l['outcome'];
      final isConverted = _isConverted(statusVal);
      final curr = sourcesMap[src] ?? (0, 0);
      sourcesMap[src] = (curr.$1 + (isConverted ? 1 : 0), curr.$2 + 1);
    }

    final List<(String, int, int)> displaySources = sourcesMap.isNotEmpty
        ? (sourcesMap.entries
              .map((e) => (e.key, e.value.$1, e.value.$2))
              .toList()
            ..sort((a, b) {
              final convCmp = b.$2.compareTo(a.$2);
              if (convCmp != 0) return convCmp;
              return b.$3.compareTo(a.$3);
            }))
        : const [];

    final isMobile = MediaQuery.of(context).size.width < 600;
    final cardPadding = isMobile
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(24);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: cardPadding,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF9FAFB), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Conversions by source',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      letterSpacing: 0.0527,
                      height: 28 / 18,
                    ),
                  ),
                ),
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${leads.length} leads',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.0117,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: cardPadding,
            child: displaySources.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No source conversion data recorded yet.',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < displaySources.take(6).length; i++) ...[
                        if (i > 0) const Gap(20),
                        Builder(
                          builder: (_) {
                            final r = displaySources[i];
                            return Row(
                              children: [
                                Expanded(
                                  flex: 32,
                                  child: Text(
                                    r.$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                      height: 16 / 12,
                                    ),
                                  ),
                                ),
                                const Gap(10),
                                Expanded(
                                  flex: 40,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9999),
                                    child: LinearProgressIndicator(
                                      value: r.$3 > 0
                                          ? (r.$2 / r.$3).clamp(0.0, 1.0)
                                          : 0.0,
                                      minHeight: 10,
                                      color: r.$2 > 0
                                          ? const Color(0xFFFB923C)
                                          : const Color(0xFF3F3FB4),
                                      backgroundColor: const Color(0xFFF9FAFB),
                                    ),
                                  ),
                                ),
                                const Gap(10),
                                SizedBox(
                                  width: 52,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: RichText(
                                    textAlign: TextAlign.right,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${r.$2}',
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF111827),
                                            height: 16 / 20,
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' ',
                                          style: GoogleFonts.inter(fontSize: 12),
                                        ),
                                        TextSpan(
                                          text: '/ ${r.$3}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: const Color(0xFF9FA0A1),
                                            height: 16 / 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OverdueFollowUps extends StatelessWidget {
  final List<Map<String, dynamic>> leads;
  final VoidCallback onReassign;

  const _OverdueFollowUps({required this.leads, required this.onReassign});

  @override
  Widget build(BuildContext context) {
    final overdue = leads.where((l) {
      final isDone = (l['isDone'] as bool?) ?? false;
      if (isDone) return false;
      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: l['followUpTime'],
        assignedDateKey: l['assignedDateKey'],
        assignedDateLabel: l['assignedDateLabel'],
        assignedAt: l['assignedAt'],
        updatedAt: l['updatedAt'],
        createdAt: l['createdAt'],
        status: (l['status'] ?? '').toString(),
      );
      return eval.isOverdue;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Overdue Follow ups',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                    letterSpacing: -0.2813,
                  ),
                ),
              ),
              const Gap(8),
              InkWell(
                onTap: onReassign,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x333F3FB4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Manage in Leads',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF5C59B6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.041,
                      height: 20 / 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(20),
          if (overdue.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF15803D),
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      'All follow-ups are up to date! No overdue calls.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF15803D),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < overdue.take(4).length; i++) ...[
              if (i > 0) const Gap(20),
              Builder(
                builder: (_) {
                  final l = overdue[i];
                  final name = (l['name'] ?? 'Student Inquiry').toString();
                  final assigned =
                      l['assignedToName'] ?? l['assignedTo'] ?? '--';
                  final college = l['college'] ?? l['collegeBranch'] ?? '';
                  final course = (l['course'] ?? l['branch'] ?? '').toString();

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: const Color(0xFF1A1A1A),
                                letterSpacing: 0.2197,
                                height: 22.5 / 15,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              course.isNotEmpty
                                  ? 'Assigned: $assigned · $college\n$course'
                                  : 'Assigned: $assigned · $college',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 19.5 / 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      InkWell(
                        onTap: onReassign,
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: const Color(0xFF5C59B6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Re Assign',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF5C59B6),
                              letterSpacing: 0.1914,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

class _CollegeVisits extends StatelessWidget {
  final VoidCallback onPlanVisit;

  const _CollegeVisits({required this.onPlanVisit});

  static const _figmaVisits = [
    {'collegeName': 'Devagiri', 'purpose': 'AI ML', 'status': 'Completed'},
    {
      'collegeName': 'Don Bosco',
      'purpose': 'Promote Python & Data Science workshop · meet HOD',
      'status': 'Completed',
    },
    {
      'collegeName': 'GEC Kozhikode',
      'purpose': 'Industrial Visit registration drive',
      'status': 'Completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'College visits this week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                    letterSpacing: -0.2813,
                  ),
                ),
              ),
              const Gap(8),
              InkWell(
                onTap: onPlanVisit,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x333F3FB4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Plan Visit',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3F3FB4),
                      letterSpacing: 0.0752,
                      height: 16.5 / 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('college_visits')
                .snapshots(),
            builder: (context, snapshot) {
              final List<Map<String, dynamic>> displayVisits;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                displayVisits = snapshot.data!.docs
                    .take(4)
                    .map((d) => d.data())
                    .toList();
              } else {
                displayVisits = _figmaVisits;
              }

              return Column(
                children: [
                  for (var i = 0; i < displayVisits.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        color: Color(0xFFF3F4F6),
                        height: 24,
                        thickness: 1,
                      ),
                    Builder(
                      builder: (_) {
                        final v = displayVisits[i];
                        final name = (v['collegeName'] ?? 'College').toString();
                        final desc =
                            (v['purpose'] ?? v['subtitle'] ?? 'Campus visit')
                                .toString();
                        final status =
                            (v['status'] ?? v['statusLabel'] ?? 'Planned')
                                .toString();

                        Color badgeBg;
                        Color badgeFg;
                        if (status == 'Completed') {
                          badgeBg = const Color(0xFFE8F5E9);
                          badgeFg = const Color(0xFF2E7D32);
                        } else if (status == 'Cancelled') {
                          badgeBg = const Color(0xFFFEE2E2);
                          badgeFg = const Color(0xFFB91C1C);
                        } else {
                          badgeBg = const Color(0xFFEEF0FF);
                          badgeFg = _primary;
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () =>
                                    LinkLauncher.launchCollegeMapsDirections(
                                      name,
                                      locationHint: desc,
                                    ),
                                borderRadius: BorderRadius.circular(6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: const Color(0xFF1A1A1A),
                                              letterSpacing: -0.1465,
                                              height: 22.5 / 15,
                                            ),
                                          ),
                                        ),
                                        const Gap(4),
                                        const Icon(
                                          Icons.directions_outlined,
                                          size: 13,
                                          color: _primary,
                                        ),
                                      ],
                                    ),
                                    const Gap(2),
                                    Text(
                                      desc,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF6B7280),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.0127,
                                        height: 19.5 / 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Gap(12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: GoogleFonts.inter(
                                  color: badgeFg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.0752,
                                  height: 16.5 / 11,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

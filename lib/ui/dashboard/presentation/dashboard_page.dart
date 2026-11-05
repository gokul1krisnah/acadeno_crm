import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_models.dart';
import 'package:acadeno_crm/ui/follow_ups/data/model/follow_up_time_helper.dart';
import 'package:acadeno_crm/core/utils/url_dialer_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:acadeno_crm/shared/utilities/link_launcher.dart';
import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/svgs/logout.svg',
                width: 18,
                height: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign out',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of the dashboard?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await cubit.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
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
                final wide = c.maxWidth >= 960;
                final isMobile = c.maxWidth < 680;
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
                              horizontal: pad.clamp(16.0, 24.0),
                              vertical: pad.clamp(16.0, 20.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!showSidebar &&
                                    state.selectedNavIndex != 0) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
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
                                      InkWell(
                                        onTap: _logout,
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
                                          child: SvgPicture.asset(
                                            'assets/svgs/logout.svg',
                                            width: 16,
                                            height: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
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

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _header(
                                                me: me,
                                                isMobile: isMobile,
                                                showMenuButton: !showSidebar,
                                              ),
                                              const SizedBox(height: 20),
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
                                                const SizedBox(height: 20),
                                              ],
                                              _stats(rawLeads, activeUsers),
                                              const SizedBox(height: 24),
                                              if (wide)
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
                                                          const SizedBox(
                                                            height: 20,
                                                          ),
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
                                                    const SizedBox(width: 20),
                                                    Expanded(
                                                      flex: 42,
                                                      child: Column(
                                                        children: [
                                                          _Conversions(
                                                            leads: rawLeads,
                                                          ),
                                                          const SizedBox(
                                                            height: 20,
                                                          ),
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
                                                    const SizedBox(height: 16),
                                                    _Conversions(
                                                      leads: rawLeads,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    _OverdueFollowUps(
                                                      leads: rawLeads,
                                                      onReassign: () =>
                                                          cubit.selectNav(1),
                                                    ),
                                                    const SizedBox(height: 16),
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
                                  const UserManagementView()
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _primaryNav.length; i++)
                    _buildNavItem(
                      item: _primaryNav[i],
                      index: i,
                      selectedIndex: selectedIndex,
                      inDrawer: inDrawer,
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 16, 6),
                    child: Text(
                      'GENERAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (var i = 0; i < _generalNav.length; i++)
                    _buildNavItem(
                      item: _generalNav[i],
                      index: i + 5,
                      selectedIndex: selectedIndex,
                      inDrawer: inDrawer,
                    ),
                ],
              ),
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
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? const Color(0xFFFFF4ED) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            cubit.selectNav(index);
            if (inDrawer) {
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
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
    required bool isMobile,
    required bool showMenuButton,
  }) {
    if (isMobile) {
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
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: _pickDashboardDate,
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        _today,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFigmaSearchBar(width: double.infinity),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _orangeAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                "Assign Today's Leads",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              onPressed: () => context.read<DashboardCubit>().selectNav(1),
            ),
          ),
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
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: _pickDashboardDate,
                borderRadius: BorderRadius.circular(6),
                child: Text(
                  _today,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _buildFigmaSearchBar(width: 460),
        ),
        const SizedBox(width: 14),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orangeAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              "Assign Today's Leads",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            onPressed: () => context.read<DashboardCubit>().selectNav(1),
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaSearchBar({double? width}) {
    return Container(
      width: width,
      height: 50,
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
        style: const TextStyle(
          fontSize: 14.5,
          color: _text,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: _muted,
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
          hintStyle: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF94A3B8),
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
              const SizedBox(width: 12),
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
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 2),
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
          const SizedBox(height: 16),
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
                    const SizedBox(height: 10),
                    Text(
                      'No results found matching "$query"',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
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
              const SizedBox(height: 10),
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
                      const SizedBox(width: 12),
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
                                const SizedBox(width: 8),
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
                            const SizedBox(height: 2),
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
                      const SizedBox(width: 10),
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
              const SizedBox(height: 12),
              Text(
                'TEAM MEMBERS (${matchedUsers.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
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
                      const SizedBox(width: 12),
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
              const SizedBox(height: 12),
              Text(
                'CAMPUS VISITS (${matchedVisits.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
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
                      const SizedBox(width: 12),
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
        color: _primary,
        icon: Icons.groups_rounded,
        isSolidHero: true,
      ),
      _StatCard(
        label: 'Calls / Contacted',
        value: '$contactedCount/$totalAssigned',
        sub: '$contactedPct% of assigned',
        color: _primary,
        icon: Icons.phone_outlined,
      ),
      _StatCard(
        label: 'Follow-ups Due',
        value: '$followUpsCount',
        sub: 'Across ${activeUsers.length} active members',
        color: _orangeAccent,
        icon: Icons.calendar_today_outlined,
      ),
      _StatCard(
        label: 'Overdue / Pending',
        value: '$overdueCount',
        sub: 'Requires team attention',
        color: const Color(0xFF6B21A8),
        icon: Icons.hourglass_empty_rounded,
      ),
      _StatCard(
        label: 'Converted Leads',
        value: '$convertedCount',
        sub: '$conversionPct% conversion rate',
        color: const Color(0xFF16A34A),
        icon: Icons.star_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        if (w >= 560) {
          final cardW = (w - 24) / 3;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((c) => SizedBox(width: cardW, child: c))
                .toList(),
          );
        }

        final halfW = (w - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < cards.length; i++)
              SizedBox(
                width: i == cards.length - 1 ? w : halfW,
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
  final IconData? icon;
  final bool isSolidHero;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.icon,
    this.isSolidHero = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSolidHero) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F3F37C9),
              blurRadius: 10,
              offset: Offset(0, 4),
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
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (icon != null) Icon(icon, color: Colors.white, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD5D3FF),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Team Today',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '• LIVE',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No active team members registered yet.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 20),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _text,
                            ),
                          ),
                          Text(
                            '${r.called} / ${r.assigned} leads',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: _primary,
                          backgroundColor: const Color(0xFFF1F5F9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'INTERESTED: ${r.interested}',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CONVERTED: ${r.converted}',
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (r.overdue > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'OVERDUE: ${r.overdue}',
                                style: const TextStyle(
                                  color: Color(0xFFEA580C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
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
    );
  }
}

class _Conversions extends StatelessWidget {
  final List<Map<String, dynamic>> leads;

  const _Conversions({required this.leads});

  @override
  Widget build(BuildContext context) {
    final sourcesMap = <String, (int converted, int total)>{};
    for (final l in leads) {
      final rawSource = (l['source'] ?? 'Direct Visit').toString().trim();
      final src = rawSource.isEmpty ? 'Direct Visit' : rawSource;
      final isConverted = (l['status'] ?? '').toString().toLowerCase().contains(
        'convert',
      );
      final curr = sourcesMap[src] ?? (0, 0);
      sourcesMap[src] = (curr.$1 + (isConverted ? 1 : 0), curr.$2 + 1);
    }

    final List<(String, int, int)> displaySources = sourcesMap.isNotEmpty
        ? (sourcesMap.entries
              .map((e) => (e.key, e.value.$1, e.value.$2))
              .toList()
            ..sort((a, b) => b.$3.compareTo(a.$3)))
        : [
            ('AI & Machine Le...', 0, 18),
            ('Direct Visit', 1, 3),
            ('AI Webinar', 1, 2),
            ('Python Workshop', 1, 1),
            ('College Visit', 0, 1),
            ('Workshop', 0, 1),
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Conversions by source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              Text(
                '${leads.length} leads',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final r in displaySources.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      r.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: r.$3 > 0 ? (r.$2 / r.$3).clamp(0.0, 1.0) : 0.0,
                        minHeight: 7,
                        color: r.$1.toLowerCase().contains('direct')
                            ? _orangeAccent
                            : _primary,
                        backgroundColor: const Color(0xFFF1F5F9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${r.$2} / ${r.$3}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _text,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overdue Follow ups',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              InkWell(
                onTap: onReassign,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Manage in Leads',
                    style: TextStyle(
                      color: Color(0xFFEF8144),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (overdue.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF15803D),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All follow-ups are up to date! No overdue calls.',
                      style: TextStyle(
                        color: Color(0xFF15803D),
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
              if (i > 0) const SizedBox(height: 14),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Assigned: $assigned · $college',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                            if (course.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                course,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: onReassign,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4338CA),
                          side: const BorderSide(color: Color(0xFF4338CA)),


                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Reassign',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'College visits this week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              InkWell(
                onTap: onPlanVisit,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Plan Visit',
                    style: TextStyle(
                      color: Color(0xFFEF8144),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                    if (i > 0) const SizedBox(height: 14),
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
                          badgeBg = const Color(0xFFDCFCE7);
                          badgeFg = const Color(0xFF15803D);
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
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: _text,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.directions_outlined,
                                          size: 13,
                                          color: _primary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      desc,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: badgeFg,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
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

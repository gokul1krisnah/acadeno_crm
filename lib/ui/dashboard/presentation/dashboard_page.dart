import 'package:intl/intl.dart';
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

const _primary = Color(0xFF4338CA);
const _bg = Color(0xFFF5F6FA);
const _border = Color(0xFFE5E7EB);
const _muted = Color(0xFF6B7280);
const _text = Color(0xFF111827);

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
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasAutoHealedRole = false;

  static const _nav = [
    _NavItem(Icons.grid_view_rounded, 'Dashboard'),
    _NavItem(Icons.people_outline, 'Leads & assign'),
    _NavItem(Icons.track_changes_outlined, 'Campaigns'),
    _NavItem(Icons.schedule_outlined, 'Follow-ups'),
    _NavItem(Icons.location_on_outlined, 'College visits'),
    _NavItem(Icons.upload_outlined, 'Import'),
    _NavItem(Icons.groups_outlined, 'Team Management'),
    _NavItem(Icons.manage_accounts_outlined, 'User Management'),
    _NavItem(Icons.settings_outlined, 'Settings'),
  ];

  String get _today {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Sign out',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                final showSidebar = c.maxWidth >= 840;
                final wide = c.maxWidth >= 1000;
                final isMobile = c.maxWidth < 680;
                final pad = context.devicePadding;

                return Scaffold(
                  key: _scaffoldKey,
                  backgroundColor: _bg,
                  drawer: showSidebar
                      ? null
                      : Drawer(
                          width: 260,
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
                            padding: EdgeInsets.all(pad),
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
                                            Icons.logout,
                                            color: _muted,
                                            size: 20,
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
                                              SizedBox(height: pad),
                                              _stats(rawLeads, activeUsers),
                                              SizedBox(height: pad * 0.8),
                                              _pair(
                                                wide,
                                                _TeamToday(
                                                  activeUsers: activeUsers,
                                                  leads: rawLeads,
                                                ),
                                                _Conversions(leads: rawLeads),
                                              ),
                                              SizedBox(height: pad * 0.8),
                                              _pair(
                                                wide,
                                                _OverdueFollowUps(
                                                  leads: rawLeads,
                                                  onReassign: () =>
                                                      cubit.selectNav(1),
                                                ),
                                                _CollegeVisits(
                                                  onPlanVisit: () =>
                                                      cubit.selectNav(4),
                                                ),
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
    final rawRole = (me['role'] ?? '').toString().trim().toLowerCase();
    final roleLabel = (rawRole == 'hr') ? 'HR & Operation Manager' : 'Admin';

    // Auto-heal admin role in Firestore so the user is consistently tagged as admin
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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Image.asset(
              AppImages.logo,
              height: 44,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'ACADENO',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < _nav.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: Material(
                        color: selectedIndex == i
                            ? const Color(0xFFEEF0FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          leading: Icon(
                            _nav[i].icon,
                            size: 20,
                            color: selectedIndex == i ? _primary : _muted,
                          ),
                          title: Text(
                            _nav[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: selectedIndex == i
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _text,
                            ),
                          ),
                          onTap: () {
                            cubit.selectNav(i);
                            if (inDrawer) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () {
              if (inDrawer) Navigator.of(context).pop();
              cubit.selectNav(8);
            },
            borderRadius: BorderRadius.circular(8),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 12, right: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: _primary,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text(
                roleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showMenuButton) ...[
                InkWell(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
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
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_today · Acadeno Research & Innovation Centre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.read<DashboardCubit>().selectNav(8),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(
                    Icons.manage_accounts_outlined,
                    color: _primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _logout,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.logout, color: _muted, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _muted,
                ),
                hintText: 'Search name, phone, college...',
                hintStyle: const TextStyle(fontSize: 14, color: _muted),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: _primaryBtn,
              onPressed: () => context.read<DashboardCubit>().selectNav(1),
              child: const Text("Assign today's leads"),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 860;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_today · Acadeno Research & Innovation Centre',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _text,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.manage_accounts_outlined,
                        size: 18,
                        color: _primary,
                      ),
                      label: const Text(
                        'Admin Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () =>
                          context.read<DashboardCubit>().selectNav(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: _primaryBtn,
                      onPressed: () =>
                          context.read<DashboardCubit>().selectNav(1),
                      child: const Text("Assign today's leads"),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.logout, color: _muted, size: 22),
                    tooltip: 'Sign out',
                    onPressed: _logout,
                  ),
                ],
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
                      fontWeight: FontWeight.w700,
                      color: _text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_today · Acadeno Research & Innovation Centre',
                    style: const TextStyle(color: _muted, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _text,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(
                  Icons.manage_accounts_outlined,
                  size: 18,
                  color: _primary,
                ),
                label: const Text(
                  'Admin Account',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                onPressed: () => context.read<DashboardCubit>().selectNav(8),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: _primaryBtn,
                onPressed: () => context.read<DashboardCubit>().selectNav(1),
                child: const Text("Assign today's leads"),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.logout, color: _muted, size: 22),
              tooltip: 'Sign out',
              onPressed: _logout,
            ),
          ],
        );
      },
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

    final followUpsCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      return status == 'follow-up' || status == 'claimed';
    }).length;

    final overdueCount = leads.where((l) {
      final isDone = (l['isDone'] as bool?) ?? false;
      final status = (l['status'] ?? '').toString().toLowerCase();
      return !isDone &&
          (status == 'new' || status == 'follow-up' || status == 'claimed');
    }).length;

    final convertedCount = leads.where((l) {
      final status = (l['status'] ?? '').toString().toLowerCase();
      return status.contains('convert');
    }).length;
    final conversionPct = totalLeads > 0
        ? (convertedCount / totalLeads * 100).toStringAsFixed(1)
        : '0.0';

    final cards = [
      _StatCard(
        'Total leads',
        NumberFormat('#,###').format(totalLeads),
        totalLeads > 0 ? '$totalAssigned assigned to team' : 'No leads in pool',
        _text,
        icon: Icons.groups_rounded,
      ),
      _StatCard(
        'Calls / Contacted',
        '$contactedCount / ${totalAssigned > 0 ? totalAssigned : totalLeads}',
        '$contactedPct% of assigned',
        _primary,
        icon: Icons.phone_in_talk_rounded,
      ),
      _StatCard(
        'Follow-ups due',
        '$followUpsCount',
        'Across ${activeUsers.length} active members',
        const Color(0xFF1D4ED8),
        icon: Icons.event_repeat_rounded,
      ),
      _StatCard(
        'Overdue / Pending',
        '$overdueCount',
        overdueCount > 0 ? 'Requires team attention' : 'All clear',
        const Color(0xFFC2410C),
        icon: Icons.hourglass_top_rounded,
      ),
      _StatCard(
        'Converted leads',
        '$convertedCount',
        '$conversionPct% conversion rate',
        const Color(0xFF15803D),
        icon: Icons.stars_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Desktop: 5 columns
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

        // Tablet: 3 columns
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

        // Mobile phone: 2-column grid filling 100% width
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

  Widget _pair(bool wide, Widget a, Widget b) {
    final pad = context.devicePadding * 0.8;
    if (!wide) {
      return Column(
        children: [
          a,
          SizedBox(height: pad),
          b,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        SizedBox(width: pad),
        Expanded(child: b),
      ],
    );
  }
}

final _primaryBtn = ElevatedButton.styleFrom(
  backgroundColor: _primary,
  foregroundColor: Colors.white,
  elevation: 0,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
);

// ============================================================================
// Shared widgets
// ============================================================================
class _Panel extends StatelessWidget {
  final String title;
  final Widget? badge;
  final Widget? trailing;
  final Widget child;
  const _Panel({
    required this.title,
    required this.child,
    this.badge,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final panelPad = context.devicePadding.clamp(14.0, 20.0);
    return Container(
      padding: EdgeInsets.all(panelPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 430 && trailing != null) {
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (badge != null) badge!,
                    trailing!,
                  ],
                );
              }
              return Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (badge != null) ...[const SizedBox(width: 8), badge!],
                  if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                  const Spacer(),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final IconData? icon;

  const _StatCard(
    this.label,
    this.value,
    this.sub,
    this.color, {
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cardPad = context.devicePadding.clamp(14.0, 18.0);
    return Container(
      padding: EdgeInsets.all(cardPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              if (icon != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _badge(String text, Color bg, Color fg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
  child: Text(
    text,
    style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
  ),
);

// ============================================================================
// Dashboard sections
// ============================================================================
class _TeamToday extends StatelessWidget {
  final List<DashboardUserModel> activeUsers;
  final List<Map<String, dynamic>> leads;

  const _TeamToday({required this.activeUsers, required this.leads});

  @override
  Widget build(BuildContext context) {
    const h = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: _muted,
    );

    if (activeUsers.isEmpty) {
      return _Panel(
        title: 'Team today',
        badge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Live',
                style: TextStyle(
                  color: Color(0xFF15803D),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No active team members registered yet.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ),
        ),
      );
    }

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

    return _Panel(
      title: 'Team today',
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Live',
              style: TextStyle(
                color: Color(0xFF15803D),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
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
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${r.called} / ${r.assigned} leads',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                              minHeight: 6,
                              color: _primary,
                              backgroundColor: const Color(0xFFE5E7EB),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _badge(
                                'Interested: ${r.interested}',
                                const Color(0xFFEFF6FF),
                                const Color(0xFF1D4ED8),
                              ),
                              _badge(
                                'Converted: ${r.converted}',
                                const Color(0xFFECFDF5),
                                const Color(0xFF047857),
                              ),
                              if (r.overdue > 0)
                                _badge(
                                  'Overdue: ${r.overdue}',
                                  const Color(0xFFFFF7ED),
                                  const Color(0xFFC2410C),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            );
          }

          return Column(
            children: [
              const Row(
                children: [
                  Expanded(flex: 3, child: Text('EXECUTIVE', style: h)),
                  Expanded(
                    flex: 4,
                    child: Text('CALLS DONE / ASSIGNED', style: h),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'INTERESTED',
                      style: h,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CONVERTED',
                      style: h,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('OVERDUE', style: h, textAlign: TextAlign.left),
                  ),
                ],
              ),
              const Divider(),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              r.role,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: r.assigned > 0
                                      ? (r.called / r.assigned).clamp(0.0, 1.0)
                                      : 0.0,
                                  minHeight: 6,
                                  color: _primary,
                                  backgroundColor: const Color(0xFFE5E7EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${r.called} / ${r.assigned}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${r.interested}',
                          textAlign: TextAlign.left,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${r.converted}',
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${r.overdue}',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: r.overdue > 0
                                ? const Color(0xFFC2410C)
                                : _text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
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
      final rawSource = (l['source'] ?? 'Direct visit').toString().trim();
      final src = rawSource.isEmpty ? 'Direct visit' : rawSource;
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
            ('College webinars', 0, 0),
            ('Workshops', 0, 0),
            ('College visits', 0, 0),
            ('Direct visits', 0, 0),
            ('Industrial visits', 0, 0),
          ];

    return _Panel(
      title: 'Conversions by source',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${leads.length} leads',
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = constraints.maxWidth < 380 ? 100.0 : 120.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in displaySources.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Text(
                          r.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: r.$3 > 0
                                ? (r.$2 / r.$3).clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 14,
                            color: r.$1.toLowerCase().contains('direct')
                                ? const Color(0xFFEA6B3D)
                                : const Color(0xFF2B7BD8),
                            backgroundColor: const Color(0xFFEDEEF2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${r.$2}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: ' / ${r.$3}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'Converted / total leads from each source',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          );
        },
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
      final status = (l['status'] ?? '').toString().toLowerCase();
      return !isDone &&
          (status == 'follow-up' || status == 'claimed' || status == 'new');
    }).toList();

    return _Panel(
      title: 'Overdue follow-ups',
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: const BoxDecoration(
          color: Color(0xFFC2410C),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Text(
          '${overdue.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      trailing: TextButton(
        onPressed: onReassign,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: const Text('Manage in Leads'),
      ),
      child: overdue.isEmpty
          ? Container(
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
          : Column(
              children: [
                for (final l in overdue.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (l['name'] ?? 'Student Inquiry').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Assigned: ${l['assignedToName'] ?? l['assignedTo'] ?? 'Unassigned'} · ${l['college'] ?? l['collegeBranch'] ?? l['phone'] ?? ''}',
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
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: onReassign,
                          child: const Text('Reassign'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CollegeVisits extends StatelessWidget {
  final VoidCallback onPlanVisit;

  const _CollegeVisits({required this.onPlanVisit});

  static const _defaultVisits = [
    ['Thu 29', 'NIT Calicut', 'AI & ML workshop promo · Team visit', 'Planned'],
    [
      'Fri 30',
      'KMCT College of Engineering',
      'Placement cell meeting · Campus drive',
      'Planned',
    ],
    [
      'Thu 22',
      'GEC Kozhikode',
      'Industrial visit & student interaction',
      'Completed',
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'College visits this week',
      trailing: TextButton(
        onPressed: onPlanVisit,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: const Text('+ Plan visit'),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('college_visits')
            .snapshots(),
        builder: (context, snapshot) {
          final List<List<String>> displayVisits;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            displayVisits = snapshot.data!.docs.take(3).map((d) {
              final data = d.data();
              final day = ' ';
              final name = (data['collegeName'] ?? 'College').toString();
              final desc =
                  (data['purpose'] ?? data['subtitle'] ?? 'Campus visit')
                      .toString();
              final status =
                  (data['status'] ?? data['statusLabel'] ?? 'Planned')
                      .toString();
              return [day, name, desc, status];
            }).toList();
          } else {
            displayVisits = const [];
          }

          return Column(
            children: [
              for (final r in displayVisits) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          r[0],
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r[1],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              r[2],
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      r[3] == 'Completed'
                          ? _badge(
                              'Completed',
                              const Color(0xFFDCFCE7),
                              const Color(0xFF15803D),
                            )
                          : _badge(
                              'Planned',
                              const Color(0xFFEEF0FF),
                              _primary,
                            ),
                    ],
                  ),
                ),
                if (r != displayVisits.last) const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }
}

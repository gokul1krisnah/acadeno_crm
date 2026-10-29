import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';
import 'package:acadeno_crm/ui/auth/data/repository/firebase_auth_repo.dart';
import 'package:acadeno_crm/ui/auth/data/sources/firebase_auth_rds.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:acadeno_crm/ui/alerts/application/alerts_cubit.dart';
import 'package:acadeno_crm/ui/alerts/application/alerts_state.dart';
import 'package:acadeno_crm/ui/alerts/data/repository/alerts_repo.dart';
import 'package:acadeno_crm/ui/alerts/data/sources/alerts_rds.dart';
import 'package:acadeno_crm/ui/alerts/presentation/alerts_tab_view.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_cubit.dart';
import 'package:acadeno_crm/ui/follow_ups/application/follow_ups_state.dart';
import 'package:acadeno_crm/ui/follow_ups/data/repository/follow_ups_repo.dart';
import 'package:acadeno_crm/ui/follow_ups/data/sources/follow_ups_rds.dart';
import 'package:acadeno_crm/ui/follow_ups/presentation/follow_ups_tab_view.dart';
import 'package:acadeno_crm/ui/leads/application/leads_cubit.dart';
import 'package:acadeno_crm/ui/leads/application/leads_state.dart';
import 'package:acadeno_crm/ui/leads/data/repository/leads_repo.dart';
import 'package:acadeno_crm/ui/leads/data/sources/leads_rds.dart';
import 'package:acadeno_crm/ui/leads/presentation/leads_tab_view.dart';
import 'package:acadeno_crm/ui/visits/application/visits_cubit.dart';
import 'package:acadeno_crm/ui/visits/application/visits_state.dart';
import 'package:acadeno_crm/ui/visits/data/repository/visits_repo.dart';
import 'package:acadeno_crm/ui/visits/data/sources/visits_rds.dart';
import 'package:acadeno_crm/ui/visits/presentation/visits_tab_view.dart';

import '../application/home_cubit.dart';
import '../data/repository/home_repo.dart';
import '../data/sources/home_rds.dart';
import '../application/home_state.dart';

@RoutePage()
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeCubit(HomeRepository(HomeRds()))),
        BlocProvider(create: (_) => LeadsCubit(LeadsRepository(LeadsRds()))),
        BlocProvider(
          create: (_) => FollowUpsCubit(FollowUpsRepository(FollowUpsRds())),
        ),
        BlocProvider(create: (_) => VisitsCubit(VisitsRepository(VisitsRds()))),
        BlocProvider(create: (_) => AlertsCubit(AlertsRepository(AlertsRds()))),
      ],
      child: const _HomeScaffoldView(),
    );
  }
}

class _HomeScaffoldView extends StatefulWidget {
  const _HomeScaffoldView();

  @override
  State<_HomeScaffoldView> createState() => _HomeScaffoldViewState();
}

class _HomeScaffoldViewState extends State<_HomeScaffoldView> {
  final _authRepository = AuthRepository(
    FirebaseAuthRds(FirebaseAuth.instance),
  );

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign out',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Sign out of ${context.read<HomeCubit>().state.user.displayName}’s Lead Manager session? Local offline cache will be cleared (PR-6.3).',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475467)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF667085)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authRepository.signOut();
              isAdminSession = false;
              if (!mounted) return;
              context.router.replaceAll([const LoginRoute()]);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    final lower = msg.toLowerCase();
    final isError =
        lower.contains('locked') ||
        lower.contains('invalid') ||
        lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('duplicate');
    SnackBarAlert.showToast(context: context, message: msg, isWarning: isError);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<LeadsCubit, LeadsState>(
          listener: (context, state) {
            if (state.toastMessage == null) return;
            SnackBarAlert.showToast(
              context: context,
              message: state.toastMessage!,
              isWarning: state.isToastError,
            );
            context.read<LeadsCubit>().clearToast();
          },
        ),
        BlocListener<FollowUpsCubit, FollowUpsState>(
          listener: (context, state) {
            if (state.toastMessage == null) return;
            _showToast(state.toastMessage!);
            context.read<FollowUpsCubit>().clearToast();
          },
        ),
        BlocListener<VisitsCubit, VisitsState>(
          listener: (context, state) {
            if (state.toastMessage == null) return;
            _showToast(state.toastMessage!);
            context.read<VisitsCubit>().clearToast();
          },
        ),
        BlocListener<AlertsCubit, AlertsState>(
          listener: (context, state) {
            if (state.toastMessage == null) return;
            _showToast(state.toastMessage!);
            context.read<AlertsCubit>().clearToast();
          },
        ),
      ],
      child: _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final cubit = context.read<HomeCubit>();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 540;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F6FA),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWideScreen ? 460 : double.infinity,
                    ),
                    child: Container(
                      decoration: isWideScreen
                          ? const BoxDecoration(
                              color: Color(0xFFF5F6FA),
                              border: Border.symmetric(
                                vertical: BorderSide(color: Color(0xFFE4E7EC)),
                              ),
                            )
                          : null,
                      child: Column(
                        children: [
                          // Active Tab Screen
                          Expanded(
                            child: switch (state.bottomNavIndex) {
                              0 => LeadsTabView(onLogout: _logout),
                              1 => const FollowUpsTabView(),
                              2 => const VisitsTabView(),
                              3 => const AlertsTabView(),
                              _ => LeadsTabView(onLogout: _logout),
                            },
                          ),

                          // Bottom Navigation Bar (Exact match to all 4 screenshots)
                          _ExecutiveBottomNavBar(
                            currentIndex: state.bottomNavIndex,
                            onSelect: cubit.selectBottomNav,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExecutiveBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _ExecutiveBottomNavBar({
    required this.currentIndex,
    required this.onSelect,
  });

  static const _items = [
    (Icons.phone_outlined, 'Today'),
    (Icons.access_time_rounded, 'Follow-ups'),
    (Icons.location_on_outlined, 'Visits'),
    (Icons.notifications_none_rounded, 'Alerts'),
  ];

  @override
  Widget build(BuildContext context) {
    final hPad = context.devicePadding.clamp(12.0, 20.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAECF0))),
      ),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final isSelected = index == currentIndex;
          final item = _items[index];

          return InkWell(
            onTap: () => onSelect(index),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEEEDFD)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      item.$1,
                      size: 20,
                      color: isSelected
                          ? const Color(0xFF4338CA)
                          : const Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF4338CA)
                          : const Color(0xFF475467),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

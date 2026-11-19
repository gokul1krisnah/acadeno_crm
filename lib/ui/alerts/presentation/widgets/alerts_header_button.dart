import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:acadeno_crm/shared/theme/app_svgs.dart';
import 'package:acadeno_crm/ui/alerts/application/alerts_cubit.dart';
import 'package:acadeno_crm/ui/alerts/application/alerts_state.dart';
import 'package:acadeno_crm/ui/alerts/presentation/alerts_tab_view.dart';
import 'package:acadeno_crm/ui/home/application/home_cubit.dart';

/// Icon-only top-right Alerts button with live unread badge.
/// Opens the existing [AlertsTabView] while preserving [AlertsCubit], [HomeCubit],
/// unread counts, and permissions.
class AlertsHeaderButton extends StatelessWidget {
  const AlertsHeaderButton({super.key});

  void _openAlerts(BuildContext context) {
    AlertsCubit? alertsCubit;
    HomeCubit? homeCubit;
    try {
      alertsCubit = context.read<AlertsCubit>();
    } catch (_) {}
    try {
      homeCubit = context.read<HomeCubit>();
    } catch (_) {}

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          Widget page = const Scaffold(
            backgroundColor: Color(0xFFF9FAFB),
            body: SafeArea(
              child: AlertsTabView(showBackButton: true),
            ),
          );

          final providers = <BlocProvider>[
            if (alertsCubit != null)
              BlocProvider<AlertsCubit>.value(value: alertsCubit),
            if (homeCubit != null)
              BlocProvider<HomeCubit>.value(value: homeCubit),
          ];

          if (providers.isNotEmpty) {
            page = MultiBlocProvider(providers: providers, child: page);
          }

          return page;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AlertsCubit? alertsCubit;
    try {
      alertsCubit = context.read<AlertsCubit>();
    } catch (_) {}

    if (alertsCubit == null) {
      return _buildButton(context, 0);
    }

    return BlocBuilder<AlertsCubit, AlertsState>(
      builder: (context, state) {
        return _buildButton(context, state.unreadAlertsCount);
      },
    );
  }

  Widget _buildButton(BuildContext context, int unreadCount) {
    final badgeText = unreadCount > 9 ? '9+' : '$unreadCount';

    return Semantics(
      button: true,
      label: unreadCount > 0
          ? 'Alerts, $unreadCount unread'
          : 'Alerts',
      child: InkWell(
        onTap: () => _openAlerts(context),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
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
                  AppSvgs.reminder,
                  width: 17,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    unreadCount > 0
                        ? const Color(0xFF4338CA)
                        : const Color(0xFF4B5563),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeText,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

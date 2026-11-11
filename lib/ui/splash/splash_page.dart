import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:gap/gap.dart';
import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/theme/app_colors.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:acadeno_crm/shared/theme/app_typography.dart';
import 'package:acadeno_crm/ui/auth/application/login_cubit.dart';
import 'package:acadeno_crm/ui/auth/data/repository/firebase_auth_repo.dart';
import 'package:acadeno_crm/ui/auth/data/sources/firebase_auth_rds.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

@RoutePage()
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;

  // Clean logo entrance animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Clean title & subtitle reveal
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleSpacing;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Smooth subtle logo scale & fade
    _logoScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.05, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.05, 0.40, curve: Curves.easeOut),
    );

    // Subtitle text reveal
    _titleOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.30, 0.65, curve: Curves.easeOut),
    );

    _subtitleSpacing = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.30, 0.75, curve: Curves.easeOutQuart),
      ),
    );

    _introController.forward();
    _restoreAndNavigate();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  /// Restores the saved session while the splash plays, so the
  /// login screen never flashes for already signed-in users.
  Future<void> _restoreAndNavigate() async {
    final cubit = LoginCubit(
      AuthRepository(FirebaseAuthRds(FirebaseAuth.instance)),
    );

    bool restored = false;
    bool isAdmin = false;

    try {
      final results =
          await Future.wait<Object?>([
            cubit.restoreSession().timeout(
              const Duration(milliseconds: 2000),
              onTimeout: () => false,
            ),
            Future<Object?>.delayed(const Duration(milliseconds: 2000)),
          ]).timeout(
            const Duration(milliseconds: 2500),
            onTimeout: () => [false, null],
          );

      restored = (results.first as bool?) ?? false;
      isAdmin = cubit.isAdmin;

      // Offline safety fallback: if session restore timed out or returned false while offline,
      // verify if a cached user and Hive session exist locally.
      if (!restored) {
        final saved = cubit.savedSession;
        final currentUser = FirebaseAuth.instance.currentUser;
        if (saved != null &&
            currentUser != null &&
            saved.uid == currentUser.uid) {
          restored = true;
          isAdmin =
              saved.isAdmin ||
              currentUser.uid == 'aOt6zw43GPTebTKWAP4d0hQHYEz2' ||
              const [
                'admin',
                'super_admin',
              ].contains(saved.role?.toLowerCase());
        }
      }
    } catch (e) {
      debugPrint('Splash restore fallback notice: $e');
      final saved = cubit.savedSession;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (saved != null &&
          currentUser != null &&
          saved.uid == currentUser.uid) {
        restored = true;
        isAdmin = saved.isAdmin;
      }
    } finally {
      await cubit.close();
    }

    if (!mounted) return;

    if (!restored) {
      context.router.replaceAll([const LoginRoute()]);
    } else if (isAdmin) {
      context.router.replaceAll([const DashboardRoute()]);
    } else {
      context.router.replaceAll([const HomeRoute()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _introController,
          builder: (context, _) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.devicePadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pure Acadeno Logo - no background halo, no cards, no glow
                    Transform.scale(
                      scale: _logoScale.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Image.asset(
                          AppImages.logo,
                          height: 92,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const Gap(18),

                    // Clean Subtitle Text
                    Opacity(
                      opacity: _titleOpacity.value,
                      child: Text(
                        'ACADENO RESEARCH & INNOVATION CENTRE',
                        textAlign: TextAlign.center,
                        style: AppTypography.body(
                          size: 11.5,
                          weight: FontWeight.w700,
                          color: AppColors.secondary,
                        ).copyWith(letterSpacing: _subtitleSpacing.value),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

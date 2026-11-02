import 'dart:math' as math;

import 'package:acadeno_crm/core/router/app_router.dart';
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

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _pulseController;

  // 1. Top color bar expanding from center -> left & right
  late final Animation<double> _topBarExpand;
  late final Animation<double> _topBarGlowOpacity;

  // 2. Logo entrance (scale + slide + fade + shimmer sweep)
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _shimmerProgress;

  // 3. Staggered title, subtitle & bottom loader reveal
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleSpacing;
  late final Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Center-to-left-and-right top bar fill (0ms -> 950ms)
    _topBarExpand = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutQuart),
    );

    _topBarGlowOpacity =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.25), weight: 60),
        ]).animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.0, 0.55, curve: Curves.easeInOut),
          ),
        );

    // Logo entrance (200ms -> 1250ms)
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.10, 0.58, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.10, 0.42, curve: Curves.easeOut),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.10, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    // Diagonal light shimmer across the logo (900ms -> 1950ms)
    _shimmerProgress = Tween<double>(begin: -1.2, end: 2.2).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.42, 0.90, curve: Curves.easeInOutSine),
      ),
    );

    // Title & subtitle reveal (700ms -> 1500ms)
    _titleOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.34, 0.68, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.30), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.34, 0.70, curve: Curves.easeOutCubic),
          ),
        );

    _subtitleSpacing = Tween<double>(begin: 0.4, end: 2.4).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.40, 0.80, curve: Curves.easeOutQuart),
      ),
    );

    // Bottom progress loader reveal
    _loaderOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.50, 0.85, curve: Curves.easeOut),
    );

    _introController.forward();
    _restoreAndNavigate();
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Restores the saved session while the splash choreography plays, so the
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
            Future<Object?>.delayed(const Duration(milliseconds: 2200)),
          ]).timeout(
            const Duration(milliseconds: 2600),
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
    const barColors = [
      AppColors.indigo,
      AppColors.blue,
      AppColors.orange,
      AppColors.amber,
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_introController, _pulseController]),
          builder: (context, _) {
            return Column(
              children: [
                // =============================================================
                // 1. TOP COLOR BAR: Expands from Center -> Left & Right
                // =============================================================
                SizedBox(
                  height: 14,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Subtle base track
                      Container(
                        height: 6,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                      ),

                      // Center-outward expanding color bar
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          widthFactor: _topBarExpand.value.clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 6,
                                width: MediaQuery.sizeOf(context).width,
                                child: Image.asset(
                                  AppImages.topColorBar,
                                  fit: BoxFit.fill,
                                  errorBuilder: (_, _, _) => Row(
                                    children: [
                                      for (final c in barColors)
                                        Expanded(child: ColoredBox(color: c)),
                                    ],
                                  ),
                                ),
                              ),
                              // Soft glowing aura underneath the expanding bar
                              Opacity(
                                opacity: _topBarGlowOpacity.value,
                                child: Container(
                                  height: 6,
                                  width: MediaQuery.sizeOf(context).width,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.indigo.withValues(
                                          alpha: 0.35,
                                        ),
                                        AppColors.blue.withValues(alpha: 0.35),
                                        AppColors.orange.withValues(
                                          alpha: 0.35,
                                        ),
                                        AppColors.amber.withValues(alpha: 0.35),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // =============================================================
                // 2. CENTER ANIMATED LOGO STAGE & BRAND TYPOGRAPHY
                // =============================================================
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.devicePadding,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo + Ambient Halo Rings + Shimmer Sweep
                          SizedBox(
                            height: 150,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer breathing halo ring
                                Transform.scale(
                                  scale: 0.92 + (_pulseController.value * 0.14),
                                  child: Opacity(
                                    opacity:
                                        _logoOpacity.value *
                                        (0.18 -
                                            (_pulseController.value * 0.08)),
                                    child: Container(
                                      width: 220,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(80),
                                        gradient: const RadialGradient(
                                          colors: [
                                            Color(0xFF4338CA),
                                            Color(0xFFF97316),
                                            Colors.transparent,
                                          ],
                                          stops: [0.1, 0.55, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Clean floating logo without white card box
                                SlideTransition(
                                  position: _logoSlide,
                                  child: Transform.scale(
                                    scale: _logoScale.value,
                                    child: Opacity(
                                      opacity: _logoOpacity.value,
                                      child: ShaderMask(
                                        blendMode: BlendMode.srcATop,
                                        shaderCallback: (bounds) {
                                          final p = _shimmerProgress.value;
                                          return LinearGradient(
                                            begin: Alignment(p - 0.4, -0.3),
                                            end: Alignment(p + 0.4, 0.3),
                                            colors: [
                                              Colors.white.withValues(
                                                alpha: 0.0,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.55,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.0,
                                              ),
                                            ],
                                            stops: const [0.0, 0.5, 1.0],
                                          ).createShader(bounds);
                                        },
                                        child: Image.asset(
                                          AppImages.logo,
                                          height: 90,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Expanding Letter-Spacing Subtitle without 'Lead Manager' text
                          SlideTransition(
                            position: _titleSlide,
                            child: Opacity(
                              opacity: _titleOpacity.value,
                              child: Text(
                                'ACADENO RESEARCH & INNOVATION CENTRE',
                                textAlign: TextAlign.center,
                                style:
                                    AppTypography.body(
                                      size: 11.5,
                                      weight: FontWeight.w700,
                                      color: AppColors.secondary,
                                    ).copyWith(
                                      letterSpacing: _subtitleSpacing.value,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 42),

                          // ===================================================
                          // 3. CENTER-OUTWARD ANIMATED PROGRESS BAR
                          // ===================================================
                          Opacity(
                            opacity: _loaderOpacity.value,
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 160,
                                  height: 4,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          color: const Color(0xFFEAECF0),
                                        ),
                                        FractionallySizedBox(
                                          widthFactor:
                                              0.35 +
                                              0.65 *
                                                  (0.5 +
                                                      0.5 *
                                                          math.sin(
                                                            _pulseController
                                                                    .value *
                                                                math.pi,
                                                          )),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.indigo,
                                                  AppColors.blue,
                                                  AppColors.orange,
                                                  AppColors.amber,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

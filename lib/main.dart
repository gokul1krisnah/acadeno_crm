import 'package:acadeno_crm/shared/theme/app_colors.dart';
import 'package:acadeno_crm/shared/theme/app_typography.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/injection/injection.dart';
import 'core/router/app_router.dart';
import 'core/services/app_notification_service.dart';
import 'core/services/app_security_service.dart';
import 'firebase_options.dart';
import 'ui/auth/data/sources/auth_session_local_ds.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce screen security: Block screenshots, screen recordings, and switcher previews (PR-2.1)
  await AppSecurityService.instance.enableScreenshotProtection();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase Cloud Messaging Push & In-App Notification Service
  await AppNotificationService.instance.initialize();

  // Hive must be ready before the splash screen restores the session.
  await AuthSessionLocalDs.init();

  configureDependencies();

  runApp(const AcadenoApp());
}

class AcadenoApp extends StatefulWidget {
  const AcadenoApp({super.key});

  @override
  State<AcadenoApp> createState() => _AcadenoAppState();
}

class _AcadenoAppState extends State<AcadenoApp> {
  final AppRouter _appRouter = AppRouter();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Listen for incoming foreground push notifications
    AppNotificationService.instance.onForegroundMessage.listen((message) {
      final title = message.notification?.title ?? 'ACADENO CRM';
      final body = message.notification?.body ?? '';
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFE0E7FF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF312E81),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ACADENO CRM',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: AppTypography.fontFamily,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.white,
        useMaterial3: true,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          contentTextStyle: AppTypography.body(
            size: 13,
            weight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ),
      routerConfig: _appRouter.config(
        deepLinkBuilder: (_) => DeepLink([const SplashRoute()]),
      ),
    );
  }
}

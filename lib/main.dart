import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:auto_route/auto_route.dart';
import 'core/injection/injection.dart';
import 'core/router/app_router.dart';
import 'core/services/app_notification_service.dart';
import 'core/services/app_phone_call_service.dart';
import 'core/services/app_security_service.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/session_security_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared/theme/app_colors.dart';
import 'shared/theme/app_typography.dart';
import 'shared/widgets/offline_status_bar.dart';
import 'firebase_options.dart';
import 'ui/auth/data/sources/auth_session_local_ds.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error safety shield: prevent internal JS SDK assertion popups from breaking user UI
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher Error] $error');
    return true;
  };

  // Enforce screen security: Block screenshots, screen recordings, and switcher previews
  await AppSecurityService.instance.enableScreenshotProtection();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence & auto-reconnection for Firestore on mobile
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // 1. Hive local storage must be ready before services access persistence
  await AuthSessionLocalDs.init();
  await OfflineQueueService.init();
  OfflineQueueService.instance.initialize();
  AppPhoneCallService.instance.initialize();

  // 2. Initialize Firebase Cloud Messaging Push & Notification Service (resilient timeout)
  await AppNotificationService.instance.initialize().timeout(
    const Duration(milliseconds: 1500),
    onTimeout: () {},
  );

  configureDependencies();

  runApp(const AcadenoApp());
}

class AcadenoApp extends StatefulWidget {
  const AcadenoApp({super.key});

  @override
  State<AcadenoApp> createState() => _AcadenoAppState();
}

class _AcadenoAppState extends State<AcadenoApp> with WidgetsBindingObserver {
  final AppRouter _appRouter = AppRouter();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Attach real-time session revocation listener
    SessionSecurityService.instance.attachContext(
      router: _appRouter,
      messengerKey: _scaffoldMessengerKey,
    );
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        SessionSecurityService.instance.stopListening();
      }
    });
    // Listen for incoming foreground push notifications from Firebase
    AppNotificationService.instance.onForegroundMessage.listen((message) {
      final notif = message.notification;
      if (notif == null) return;
      final title = (notif.title ?? '').trim();
      final body = (notif.body ?? '').trim();
      if (title.isEmpty && body.isEmpty) return;
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the app is minimized/paused, gracefully pause Firestore network connection.
    // This prevents Android OS DNS lookup failures (UnknownHostException) in the background and saves battery.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      FirebaseFirestore.instance.disableNetwork().catchError((_) {});
    } else if (state == AppLifecycleState.resumed) {
      FirebaseFirestore.instance.enableNetwork().catchError((_) {});
    }
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
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
            elevation: WidgetStateProperty.all(4),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
            elevation: WidgetStateProperty.all(4),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return Material(
          color: Colors.white,
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: OfflineStatusBar(),
              ),
            ],
          ),
        );
      },
      routerConfig: _appRouter.config(
        deepLinkBuilder: (_) => DeepLink([const SplashRoute()]),
      ),
    );
  }
}

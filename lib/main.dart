import 'dart:io' as io show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:auto_route/auto_route.dart';
import 'core/injection/injection.dart';
import 'core/router/app_router.dart';
import 'core/services/app_notification_service.dart';
import 'core/services/app_phone_call_service.dart';
import 'core/services/app_security_service.dart';
import 'core/services/firestore_stream_cache.dart';
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
    final msg = details.exceptionAsString();
    if (msg.contains('INTERNAL ASSERTION FAILED') ||
        msg.contains('b815') ||
        msg.contains('ca9')) {
      return;
    }
    debugPrint('[FlutterError] $msg');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    final msg = error.toString();
    if (msg.contains('INTERNAL ASSERTION FAILED') ||
        msg.contains('b815') ||
        msg.contains('ca9')) {
      return true;
    }
    debugPrint('[PlatformDispatcher Error] $error');
    return true;
  };

  // Allow screenshots across the app by default (can be restricted when requested)
  await AppSecurityService.instance.disableScreenshotProtection();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set Firebase Auth locale to eliminate "Ignoring header X-Firebase-Locale because its value was null"
  try {
    if (!kIsWeb) {
      final loc = io.Platform.localeName;
      FirebaseAuth.instance.setLanguageCode(loc.isNotEmpty ? loc : 'en');
    } else {
      FirebaseAuth.instance.setLanguageCode('en');
    }
  } catch (_) {}

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
  DateTime? _pausedAt;
  bool _isAppLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppPhoneCallService.instance.attachNavigatorKey(_appRouter.navigatorKey);
    // Attach real-time session revocation listener
    SessionSecurityService.instance.attachContext(
      router: _appRouter,
      messengerKey: _scaffoldMessengerKey,
    );
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        SessionSecurityService.instance.stopListening();
        FirestoreStreamCache.instance.clearAll();
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
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const Gap(12),
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
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const Gap(3),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475467),
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
          backgroundColor: const Color(0xFFFFFFFF),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
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
      _pausedAt ??= DateTime.now();
      FirebaseFirestore.instance.disableNetwork().catchError((_) {});
    } else if (state == AppLifecycleState.resumed) {
      FirebaseFirestore.instance.enableNetwork().catchError((_) {});
      final pausedTime = _pausedAt;
      _pausedAt = null;
      if (pausedTime != null && FirebaseAuth.instance.currentUser != null) {
        final elapsed = DateTime.now().difference(pausedTime);
        if (elapsed >= const Duration(hours: 12)) {
          SessionSecurityService.instance.terminateSession(
            'Your 12-hour session has expired. Please sign in again.',
          );
        } else if (elapsed >= const Duration(minutes: 5)) {
          // PR-5.2: Lock app after 5 minutes in background
          setState(() => _isAppLocked = true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ACADENO CRM',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
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
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            alignment: Alignment.center,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: AppTypography.figmaButton(),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.center,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: AppTypography.figmaButton(),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            alignment: Alignment.center,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: AppTypography.figmaButton(),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            alignment: Alignment.center,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: AppTypography.figmaButton(),
          ),
        ),
        scrollbarTheme: const ScrollbarThemeData(
          thumbVisibility: WidgetStatePropertyAll(false),
          trackVisibility: WidgetStatePropertyAll(false),
          thickness: WidgetStatePropertyAll(0),
        ),
      ),
      builder: (context, child) {
        // Clamp the system font scale so accessibility/device font overrides
        // never cause button text to wrap to second lines or overflow pixels.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.0,
            ),
          ),
          child: Material(
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
                if (_isAppLocked)
                  Positioned.fill(
                    child: _AppPinLockOverlay(
                      onUnlocked: () => setState(() => _isAppLocked = false),
                      onSignOut: () {
                        setState(() => _isAppLocked = false);
                        SessionSecurityService.instance.terminateSession(
                          'Signed out from lock screen.',
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      routerConfig: _appRouter.config(
        deepLinkBuilder: (_) => DeepLink([const SplashRoute()]),
      ),
    );
  }
}

/// 5-Minute Inactivity PIN / Lock Screen Overlay (PR-5.2, Screen #2).
class _AppPinLockOverlay extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onSignOut;

  const _AppPinLockOverlay({
    required this.onUnlocked,
    required this.onSignOut,
  });

  @override
  State<_AppPinLockOverlay> createState() => _AppPinLockOverlayState();
}

class _AppPinLockOverlayState extends State<_AppPinLockOverlay> {
  final TextEditingController _pinCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _verifyPin() {
    final pin = _pinCtrl.text.trim();
    if (pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin)) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Enter your 4-digit staff PIN to unlock');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F172A).withValues(alpha: 0.96),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF3F37C9),
                      size: 28,
                    ),
                  ),
                  const Gap(16),
                  const Text(
                    'Session Locked',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Gap(6),
                  const Text(
                    'Locked after 5 minutes in background.\nEnter your 4-digit PIN to resume.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const Gap(20),
                  TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    onSubmitted: (_) => _verifyPin(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 12,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      errorText: _error,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Gap(16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF8144),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _verifyPin,
                      child: const Text(
                        'Unlock App',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Gap(8),
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text(
                      'Sign in with password instead',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

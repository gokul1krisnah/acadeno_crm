import 'package:hive/hive.dart';
import '../../ui/auth/data/sources/auth_session_local_ds.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // When a RemoteMessage contains a `notification` payload, the Android system
    // tray displays it automatically. We only show a manual local notification if
    // the payload is data-only (no system notification block).
    if (!kIsWeb && message.notification == null) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'acadeno_crm_high_importance',
        'Acadeno Reminders & Leads',
        channelDescription: 'High priority alerts for assigned student leads and reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        tag: 'lead_assigned',
        icon: '@drawable/ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
        color: Color(0xFFEA580C),
        styleInformation: BigTextStyleInformation(''),
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      final title = message.data['title'] ?? 'Reminder';
      final body = message.data['body'] ?? 'You have a new update';

      await localNotifications.show(
        id: 1001,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    }
  } catch (_) {}
}

/// Core Push & In-App Notification Service for ACADENO CRM.
/// Manages FCM token registration, system permissions, and foreground/background delivery.
class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Completer<String>? _initialTokenCompleter;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  bool _isSyncingToken = false;
  String? _lastSyncedToken;
  String? _lastSyncedUid;

  Timer? _morningTimer;
  Timer? _morningPeriodicTimer;
  static const String _morningDatePrefKey = 'last_morning_briefing_date';
  static String? _inMemoryLastDate;

  Future<String?> _getLastMorningDateAsync() async {
    try {
      if (!Hive.isBoxOpen(AuthSessionLocalDs.boxName)) {
        await Hive.openBox<dynamic>(AuthSessionLocalDs.boxName);
      }
      final box = Hive.box<dynamic>(AuthSessionLocalDs.boxName);
      final val = box.get(_morningDatePrefKey)?.toString();
      if (val != null) {
        _inMemoryLastDate = val;
        return val;
      }
    } catch (_) {}
    return _inMemoryLastDate;
  }

  Future<void> _saveLastMorningDateAsync(String date) async {
    _inMemoryLastDate = date;
    try {
      if (!Hive.isBoxOpen(AuthSessionLocalDs.boxName)) {
        await Hive.openBox<dynamic>(AuthSessionLocalDs.boxName);
      }
      final box = Hive.box<dynamic>(AuthSessionLocalDs.boxName);
      await box.put(_morningDatePrefKey, date);
    } catch (_) {}
  }

  final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();

  /// Stream of foreground push messages for UI snackbars or in-app toasts.
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessageController.stream;

  /// Initializes push notification channels, requests permissions, and captures FCM token.
  Future<void> initialize() async {
    try {
      // 1. Setup Android high-importance notification channel with Acadeno brand icons
      if (!kIsWeb) {
        const androidInit = AndroidInitializationSettings(
          '@drawable/ic_notification',
        );
        const initSettings = InitializationSettings(android: androidInit);
        await _localNotifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (response) {
            debugPrint('User opened local notification: ${response.payload}');
          },
        );

        const androidChannel = AndroidNotificationChannel(
          'acadeno_crm_high_importance',
          'Acadeno Reminders & Leads',
          description: 'High priority alerts for assigned student leads and reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(androidChannel);

        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      }

      // 2. Request user notification permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        'FCM Notification permission status: ${settings.authorizationStatus}',
      );

      // 3. Configure foreground presentation options (heads-up banner & sound)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Listen to token registration & refresh events cleanly
      try {
        _fcm.onRegistered.listen((newToken) {
          _fcmToken = newToken;
          if (_initialTokenCompleter != null &&
              !_initialTokenCompleter!.isCompleted) {
            _initialTokenCompleter!.complete(newToken);
          }
          syncCurrentUserToken();
        });
      } catch (_) {}

      // 5. Trigger FCM registration
      try {
        _initialTokenCompleter = Completer<String>();
        await _fcm.register();
        final registeredToken = await _initialTokenCompleter!.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => _fcmToken ?? '',
        );
        if (registeredToken.isNotEmpty) {
          _fcmToken = registeredToken;
          debugPrint('FCM Device Token: $_fcmToken');
        }
      } catch (e) {
        debugPrint('FCM register notice (offline or skipped): $e');
      }

      // 6. Listen to incoming foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _foregroundMessageController.add(message);
        // Show native Android system notification in notification shade & heads-up
        if (!kIsWeb) {
          final notif = message.notification;
          final title = (notif?.title ?? message.data['title'] ?? 'Reminder').toString().trim();
          final body = (notif?.body ?? message.data['body'] ?? 'You have a new update').toString().trim();
          if (title.isNotEmpty || body.isNotEmpty) {
            showNativeNotification(
              title: title.isNotEmpty ? title : 'Reminder',
              body: body,
              payload: message.data['leadId'] ?? message.data['target'] ?? '',
            );
          }
        }
      });

      // 7. Handle notification taps when app is in background or opened
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          'User opened push notification: ${message.notification?.title}',
        );
      });

      // 8. Auto-sync token whenever staff signs in or auth state changes
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          syncUserFcmToken(user.uid);
        } else {
          _lastSyncedUid = null;
          _lastSyncedToken = null;
        }
      });

      // 9. Start automated 9:00 AM daily morning notification
      scheduleDailyMorningBriefing();
    } catch (e) {
      debugPrint('AppNotificationService init notice: $e');
    }
  }

  /// Displays an Android system tray notification matching Figma 1824:1634
  /// with the peach/orange bell badge, #EA580C accent color, and expandable body text.
  Future<void> showNativeNotification({
    required String title,
    required String body,
    String? tag,
    String? payload,
    int id = 1001,
  }) async {
    if (kIsWeb) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        'acadeno_crm_high_importance',
        'Acadeno Reminders & Leads',
        channelDescription: 'High priority alerts for assigned student leads and reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        tag: tag ?? 'lead_assigned',
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_notification_large'),
        color: const Color(0xFFEA580C),
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: 'Acadeno CRM',
        ),
      );
      final details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Schedules the automated daily 9:00 AM "Good morning!" notification
  Future<void> scheduleDailyMorningBriefing() async {
    try {
      final now = DateTime.now();
      final todayDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Check persistent Hive storage: only trigger if NOT already triggered today (never re-trigger on app restarts!)
      final lastTriggered = await _getLastMorningDateAsync();
      if (now.hour >= 9 && lastTriggered != todayDate) {
        await _triggerDailyMorningBriefing(todayDate);
      }

      // 2. Calculate delay until next 9:00 AM
      var nextNineAm = DateTime(now.year, now.month, now.day, 9, 0, 0);
      if (now.isAfter(nextNineAm)) {
        nextNineAm = nextNineAm.add(const Duration(days: 1));
      }
      final delay = nextNineAm.difference(now);

      _morningTimer?.cancel();
      _morningTimer = Timer(delay, () async {
        final triggerNow = DateTime.now();
        final triggerDate =
            '${triggerNow.year}-${triggerNow.month.toString().padLeft(2, '0')}-${triggerNow.day.toString().padLeft(2, '0')}';
        await _triggerDailyMorningBriefing(triggerDate);

        // Recurring 24-hour interval
        _morningPeriodicTimer?.cancel();
        _morningPeriodicTimer = Timer.periodic(const Duration(hours: 24), (
          _,
        ) async {
          final recurringNow = DateTime.now();
          final recurringDate =
              '${recurringNow.year}-${recurringNow.month.toString().padLeft(2, '0')}-${recurringNow.day.toString().padLeft(2, '0')}';
          await _triggerDailyMorningBriefing(recurringDate);
        });
      });
    } catch (e) {
      debugPrint('scheduleDailyMorningBriefing error: $e');
    }
  }

  String _getTimeBasedGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning! ☀️';
    if (h < 17) return 'Good afternoon! 🌤️';
    return 'Good evening! 🌙';
  }

  Future<void> _triggerDailyMorningBriefing(String todayDate) async {
    final lastTriggered = await _getLastMorningDateAsync();
    if (lastTriggered == todayDate) return;
    await _saveLastMorningDateAsync(todayDate);

    final greeting = _getTimeBasedGreeting();

    // Show native Android system tray notification with Acadeno logo & sound
    await showNativeNotification(
      title: '$greeting Acadeno CRM',
      body:
          'Your daily schedule and student lead follow-ups are ready. Check today\'s tasks!',
      tag: 'daily_greeting_$todayDate',
      id: 9001,
    );

    // Save alert into Firestore alerts collection for this executive
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final alertDoc = _firestore
            .collection('alerts')
            .doc('daily_greeting_${uid}_$todayDate');
        await alertDoc.set({
          'id': alertDoc.id,
          'recipientUid': uid,
          'title': greeting,
          'subtitle':
              'Your daily schedule and student lead follow-ups are ready.',
          'category': 'greeting',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'dateLabel': 'Today',
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Syncs the current device FCM token to the user's Firestore document.
  Future<void> syncCurrentUserToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      await syncUserFcmToken(uid);
    }
  }

  /// Saves the device FCM token to `users/{uid}` in Firestore so the backend can target this user.
  Future<void> syncUserFcmToken(String uid) async {
    if (_isSyncingToken) return;
    if (_fcmToken != null &&
        _fcmToken!.isNotEmpty &&
        _lastSyncedUid == uid &&
        _lastSyncedToken == _fcmToken) {
      return;
    }

    _isSyncingToken = true;
    try {
      // Allow initial Firestore auth/session listeners to settle before writing token
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (_auth.currentUser?.uid != uid) return;

      if (_fcmToken == null || _fcmToken!.isEmpty) {
        _fcmToken = await refreshToken();
      }

      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        try {
          await _firestore.collection('users').doc(uid).set({
            'fcmToken': _fcmToken,
            'fcmUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          _lastSyncedUid = uid;
          _lastSyncedToken = _fcmToken;
          debugPrint(
            '✅ Automatically registered device token to Firestore users/$uid',
          );
        } catch (e) {
          final msg = e.toString();
          if (!msg.contains('INTERNAL ASSERTION FAILED') &&
              !msg.contains('b815') &&
              !msg.contains('ca9')) {
            debugPrint('Failed to save FCM token to users/$uid: $e');
          }
        }
      }
    } finally {
      _isSyncingToken = false;
    }
  }

  /// Forces a fresh FCM device token retrieval and syncs it with Firestore.
  Future<String?> refreshToken() async {
    try {
      _initialTokenCompleter = Completer<String>();
      await _fcm.register();
      final freshToken = await _initialTokenCompleter!.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => _fcmToken ?? '',
      );
      if (freshToken.isNotEmpty) {
        _fcmToken = freshToken;
      }
      await syncCurrentUserToken();
      return _fcmToken;
    } catch (e) {
      debugPrint('Error refreshing FCM token: $e');
      return null;
    }
  }

  void dispose() {
    _morningTimer?.cancel();
    _morningPeriodicTimer?.cancel();
    _foregroundMessageController.close();
  }
}

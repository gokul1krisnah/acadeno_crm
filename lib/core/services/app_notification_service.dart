import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Show Android heads-up notification in system tray when backgrounded
    if (!kIsWeb) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'acadeno_crm_high_importance',
        'Acadeno Lead Notifications',
        channelDescription: 'High priority alerts for assigned student leads',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      final title = message.notification?.title ?? message.data['title'] ?? '📞 Acadeno CRM';
      final body = message.notification?.body ?? message.data['body'] ?? 'You have a new update';

      await localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();

  /// Stream of foreground push messages for UI snackbars or in-app toasts.
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessageController.stream;

  /// Initializes push notification channels, requests permissions, and captures FCM token.
  Future<void> initialize() async {
    try {
      // 1. Setup Android high-importance notification channel
      if (!kIsWeb) {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _localNotifications.initialize(settings: initSettings);

        const androidChannel = AndroidNotificationChannel(
          'acadeno_crm_high_importance',
          'Acadeno Lead Notifications',
          description: 'High priority alerts for assigned student leads',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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

      // 4. Retrieve FCM device token
      try {
        _fcmToken = await _fcm.getToken();
        debugPrint('FCM Device Token: $_fcmToken');
      } catch (e) {
        debugPrint('FCM getToken notice: $e');
      }

      // 5. Listen to token refresh events
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        syncCurrentUserToken();
      });

      // 6. Listen to incoming foreground messages & trigger local notification heads-up
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _foregroundMessageController.add(message);
        if (!kIsWeb) {
          showNativeNotification(
            title: message.notification?.title ?? message.data['title'] ?? '📞 Acadeno CRM',
            body: message.notification?.body ?? message.data['body'] ?? 'New lead assigned',
          );
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
        }
      });

      // 9. Sync token if user is already signed in
      await syncCurrentUserToken();
    } catch (e) {
      debugPrint('AppNotificationService init notice: $e');
    }
  }

  /// Displays an Android system tray heads-up banner with sound and vibration
  Future<void> showNativeNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'acadeno_crm_high_importance',
        'Acadeno Lead Notifications',
        channelDescription: 'High priority alerts for assigned student leads',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
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
    if (_fcmToken == null || _fcmToken!.isEmpty) {
      try {
        _fcmToken = await _fcm.getToken();
      } catch (_) {}
    }

    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid).set({
          'fcmToken': _fcmToken,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ Automatically registered device token to Firestore users/$uid');
      } catch (e) {
        debugPrint('Failed to save FCM token to users/$uid: $e');
      }
    }
  }

  /// Forces a fresh FCM device token retrieval and syncs it with Firestore.
  Future<String?> refreshToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      await syncCurrentUserToken();
      return _fcmToken;
    } catch (e) {
      debugPrint('Error refreshing FCM token: $e');
      return null;
    }
  }

  void dispose() {
    _foregroundMessageController.close();
  }
}

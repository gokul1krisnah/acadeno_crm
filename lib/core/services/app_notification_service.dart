import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
      // 1. Register background message handler on native platforms
      if (!kIsWeb) {
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

      // 6. Listen to incoming foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _foregroundMessageController.add(message);
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

  /// Dispatches a test push notification: fires foreground listener and logs to Firestore `notification_queue`.
  Future<void> sendLocalTestNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final message = RemoteMessage(
      notification: RemoteNotification(
        title: title,
        body: body,
      ),
      data: data ?? {'type': 'test'},
      sentTime: DateTime.now(),
    );

    // 1. Emit to in-app foreground listeners
    _foregroundMessageController.add(message);

    // 2. Persist to Firestore `notification_queue`
    try {
      final user = _auth.currentUser;
      await _firestore.collection('notification_queue').add({
        'title': title,
        'body': body,
        'data': data ?? {'type': 'test'},
        'recipientUid': user?.uid,
        'recipientEmail': user?.email,
        'fcmToken': _fcmToken,
        'status': 'sent_locally',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error recording test notification to Firestore: $e');
    }
  }

  void dispose() {
    _foregroundMessageController.close();
  }
}


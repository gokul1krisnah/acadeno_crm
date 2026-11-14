import 'dart:async';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/auth/data/sources/auth_session_local_ds.dart';
import '../router/app_router.dart';
import 'firestore_stream_cache.dart';
import 'offline_queue_service.dart';

/// Central Real-Time Session Security & Remote Deactivation Listener.
///
/// Ensures accounts deactivated or remotely signed out in Super Admin console
/// immediately terminate on the user's device (< 1 sec) via live Firestore snapshot.
class SessionSecurityService {
  SessionSecurityService._();
  static final SessionSecurityService instance = SessionSecurityService._();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  String? _monitoredUid;
  String? _initialLogoutToken;
  Timestamp? _initialLogoutAt;
  bool _isTerminating = false;

  AppRouter? _router;
  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  /// Attaches global router and messenger from [AcadenoApp].
  void attachContext({
    required AppRouter router,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  }) {
    _router = router;
    _messengerKey = messengerKey;
  }

  /// Starts listening to real-time `users/{uid}` updates for remote revocation.
  void startListening(
    String uid, {
    String? initialLogoutToken,
    Timestamp? initialLogoutAt,
  }) {
    if (_monitoredUid == uid && _userDocSub != null) return;
    _monitoredUid = uid;
    _isTerminating = false;
    _initialLogoutToken = initialLogoutToken;
    _initialLogoutAt = initialLogoutAt;

    _userDocSub?.cancel();

    _userDocSub = FirestoreStreamCache.instance
        .watchDoc('users', uid)
        .listen(
          (doc) => _handleUserDocUpdate(doc),
          onError: (err) {
            // Silently suppress permission-denied / network cancellation during logout
            debugPrint('[SessionSecurityService] Listener stream closed: $err');
          },
        );
  }

  /// Evaluates real-time document updates to trigger instant session termination.
  Future<void> _handleUserDocUpdate(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_isTerminating) return;
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    if (currentAuthUser == null || currentAuthUser.uid != doc.id) {
      await stopListening();
      return;
    }

    if (!doc.exists) {
      await terminateSession(
        'Your account is no longer registered. Session terminated.',
      );
      return;
    }

    final data = doc.data() ?? {};

    // 1. Remote Account Deactivation Check
    final isActive = data['isActive'] as bool? ?? true;
    final status = (data['status'] as String?)?.toLowerCase();
    if (!isActive || status == 'inactive') {
      await terminateSession(
        'Your account has been deactivated by Super Admin.',
      );
      return;
    }

    // 2. Initial state initialization: Capture the existing tokens present on first snapshot
    final serverLogoutToken = data['forceLogoutToken'] as String?;
    final serverLogoutAt = data['forceLogoutAt'] as Timestamp?;

    if (_initialLogoutToken == null && _initialLogoutAt == null) {
      _initialLogoutToken = serverLogoutToken;
      _initialLogoutAt = serverLogoutAt;
      return;
    }

    // 3. Detect if a NEW force-logout has been triggered since login
    final hasNewToken =
        serverLogoutToken != null &&
        serverLogoutToken.isNotEmpty &&
        serverLogoutToken != _initialLogoutToken;

    final hasNewTimestamp =
        serverLogoutAt != null &&
        (_initialLogoutAt == null ||
            serverLogoutAt.compareTo(_initialLogoutAt!) > 0);

    if (hasNewToken || hasNewTimestamp) {
      _initialLogoutToken = serverLogoutToken;
      _initialLogoutAt = serverLogoutAt;

      final isDeviceReset = (data['deviceBound'] as bool? ?? true) == false;
      final msg = isDeviceReset
          ? 'Your phone binding was reset by Super Admin. Please sign in again on your new phone.'
          : 'Your session was remotely terminated by Super Admin.';
      await terminateSession(msg);
      return;
    }
  }

  /// Instantly revokes session, purges local credentials, shows alert, and redirects to login.
  Future<void> terminateSession(String reasonMessage) async {
    if (_isTerminating) return;
    _isTerminating = true;

    try {
      await stopListening();
      await FirebaseAuth.instance.signOut();
      await AuthSessionLocalDs().clear();
      await OfflineQueueService.instance.clearAll();
      FirestoreStreamCache.instance.clearAll();
      isAdminSession = false;

      // Show high-priority red alert snackbar
      _messengerKey?.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.gpp_bad_rounded, color: Colors.white, size: 22),
              const Gap(10),
              Expanded(
                child: Text(
                  reasonMessage,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Force navigate back to LoginRoute
      _router?.replaceAll([const LoginRoute()]);
    } catch (e) {
      debugPrint('[SessionSecurityService] Error during terminateSession: $e');
    } finally {
      _isTerminating = false;
    }
  }

  /// Cancels live listener cleanly.
  Future<void> stopListening() async {
    final sub = _userDocSub;
    _userDocSub = null;
    _monitoredUid = null;
    try {
      await sub?.cancel();
    } catch (_) {}
  }
}

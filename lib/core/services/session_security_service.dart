import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/auth/data/sources/auth_session_local_ds.dart';
import '../router/app_router.dart';

/// Central Real-Time Session Security & Remote Deactivation Listener (PR-5.3).
///
/// Ensures accounts deactivated or remotely signed out in Super Admin console
/// immediately terminate on the user's device (< 1 sec) via live Firestore snapshot.
class SessionSecurityService {
  SessionSecurityService._();
  static final SessionSecurityService instance = SessionSecurityService._();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  String? _monitoredUid;
  String? _knownLogoutToken;
  DateTime? _sessionStartedAt;
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

  /// Marks the current login session timestamp.
  void recordLoginSession({DateTime? loginTime, String? initialLogoutToken}) {
    _sessionStartedAt = loginTime ?? DateTime.now();
    _knownLogoutToken = initialLogoutToken;
    _isTerminating = false;
  }

  /// Starts listening to real-time `users/{uid}` updates for remote revocation.
  void startListening(String uid) {
    if (_monitoredUid == uid && _userDocSub != null) return;
    _monitoredUid = uid;
    _isTerminating = false;
    _userDocSub?.cancel();

    _sessionStartedAt ??= DateTime.now();

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) => _handleUserDocUpdate(doc),
          onError: (err) {
            debugPrint('[SessionSecurityService] Snapshot error: $err');
          },
        );
  }

  /// Evaluates real-time document updates to trigger instant session termination (PR-5.3).
  Future<void> _handleUserDocUpdate(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_isTerminating) return;
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    if (currentAuthUser == null || currentAuthUser.uid != doc.id) return;

    if (!doc.exists) {
      await terminateSession('Your account is no longer registered. Session terminated.');
      return;
    }

    final data = doc.data() ?? {};

    // 1. Remote Account Deactivation Check (PR-5.3)
    final isActive = data['isActive'] as bool? ?? true;
    final status = (data['status'] as String?)?.toLowerCase();
    if (!isActive || status == 'inactive') {
      await terminateSession('Your account has been deactivated by Super Admin (PR-5.3).');
      return;
    }

    // 2. Remote Force Sign Out Token Check
    final serverLogoutToken = data['forceLogoutToken'] as String?;
    if (serverLogoutToken != null && serverLogoutToken.isNotEmpty) {
      if (_knownLogoutToken == null) {
        // Initial token recorded upon listener start
        _knownLogoutToken = serverLogoutToken;
      } else if (serverLogoutToken != _knownLogoutToken) {
        _knownLogoutToken = serverLogoutToken;
        final isDeviceReset = (data['deviceBound'] as bool? ?? true) == false;
        final msg = isDeviceReset
            ? 'Your phone binding was reset by Super Admin (PR-5.1). Please sign in again on your new phone.'
            : 'Your session was remotely terminated by Super Admin (PR-5.3).';
        await terminateSession(msg);
        return;
      }
    }

    // 3. Force Logout Timestamp Check (backup check against session start)
    final forceLogoutAtRaw = data['forceLogoutAt'];
    if (forceLogoutAtRaw is Timestamp) {
      final forceLogoutDate = forceLogoutAtRaw.toDate();
      if (_sessionStartedAt != null &&
          forceLogoutDate.isAfter(_sessionStartedAt!.add(const Duration(seconds: 1)))) {
        final isDeviceReset = (data['deviceBound'] as bool? ?? true) == false;
        final msg = isDeviceReset
            ? 'Your phone binding was reset by Super Admin (PR-5.1). Please sign in again on your new phone.'
            : 'Your session was remotely terminated by Super Admin (PR-5.3).';
        await terminateSession(msg);
        return;
      }
    }
  }

  /// Instantly revokes session, purges local credentials, shows alert, and redirects to login (PR-5.3).
  Future<void> terminateSession(String reasonMessage) async {
    if (_isTerminating) return;
    _isTerminating = true;

    try {
      await stopListening();
      await FirebaseAuth.instance.signOut();
      await AuthSessionLocalDs().clear();
      isAdminSession = false;

      // Show high-priority red alert snackbar
      _messengerKey?.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.gpp_bad_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  /// Cancels live listener.
  Future<void> stopListening() async {
    await _userDocSub?.cancel();
    _userDocSub = null;
    _monitoredUid = null;
  }
}

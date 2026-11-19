import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../sources/auth_session_local_ds.dart';
import '../sources/firebase_auth_rds.dart';

class AuthRepository {
  AuthRepository(this._authRds, [AuthSessionLocalDs? sessionDs])
    : _sessionDs = sessionDs ?? AuthSessionLocalDs();

  final FirebaseAuthRds _authRds;
  final AuthSessionLocalDs _sessionDs;
  AuthSession? _savedSession;

  /// Cached metadata of the currently restored or saved session.
  AuthSession? get savedSession => _savedSession;

  /// Signs in via Firebase and returns the authenticated [User].
  Future<User> signIn({required String email, required String password}) async {
    final credential = await _authRds.signIn(email: email, password: password);
    return credential.user!;
  }

  /// Registers a new user via Firebase and returns the created [User].
  Future<User> register({
    required String email,
    required String password,
  }) async {
    final credential = await _authRds.register(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  /// Signs out from Firebase Auth and clears persisted session metadata from Hive.
  Future<void> signOut({bool unbindDevice = true}) async {
    await clearSession();
    await _authRds.signOut(unbindDevice: unbindDevice);
  }

  /// Persists non-sensitive session metadata in Hive after a successful login.
  Future<void> saveSession(
    User user, {
    String? role,
    bool isAdmin = false,
  }) async {
    await _sessionDs.save(
      uid: user.uid,
      email: user.email ?? '',
      role: role,
      isAdmin: isAdmin,
    );
    _savedSession = AuthSession(
      uid: user.uid,
      email: user.email ?? '',
      savedAt: DateTime.now(),
      role: role,
      isAdmin: isAdmin,
    );
  }

  /// Clears persisted session metadata from Hive.
  Future<void> clearSession() async {
    _savedSession = null;
    await _sessionDs.clear();
  }

  /// Restores the previous session after an app restart.
  ///
  /// Returns the signed-in [User] or null when there is no valid session.
  /// Sets [sessionVerifiedOnline] to false if the backend was unreachable
  /// (the session is then trusted from local state only).
  Future<User?> restoreSession() async {
    // 1. Wait for Firebase Auth to finish hydrating persisted credentials on cold start
    // (especially important on Web IndexedDB and cold mobile restarts).
    User? user = currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
      } catch (_) {
        user = currentUser;
      }
    }

    final saved = await _sessionDs.read();
    _savedSession = saved;

    // No authenticated Firebase user -> session cannot be restored.
    if (user == null) {
      await clearSession();
      return null;
    }

    // If Hive had metadata for a different UID, discard the stale metadata (do not sign out the valid Firebase user).
    if (saved != null && saved.uid != user.uid) {
      await clearSession();
    }

    try {
      // Validates and refreshes the backend auth token (fails if disabled/deleted/revoked).
      await user.reload().timeout(const Duration(seconds: 3));
      sessionVerifiedOnline = true;
      return currentUser ?? user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        sessionVerifiedOnline = false;
        return user;
      }
      if (e.code == 'user-disabled' ||
          e.code == 'user-not-found' ||
          e.code == 'user-token-expired' ||
          e.code == 'invalid-user-token') {
        await signOut(unbindDevice: false);
        return null;
      }
      sessionVerifiedOnline = false;
      return user;
    } catch (e) {
      debugPrint(
        'restoreSession: user.reload offline or timed out, trusting local session',
      );
      sessionVerifiedOnline = false;
      return user;
    }
  }

  bool sessionVerifiedOnline = true;

  User? get currentUser => FirebaseAuth.instance.currentUser;
}

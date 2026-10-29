import 'package:firebase_auth/firebase_auth.dart';

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
  Future<void> signOut() async {
    await clearSession();
    await _authRds.signOut();
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
    final user = currentUser;
    final saved = await _sessionDs.read();
    _savedSession = saved;

    // Firebase has no user, or Hive metadata is missing/mismatched.
    if (user == null || saved == null || saved.uid != user.uid) {
      if (user != null) await _authRds.signOut();
      await clearSession();
      return null;
    }

    try {
      // Validates and refreshes the backend auth token (fails if disabled/deleted/revoked).
      await user.reload();
      sessionVerifiedOnline = true;
      return currentUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        sessionVerifiedOnline = false;
        return user;
      }
      await signOut();
      return null;
    } catch (_) {
      await signOut();
      return null;
    }
  }

  bool sessionVerifiedOnline = true;

  User? get currentUser => FirebaseAuth.instance.currentUser;
}

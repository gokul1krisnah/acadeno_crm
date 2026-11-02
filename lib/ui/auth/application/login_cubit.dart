import '../../../../core/services/device_security_service.dart';
import 'dart:async';
import '../data/sources/auth_session_local_ds.dart';
import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/login_model.dart';
import '../data/repository/firebase_auth_repo.dart';
import 'login_state.dart';

// ---------------------------------------------------------------------------
// Role configuration: roles considered admin in the application
// ---------------------------------------------------------------------------
const List<String> _kAdminRoles = ['admin', 'super_admin'];

// Optional fallback UID for legacy administrative bootstrap account
const String _kAdminUid = 'aOt6zw43GPTebTKWAP4d0hQHYEz2';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._authRepository) : super(const LoginState.initial());

  final AuthRepository _authRepository;

  /// Cached session metadata from Hive local storage.
  AuthSession? get savedSession => _authRepository.savedSession;

  /// True if the currently signed-in user has admin privileges.
  bool isAdmin = false;

  /// The active role for the signed-in user ('super_admin', 'admin', 'manager', 'executive', etc.)
  String? currentRole;

  Future<void> signIn(LoginRequestModel request) async {
    emit(const LoginState.loading());

    try {
      // Step 1: Authenticate via Firebase Auth (validates email & password against backend)
      final user = await _authRepository.signIn(
        email: request.email,
        password: request.password,
      );

      // Step 2: Role and account status checks from the backend
      final denial = await _authorize(user);
      if (denial != null) {
        emit(LoginState.failure(message: denial));
        return;
      }

      // Step 3: Persist session metadata in Hive only after successful authentication & authorization
      await _authRepository.saveSession(
        user,
        role: currentRole,
        isAdmin: isAdmin,
      );
      emit(const LoginState.success());
    } on FirebaseAuthException catch (error) {
      _resetRole();
      emit(LoginState.failure(message: _errorMessage(error)));
    } catch (_) {
      _resetRole();
      emit(
        const LoginState.failure(
          message: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  /// Restores a previously saved session on app start.
  ///
  /// Returns true when the user is authenticated and authorized; [isAdmin]
  /// then tells which home screen to open. Returns false (and clears any
  /// persisted session) otherwise.
  Future<bool> restoreSession() async {
    try {
      final user = await _authRepository.restoreSession().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {
          final current = _authRepository.currentUser;
          final saved = _authRepository.savedSession;
          if (current != null && saved != null && current.uid == saved.uid) {
            _authRepository.sessionVerifiedOnline = false;
            return current;
          }
          return null;
        },
      );
      if (user == null) {
        _resetRole();
        return false;
      }
      final denial = await _authorize(
        user,
        offline: !_authRepository.sessionVerifiedOnline,
      );
      if (denial != null) {
        return false;
      }
      // Keep persisted session in sync if online; do not block startup
      if (_authRepository.sessionVerifiedOnline) {
        try {
          await _authRepository.saveSession(
            user,
            role: currentRole,
            isAdmin: isAdmin,
          ).timeout(const Duration(milliseconds: 500));
        } catch (_) {}
      }
      return true;
    } catch (_) {
      // Offline safety: do not wipe session on network timeout
      final saved = _authRepository.savedSession;
      final current = _authRepository.currentUser;
      if (saved != null && current != null && saved.uid == current.uid) {
        final isOfflineAdmin = (saved.isAdmin) ||
            current.uid == _kAdminUid ||
            _kAdminRoles.contains(saved.role?.toLowerCase());
        if (isOfflineAdmin) {
          isAdmin = true;
          isAdminSession = true;
          currentRole = saved.role ?? 'admin';
        } else {
          _resetRole();
          currentRole = saved.role ?? 'executive';
        }
        return true;
      }
      await _authRepository.signOut();
      _resetRole();
      return false;
    }
  }

  void _resetRole() {
    isAdmin = false;
    isAdminSession = false;
    currentRole = null;
  }

  /// Applies role-based access rules to an authenticated [user] and sets
  /// [isAdmin]. Returns a failure message if access is denied (the user is
  /// signed out and the persisted session cleared), or null if allowed.
  Future<String?> _authorize(User user, {bool offline = false}) async {
    // 1. If offline was detected, immediately trust cached Hive session without waiting
    if (offline) {
      final saved = _authRepository.savedSession;
      if (saved != null && saved.uid == user.uid) {
        final isOfflineAdmin = saved.isAdmin ||
            user.uid == _kAdminUid ||
            _kAdminRoles.contains(saved.role?.toLowerCase());
        if (isOfflineAdmin) {
          isAdmin = true;
          isAdminSession = true;
          currentRole = saved.role ?? 'admin';
        } else {
          _resetRole();
          currentRole = saved.role ?? 'executive';
        }
        return null;
      }
    }

    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(milliseconds: 1200));
    } catch (e) {
      // Backend unreachable or timed out: trust cached session from Hive
      final saved = _authRepository.savedSession;
      if (saved != null && saved.uid == user.uid) {
        final isOfflineAdmin = saved.isAdmin ||
            user.uid == _kAdminUid ||
            _kAdminRoles.contains(saved.role?.toLowerCase());
        if (isOfflineAdmin) {
          isAdmin = true;
          isAdminSession = true;
          currentRole = saved.role ?? 'admin';
        } else {
          _resetRole();
          currentRole = saved.role ?? 'executive';
        }
        return null;
      }
      if (user.uid == _kAdminUid) {
        isAdmin = true;
        isAdminSession = true;
        currentRole = 'admin';
        return null;
      }
      return 'Offline: unable to verify session';
    }

    if (!doc.exists) {
      // Fallback bootstrap check for admin UID if user doc has not been initialized
      if (user.uid == _kAdminUid) {
        isAdmin = true;
        isAdminSession = true;
        currentRole = 'admin';
        return null;
      }
      await _authRepository.signOut();
      _resetRole();
      return 'Your account is not authorized. Contact your administrator.';
    }

    final data = doc.data() ?? {};
    final isActive = data['isActive'] as bool? ?? true;
    if (!isActive) {
      await _authRepository.signOut();
      _resetRole();
      return 'Your account has been deactivated. Contact your admin.';
    }

    final role = (data['role'] as String?)?.toLowerCase() ?? 'hr';
    currentRole = role;

    final isUserAdmin = user.uid == _kAdminUid || _kAdminRoles.contains(role);
    if (isUserAdmin) {
      isAdmin = true;
      isAdminSession = true;
    } else {
      _resetRole();
      currentRole = role;

      // PR-5.1 & PR-5.4: Enforce single-phone hardware binding and integrity for Sales Executives
      if (!offline) {
        final deviceCheckResult = await DeviceSecurityService.verifyDeviceBinding(
          user: user,
          userData: data,
        );
        if (deviceCheckResult != null) {
          await _authRepository.signOut();
          _resetRole();
          return deviceCheckResult;
        }
      }
    }

    // Record session start for PR-5.3 remote deactivation listener
    SessionSecurityService.instance.recordLoginSession(
      loginTime: DateTime.now(),
      initialLogoutToken: data['forceLogoutToken'] as String?,
    );

    return null;
  }

  Future<void> register(LoginRequestModel request) async {
    emit(const LoginState.loading());

    try {
      // Step 1: Create Firebase Auth user
      final user = await _authRepository.register(
        email: request.email,
        password: request.password,
      );

      // Step 2: Auto-create Firestore users/{uid} document
      // This allows the user to login immediately without manual Firestore setup
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email ?? request.email,
        'name': user.displayName ?? '', // empty until profile is updated
        'role': 'hr', // default role
        'isActive': true, // active by default
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Newly registered users have default hr role
      _resetRole();
      currentRole = 'hr';
      await _authRepository.saveSession(
        user,
        role: 'hr',
        isAdmin: false,
      );
      emit(const LoginState.success());
    } on FirebaseAuthException catch (error) {
      emit(LoginState.failure(message: _errorMessage(error)));
    } catch (_) {
      emit(
        const LoginState.failure(
          message: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  String _errorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must contain at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }
}

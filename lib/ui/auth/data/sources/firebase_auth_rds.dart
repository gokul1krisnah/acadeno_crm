import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/app_notification_service.dart';

class FirebaseAuthRds {
  FirebaseAuthRds(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user != null) {
      unawaited(AppNotificationService.instance.syncUserFcmToken(user.uid));
    }
    return cred;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _firebaseAuth.signOut();
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/app_notification_service.dart';
import '../../../../core/services/firestore_stream_cache.dart';
import '../../../../core/services/offline_queue_service.dart';
import 'auth_session_local_ds.dart';

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

  Future<void> signOut() async {
    await OfflineQueueService.instance.clearAll();
    await AuthSessionLocalDs().clear();
    FirestoreStreamCache.instance.clearAll();
    await _firebaseAuth.signOut();
  }
}

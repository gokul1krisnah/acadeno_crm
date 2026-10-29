import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Remote data source for the signed-in user's profile.
class HomeRds {
  HomeRds({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  User? get currentUser => _firebaseAuth.currentUser;

  /// Live `users/{uid}` document of the signed-in user (null if signed out).
  Stream<DocumentSnapshot<Map<String, dynamic>>>? watchCurrentUserDoc() {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).snapshots();
  }
}


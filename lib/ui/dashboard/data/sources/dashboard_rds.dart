import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class DashboardRds {
  DashboardRds({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _firestore.collection('audit_log');

  CollectionReference<Map<String, dynamic>> get _leads =>
      _firestore.collection('leads');

  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  User? get currentUser => _firebaseAuth.currentUser;

  String get currentActorLabel =>
      _firebaseAuth.currentUser?.email ??
      _firebaseAuth.currentUser?.displayName ??
      'Super Admin';

  Stream<DocumentSnapshot<Map<String, dynamic>>>? watchCurrentUserDoc() {
    final uid = currentUserId;
    if (uid == null) return null;
    return _users.doc(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllUsers() {
    return _users.snapshots().handleError((err) {
      // Catch and log any stream-level Firestore exceptions to prevent unhandled errors
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllLeads() {
    return _leads.snapshots().handleError((err) {
      // Catch and log any stream-level Firestore exceptions to prevent unhandled errors
    });
  }

  /// A secondary Firebase app ensures creating a user does NOT sign the admin out.
  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app('userCreator');
    } on FirebaseException {
      return Firebase.initializeApp(
        name: 'userCreator',
        options: Firebase.app().options,
      );
    }
  }

  /// Appends an immutable entry to `audit_log` (best-effort if rules restrict).
  Future<void> appendAuditLog({
    required String action,
    required String target,
    required String category,
  }) async {
    try {
      await _auditLogs.add({
        'actorUid': currentUserId,
        'actor': currentActorLabel,
        'action': action,
        'target': target,
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore if audit_log collection rules are not yet deployed
    }
  }

  /// Creates the user in Firebase Authentication, then creates `users/{uid}` in Firestore.
  Future<void> createAuthUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String phone = '',
  }) async {
    final auth = FirebaseAuth.instanceFor(app: await _secondaryApp());
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(name.trim());
      await saveUserDoc(
        uid: uid,
        name: name,
        email: email,
        role: role,
        phone: phone,
      );
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'email-already-in-use' =>
          'This email already exists in Authentication. Use "Add by UID" instead.',
        'weak-password' => 'Password must be at least 6 characters.',
        'invalid-email' => 'Invalid email address.',
        'operation-not-allowed' =>
          'Enable Email/Password sign-in in Firebase Console → Authentication.',
        _ => e.message ?? e.code,
      };
    } finally {
      await auth.signOut();
    }
  }

  /// Creates or updates `users/{uid}` for an existing Auth user.
  Future<void> saveUserDoc({
    required String uid,
    required String name,
    required String email,
    required String role,
    String phone = '',
  }) async {
    try {
      await _users.doc(uid.trim()).set({
        'uid': uid.trim(),
        'name': name.trim(),
        'email': email.trim(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        'role': role,
        'isActive': true,
        'deviceBound': true,
        'deviceName': 'Android · Registered',
        'joinedOn': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserId,
      }, SetOptions(merge: true));
      await appendAuditLog(
        action: 'Created user account ($role)',
        target: '${name.trim()} (${email.trim()})',
        category: 'user_create',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw 'Permission denied. Your users/{yourUid} doc must have role "admin" or '
            '"super_admin", and the Firestore rules must be published.';
      }
      rethrow;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _users.doc(uid).update(data);
  }

  Future<void> resetUserDevice(String uid, String userName) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch.toString();
    await _users.doc(uid).update({
      'deviceBound': false,
      'deviceId': null,
      'registeredDeviceId': null,
      'deviceName': 'Pending new phone binding',
      'deviceResetAt': FieldValue.serverTimestamp(),
      'forceLogoutAt': FieldValue.serverTimestamp(),
      'forceLogoutToken': nowMs,
    });
    await appendAuditLog(
      action: 'Approved new phone binding & signed out old device',
      target: userName,
      category: 'device_reset',
    );
  }

  Future<void> forceSignOutUser(String uid, String userName) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch.toString();
    await _users.doc(uid).update({
      'forceLogoutAt': FieldValue.serverTimestamp(),
      'forceLogoutToken': nowMs,
      'lastForceLogoutBy': userName,
    });
    await appendAuditLog(
      action: 'Remotely signed out active sessions',
      target: userName,
      category: 'remote_signout',
    );
  }

  Future<({bool success, String? link, String? error})> sendPasswordReset(
    String email, {
    String? uid,
    String? newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Try serverless backend API on Vercel / Cloud
    try {
      final response = await http
          .post(
            Uri.parse('/api/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': cleanEmail,
              if (uid != null && uid.isNotEmpty) 'uid': uid,
              if (newPassword != null && newPassword.isNotEmpty)
                'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          final link = data['link']?.toString();
          return (success: true, link: link, error: null);
        }
      } else if (response.statusCode == 404 || response.statusCode == 400) {
        final data = jsonDecode(response.body);
        final err = data is Map ? data['error']?.toString() : null;
        if (err != null && err.isNotEmpty) {
          return (success: false, link: null, error: err);
        }
      }
    } catch (_) {
      // Backend endpoint unavailable (e.g. running offline or local dev without server)
    }

    // 2. Client-side Firebase Auth fallback
    if (newPassword != null && newPassword.isNotEmpty) {
      return (
        success: false,
        link: null,
        error:
            'Direct password change requires the backend admin service. Use Send Reset Email instead.',
      );
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: cleanEmail);
      return (success: true, link: null, error: null);
    } on FirebaseAuthException catch (e) {
      return (
        success: false,
        link: null,
        error: e.message ?? 'Firebase Auth failed to dispatch reset email.',
      );
    } catch (e) {
      return (success: false, link: null, error: e.toString());
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final res = await sendPasswordReset(email);
    if (!res.success && res.error != null) {
      throw Exception(res.error);
    }
  }

  Future<void> deleteUser(String uid) {
    return _users.doc(uid).delete();
  }
}

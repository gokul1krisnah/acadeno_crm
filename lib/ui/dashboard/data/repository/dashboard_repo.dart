import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../auth/data/repository/firebase_auth_repo.dart';
import '../../../auth/data/sources/firebase_auth_rds.dart';
import '../model/dashboard_user_model.dart';
import '../sources/dashboard_rds.dart';

class DashboardRepository {
  DashboardRepository(this._rds, [AuthRepository? authRepository])
    : _authRepository =
          authRepository ??
          AuthRepository(FirebaseAuthRds(FirebaseAuth.instance));

  final DashboardRds _rds;
  final AuthRepository _authRepository;

  String? get currentUserId => _rds.currentUserId;

  User? get currentUser => _rds.currentUser;

  String get currentActorLabel => _rds.currentActorLabel;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? watchCurrentUserDoc() {
    return _rds.watchCurrentUserDoc();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllUsers() {
    return _rds.watchAllUsers();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllLeads() {
    return _rds.watchAllLeads();
  }

  List<DashboardUserModel> mapAndSortUsers(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    final docs = [...?snapshot?.docs]
      ..sort((a, b) {
        final ta = a.data()['createdAt'], tb = b.data()['createdAt'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        return 0;
      });
    return docs.map(DashboardUserModel.fromFirestore).toList();
  }

  Future<void> createUser(CreateUserRequestModel request) async {
    if (request.byUid) {
      await _rds.saveUserDoc(
        uid: request.uid,
        name: request.name,
        email: request.email,
        role: request.role,
        phone: request.phone,
      );
    } else {
      await _rds.createAuthUser(
        name: request.name,
        email: request.email,
        password: request.password,
        role: request.role,
        phone: request.phone,
      );
    }
  }

  Future<void> updateUserRole(
    String uid,
    String role, {
    String userName = '',
  }) async {
    await _rds.updateUser(uid, {
      'role': role,
      'roleUpdatedAt': FieldValue.serverTimestamp(),
    });
    await _rds.appendAuditLog(
      action: 'Changed role to $role',
      target: userName.isEmpty ? uid : userName,
      category: 'role_change',
    );
  }

  Future<void> updateUserActive(
    String uid,
    bool isActive, {
    String userName = '',
    String? reassignToExecutive,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch.toString();
    await _rds.updateUser(uid, {
      'isActive': isActive,
      'status': isActive ? 'active' : 'inactive',
      if (!isActive) 'forceLogoutAt': FieldValue.serverTimestamp(),
      if (!isActive) 'forceLogoutToken': nowMs,
      if (!isActive && reassignToExecutive != null)
        'openWorkReassignedTo': reassignToExecutive,
    });
    await _rds.appendAuditLog(
      action: isActive
          ? 'Reactivated user account'
          : 'Deactivated user & revoked sessions'
                '${reassignToExecutive != null ? " (reassigned open work to $reassignToExecutive)" : ""}',
      target: userName.isEmpty ? uid : userName,
      category: 'status_change',
    );
  }

  Future<void> resetUserDevice(String uid, String userName) {
    return _rds.resetUserDevice(uid, userName);
  }

  Future<void> forceSignOutUser(String uid, String userName) {
    return _rds.forceSignOutUser(uid, userName);
  }

  Future<void> appendAuditLog({
    required String action,
    required String target,
    required String category,
  }) {
    return _rds.appendAuditLog(
      action: action,
      target: target,
      category: category,
    );
  }

  Future<void> deleteUser(String uid, {String userName = ''}) async {
    await _rds.deleteUser(uid);
    await _rds.appendAuditLog(
      action: 'Removed user record',
      target: userName.isEmpty ? uid : userName,
      category: 'user_delete',
    );
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }
}

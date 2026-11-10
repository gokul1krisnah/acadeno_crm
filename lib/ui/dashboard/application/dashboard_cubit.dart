import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/dashboard_user_model.dart';
import '../data/repository/dashboard_repo.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repository) : super(const DashboardInitial());

  final DashboardRepository _repository;

  final List<AuditLogEntry> auditEntries = [];

  String? get currentUserId => _repository.currentUserId;

  User? get currentUser => _repository.currentUser;

  String get currentActorLabel => _repository.currentActorLabel;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? watchCurrentUserDoc() {
    return _repository.watchCurrentUserDoc();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllUsers() {
    return _repository.watchAllUsers();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllLeads() {
    return _repository.watchAllLeads();
  }

  List<DashboardUserModel> mapAndSortUsers(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    return _repository.mapAndSortUsers(snapshot);
  }

  void selectNav(int index) {
    emit(DashboardInitial(selectedNavIndex: index));
  }

  void recordAudit({
    required String action,
    required String target,
    required String category,
    String? toastMessage,
  }) {
    auditEntries.insert(
      0,
      AuditLogEntry(
        actor: currentActorLabel,
        action: action,
        target: target,
        timestamp: 'Just now · IST',
        category: category,
      ),
    );
    _repository.appendAuditLog(
      action: action,
      target: target,
      category: category,
    );
    if (toastMessage != null) {
      emit(
        DashboardActionSuccess(
          message: toastMessage,
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    } else {
      emit(DashboardInitial(selectedNavIndex: state.selectedNavIndex));
    }
  }

  Future<bool> createUser(CreateUserRequestModel request) async {
    emit(DashboardLoading(selectedNavIndex: state.selectedNavIndex));
    try {
      await _repository.createUser(request);
      auditEntries.insert(
        0,
        AuditLogEntry(
          actor: currentActorLabel,
          action: 'Created user (${request.role.replaceAll('_', ' ')})',
          target: '${request.name} · ${request.email}',
          timestamp: 'Just now · IST',
          category: 'user_create',
        ),
      );
      emit(
        DashboardActionSuccess(
          message: request.byUid
              ? 'User saved to database'
              : 'User created in Authentication and database',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
      return true;
    } catch (e) {
      emit(
        DashboardActionFailure(
          message: e.toString(),
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
      return false;
    }
  }

  Future<void> updateUserRole(
    String uid,
    String role, {
    String userName = '',
  }) async {
    try {
      await _repository.updateUserRole(uid, role, userName: userName);
      auditEntries.insert(
        0,
        AuditLogEntry(
          actor: currentActorLabel,
          action: 'Changed role to ${role.replaceAll('_', ' ')}',
          target: userName.isEmpty ? uid : userName,
          timestamp: 'Just now · IST',
          category: 'role_change',
        ),
      );
      emit(
        DashboardActionSuccess(
          message:
              'Updated ${userName.isEmpty ? "user" : userName} role to ${role.replaceAll('_', ' ')}',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    } catch (e) {
      emit(
        DashboardActionFailure(
          message: 'Update failed: $e',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    }
  }

  Future<void> updateUserActive(
    String uid,
    bool isActive, {
    String userName = '',
    String? reassignToExecutive,
  }) async {
    try {
      await _repository.updateUserActive(
        uid,
        isActive,
        userName: userName,
        reassignToExecutive: reassignToExecutive,
      );
      auditEntries.insert(
        0,
        AuditLogEntry(
          actor: currentActorLabel,
          action: isActive
              ? 'Reactivated user account'
              : 'Deactivated account & revoked active sessions'
                    '${reassignToExecutive != null ? " · Reassigned work to $reassignToExecutive" : ""}',
          target: userName.isEmpty ? uid : userName,
          timestamp: 'Just now · IST',
          category: 'status_change',
        ),
      );
      emit(
        DashboardActionSuccess(
          message: isActive
              ? '${userName.isEmpty ? "User" : userName} reactivated'
              : '${userName.isEmpty ? "User" : userName} deactivated (sessions ends within 60s)'
                    '${reassignToExecutive != null ? " & work moved to $reassignToExecutive" : ""}',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    } catch (e) {
      emit(
        DashboardActionFailure(
          message: 'Update failed: $e',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    }
  }

  Future<void> resetUserDevice(String uid, String userName) async {
    try {
      await _repository.resetUserDevice(uid, userName);
      auditEntries.insert(
        0,
        AuditLogEntry(
          actor: currentActorLabel,
          action: 'Reset registered phone & approved new device binding',
          target: userName,
          timestamp: 'Just now · IST',
          category: 'device_reset',
        ),
      );
      emit(
        DashboardActionSuccess(
          message: 'New phone approved for $userName. Old device signed out.',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    } catch (e) {
      emit(
        DashboardActionFailure(
          message: 'Device reset failed: $e',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    }
  }

  Future<void> forceSignOutUser(String uid, String userName) async {
    try {
      await _repository.forceSignOutUser(uid, userName);
      auditEntries.insert(
        0,
        AuditLogEntry(
          actor: currentActorLabel,
          action: 'Triggered remote sign-out across all devices',
          target: userName,
          timestamp: 'Just now · IST',
          category: 'remote_signout',
        ),
      );
      emit(
        DashboardActionSuccess(
          message: 'Remote sign-out sent to $userName.',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    } catch (e) {
      emit(
        DashboardActionFailure(
          message: 'Remote sign-out failed: $e',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    }
  }

  Future<void> deleteUser(String uid, String name) async {
    try {
      await _repository.deleteUser(uid, userName: name);
      auditEntries.insert(
        0,
        AuditLogEntry(
          actor: currentActorLabel,
          action: 'Removed user from database',
          target: name,
          timestamp: 'Just now · IST',
          category: 'user_delete',
        ),
      );
      emit(
        DashboardActionSuccess(
          message: '$name removed',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    } catch (e) {
      emit(
        DashboardActionFailure(
          message: 'Delete failed: $e',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    }
  }

  Future<void> sendPasswordResetEmail(
    String email, {
    String userName = '',
  }) async {
    try {
      await _repository.sendPasswordResetEmail(email, userName: userName);
      auditEntries.insert(
        0,
        AuditLogEntry(
          actor: currentActorLabel,
          action: 'Sent password reset email',
          target: userName.isEmpty ? email : userName,
          timestamp: 'Just now · IST',
          category: 'password_reset',
        ),
      );
      emit(
        DashboardActionSuccess(
          message: 'Password reset link sent to $email',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    } catch (e) {
      emit(
        DashboardActionFailure(
          message: 'Password reset failed: $e',
          selectedNavIndex: state.selectedNavIndex,
        ),
      );
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    isAdminSession = false;
    emit(DashboardSignedOut(selectedNavIndex: state.selectedNavIndex));
  }
}

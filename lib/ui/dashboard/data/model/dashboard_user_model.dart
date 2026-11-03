import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardUserModel {
  const DashboardUserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone = '',
    this.deviceName = 'Registered Android',
    this.deviceBound = true,
    this.callsToday = 0,
    this.assignedToday = 30,
    this.conversionsMonth = 0,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final String phone;
  final String deviceName;
  final bool deviceBound;
  final int callsToday;
  final int assignedToday;
  final int conversionsMonth;
  final DateTime? createdAt;

  static const List<String> allowedRoles = ['admin', 'hr'];
  static const List<String> adminRoles = ['admin', 'super_admin'];
  static const List<String> superAdminRoles = ['admin', 'super_admin'];

  bool get isAdminRole => adminRoles.contains(role);
  bool get isSuperAdmin => superAdminRoles.contains(role);

  static String normalizeRole(String? raw) {
    final lower = (raw ?? '').trim().toLowerCase();
    switch (lower) {
      case 'admin':
      case 'super_admin':
        return 'admin';
      case 'hr':
      default:
        return 'hr';
    }
  }

  String get roleLabel => switch (role) {
    'admin' || 'super_admin' => 'Admin',
    _ => 'HR & Operation Manager',
  };

  factory DashboardUserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      final data = doc.data() ?? {};
      final rawRole = data['role']?.toString();
      final createdAtField = data['createdAt'];

      // Extract original email from all possible Firestore document fields
      String email = (data['email'] ??
              data['userEmail'] ??
              data['gmail'] ??
              data['mail'] ??
              data['emailAddress'] ??
              data['emailId'] ??
              data['user_email'] ??
              data['user_mail'] ??
              '')
          .toString()
          .trim();

      if (email.isEmpty && doc.id.contains('@')) {
        email = doc.id.trim();
      }

      final currentAuthUser = FirebaseAuth.instance.currentUser;
      if (email.isEmpty && currentAuthUser != null && currentAuthUser.uid == doc.id) {
        if (currentAuthUser.email != null && currentAuthUser.email!.trim().isNotEmpty) {
          email = currentAuthUser.email!.trim();
        }
      }

      // Extract original name as actually saved in Firestore
      String name = (data['name'] ??
              data['displayName'] ??
              data['fullName'] ??
              data['userName'] ??
              data['username'] ??
              data['name_display'] ??
              '')
          .toString()
          .trim();

      if (name.isEmpty && currentAuthUser != null && currentAuthUser.uid == doc.id) {
        if (currentAuthUser.displayName != null && currentAuthUser.displayName!.trim().isNotEmpty) {
          name = currentAuthUser.displayName!.trim();
        }
      }

      // If email was empty but name contains @, name is likely the email
      if (email.isEmpty && name.contains('@')) {
        email = name;
      }

      // If name is still empty, derive fallback without synthetic fake strings
      if (name.isEmpty) {
        if (email.isNotEmpty && email != '—' && email.contains('@')) {
          name = email.split('@').first;
        } else if (doc.id.contains('@')) {
          name = doc.id.split('@').first;
        } else {
          name = doc.id.length > 5
              ? 'User (${doc.id.substring(0, 5)})'
              : 'User (${doc.id})';
        }
      }

      if (email.isEmpty) {
        email = '—';
      }

      // Device info
      final deviceName = (data['deviceName'] ??
              data['boundDeviceModel'] ??
              data['deviceModel'] ??
              data['device'] ??
              (data['deviceBound'] == false
                  ? 'Pending new phone...'
                  : 'Registered Android'))
          .toString();

      final deviceBound = data['deviceBound'] != false &&
          !deviceName.toLowerCase().contains('pending');

      return DashboardUserModel(
        uid: doc.id,
        name: name,
        email: email,
        role: normalizeRole(rawRole),
        isActive: data['isActive'] != false,
        phone: (data['phone'] ?? '').toString(),
        deviceName: deviceName,
        deviceBound: deviceBound,
        callsToday: (data['callsToday'] as num?)?.toInt() ?? 0,
        assignedToday: (data['assignedToday'] as num?)?.toInt() ?? 0,
        conversionsMonth: (data['conversionsMonth'] as num?)?.toInt() ?? 0,
        createdAt: createdAtField is Timestamp ? createdAtField.toDate() : null,
      );
    } catch (_) {
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      final fallbackEmail = (currentAuthUser != null && currentAuthUser.uid == doc.id && currentAuthUser.email != null)
          ? currentAuthUser.email!
          : (doc.id.contains('@') ? doc.id : '—');
      final fallbackName = doc.id.contains('@')
          ? doc.id.split('@').first
          : (fallbackEmail.contains('@')
              ? fallbackEmail.split('@').first
              : (doc.id.length > 5 ? 'User (${doc.id.substring(0, 5)})' : 'User (${doc.id})'));
      return DashboardUserModel(
        uid: doc.id,
        name: fallbackName,
        email: fallbackEmail,
        role: 'hr',
        isActive: true,
      );
    }
  }
}

class CreateUserRequestModel {
  const CreateUserRequestModel({
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.uid = '',
    this.password = '',
    this.byUid = false,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;
  final bool byUid;
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.actor,
    required this.action,
    required this.target,
    required this.timestamp,
    required this.category,
  });

  final String actor;
  final String action;
  final String target;
  final String timestamp;
  final String category;
}

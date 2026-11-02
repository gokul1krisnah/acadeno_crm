import 'package:cloud_firestore/cloud_firestore.dart';

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
      return DashboardUserModel(
        uid: doc.id,
        name: (data['name'] ?? '—').toString(),
        email: (data['email'] ?? '—').toString(),
        role: normalizeRole(rawRole),
        isActive: data['isActive'] != false,
        phone: (data['phone'] ?? '').toString(),
        deviceName: (data['deviceName'] ?? (data['boundDeviceModel'] ?? 'Registered Android')).toString(),
        deviceBound: data['deviceBound'] != false,
        callsToday: (data['callsToday'] as num?)?.toInt() ?? 0,
        assignedToday: (data['assignedToday'] as num?)?.toInt() ?? 0,
        conversionsMonth: (data['conversionsMonth'] as num?)?.toInt() ?? 0,
        createdAt: createdAtField is Timestamp ? createdAtField.toDate() : null,
      );
    } catch (_) {
      return DashboardUserModel(
        uid: doc.id,
        name: doc.id.length > 5 ? 'User (' + doc.id.substring(0, 5) + ')' : 'User (' + doc.id + ')',
        email: '—',
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

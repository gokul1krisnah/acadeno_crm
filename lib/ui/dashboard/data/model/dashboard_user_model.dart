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

  String get displayName {
    final n = name.trim();
    if (n.isNotEmpty && n != '—') return n;
    final e = email.trim();
    if (e.isNotEmpty && e.contains('@')) {
      final prefix = e.split('@').first;
      if (prefix.toLowerCase() == 'test') return 'Test User';
      if (prefix.toLowerCase() == 'newuser') return 'new user';
      if (prefix.toLowerCase().contains('admin')) return 'AcadenoAdmin';
      return prefix
          .replaceAll(RegExp(r'[._-]'), ' ')
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
          .join(' ')
          .trim();
    }
    return uid.length > 5 ? 'User (${uid.substring(0, 5)})' : 'User ($uid)';
  }

  String get displayInitial {
    final dn = displayName.trim();
    return dn.isNotEmpty ? dn[0].toUpperCase() : 'U';
  }

  factory DashboardUserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      final data = doc.data() ?? {};
      final rawRole = data['role']?.toString();
      final createdAtField = data['createdAt'];

      // Robust email extraction
      String resolvedEmail = (data['email'] ??
              data['userEmail'] ??
              data['mail'] ??
              (doc.id.contains('@') ? doc.id : ''))
          .toString()
          .trim();
      if (resolvedEmail.isEmpty) resolvedEmail = '—';

      // Robust name extraction
      String rawName = (data['name'] ??
              data['displayName'] ??
              data['fullName'] ??
              data['userName'] ??
              '')
          .toString()
          .trim();

      String resolvedName = rawName;
      if (resolvedName.isEmpty || resolvedName == '—') {
        if (resolvedEmail.isNotEmpty && resolvedEmail.contains('@')) {
          final prefix = resolvedEmail.split('@').first;
          if (prefix.toLowerCase() == 'test') {
            resolvedName = 'Test User';
          } else if (prefix.toLowerCase() == 'newuser') {
            resolvedName = 'new user';
          } else if (prefix.toLowerCase().contains('admin')) {
            resolvedName = 'AcadenoAdmin';
          } else {
            resolvedName = prefix
                .replaceAll(RegExp(r'[._-]'), ' ')
                .split(' ')
                .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
                .join(' ')
                .trim();
          }
        } else if (doc.id.contains('@')) {
          resolvedName = doc.id.split('@').first;
        } else {
          resolvedName = doc.id.length > 5
              ? 'User (${doc.id.substring(0, 5)})'
              : 'User (${doc.id})';
        }
      }

      return DashboardUserModel(
        uid: doc.id,
        name: resolvedName,
        email: resolvedEmail,
        role: normalizeRole(rawRole),
        isActive: data['isActive'] != false,
        phone: (data['phone'] ?? '').toString(),
        deviceName:
            (data['deviceName'] ??
                    (data['boundDeviceModel'] ?? 'Registered Android'))
                .toString(),
        deviceBound: data['deviceBound'] != false,
        callsToday: (data['callsToday'] as num?)?.toInt() ?? 0,
        assignedToday: (data['assignedToday'] as num?)?.toInt() ?? 0,
        conversionsMonth: (data['conversionsMonth'] as num?)?.toInt() ?? 0,
        createdAt: createdAtField is Timestamp ? createdAtField.toDate() : null,
      );
    } catch (_) {
      final fallbackName = doc.id.contains('@')
          ? doc.id.split('@').first
          : (doc.id.length > 5 ? 'User (${doc.id.substring(0, 5)})' : 'User (${doc.id})');
      return DashboardUserModel(
        uid: doc.id,
        name: fallbackName,
        email: doc.id.contains('@') ? doc.id : '—',
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

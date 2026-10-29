import 'package:cloud_firestore/cloud_firestore.dart';

/// Signed-in user's profile, read from Firebase Auth + `users/{uid}` in Firestore.
class HomeUserModel {
  const HomeUserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.joinedOn,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String phone;
  final DateTime? joinedOn;

  static const HomeUserModel empty = HomeUserModel(
    uid: '',
    name: '',
    email: '',
    role: 'hr',
  );

  /// Name to show in the UI. Falls back to the email prefix, then "there".
  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final prefix = email.split('@').first.trim();
    if (prefix.isEmpty) return 'there';
    return prefix[0].toUpperCase() + prefix.substring(1);
  }

  String get firstName => displayName.split(RegExp(r'\s+')).first;

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2);
    final value = parts.map((p) => p[0].toUpperCase()).join();
    return value.isEmpty ? 'U' : value;
  }

  String get roleLabel => switch (role) {
    'admin' || 'super_admin' => 'Admin',
    _ => 'HR & Operation Manager',
  };

  String get joinedLabel {
    final d = joinedOn;
    if (d == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  HomeUserModel copyWith({String? name, String? email}) => HomeUserModel(
    uid: uid,
    name: name ?? this.name,
    email: email ?? this.email,
    role: role,
    phone: phone,
    joinedOn: joinedOn,
  );

  factory HomeUserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final joined = data['joinedOn'] ?? data['createdAt'];
    final rawRole = ((data['role'] as String?) ?? 'hr').toLowerCase();
    final normalizedRole = (rawRole == 'admin' || rawRole == 'super_admin')
        ? 'admin'
        : 'hr';
    return HomeUserModel(
      uid: doc.id,
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      role: normalizedRole,
      phone: (data['phone'] ?? '').toString(),
      joinedOn: joined is Timestamp ? joined.toDate() : null,
    );
  }
}

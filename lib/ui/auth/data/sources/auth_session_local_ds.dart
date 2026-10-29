import 'package:hive_flutter/hive_flutter.dart';

/// Non-sensitive session metadata persisted in Hive.
///
/// No password or token is stored here. The Firebase SDK keeps the actual
/// credentials (refresh token) in its own platform-managed persistence; this
/// record only lets the app know which user last signed in successfully.
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.savedAt,
    this.role,
    this.isAdmin = false,
  });

  final String uid;
  final String email;
  final DateTime savedAt;
  final String? role;
  final bool isAdmin;
}

class AuthSessionLocalDs {
  static const String boxName = 'auth_session';
  static const String _key = 'session';

  /// Initializes Hive and opens the session box. Must be awaited before
  /// `runApp()`. A corrupted box is wiped and recreated.
  static Future<void> init() async {
    await Hive.initFlutter();
    try {
      await Hive.openBox<dynamic>(boxName);
    } catch (_) {
      try {
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.openBox<dynamic>(boxName);
      } catch (_) {
        // Storage unusable: the app still works, sessions just won't persist.
      }
    }
  }

  Box<dynamic>? get _box =>
      Hive.isBoxOpen(boxName) ? Hive.box<dynamic>(boxName) : null;

  Future<void> save({
    required String uid,
    required String email,
    String? role,
    bool isAdmin = false,
  }) async {
    await _box?.put(_key, {
      'uid': uid,
      'email': email,
      'role': role,
      'isAdmin': isAdmin,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Returns the saved session, or null if absent or corrupted.
  Future<AuthSession?> read() async {
    final box = _box;
    if (box == null) return null;
    try {
      final raw = box.get(_key);
      if (raw is! Map) return null;
      final uid = raw['uid'];
      final email = raw['email'];
      final savedAt = DateTime.tryParse('${raw['savedAt']}');
      if (uid is! String ||
          uid.isEmpty ||
          email is! String ||
          savedAt == null) {
        await box.delete(_key);
        return null;
      }
      final role = raw['role'] as String?;
      final isAdmin = (raw['isAdmin'] as bool?) ?? false;
      return AuthSession(
        uid: uid,
        email: email,
        savedAt: savedAt,
        role: role,
        isAdmin: isAdmin,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _box?.delete(_key);
    } catch (_) {}
  }
}

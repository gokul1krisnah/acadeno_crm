import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Device Security, Integrity & Hardware Binding Service.
class DeviceSecurityService {
  static const MethodChannel _securityChannel = MethodChannel(
    'com.acadeno.crm/security',
  );

  /// Fetches unique hardware deviceId and human-readable device model name.
  static Future<({String deviceId, String deviceName})>
  getDeviceIdentifier() async {
    if (kIsWeb) {
      final box = await Hive.openBox('acadeno_device_security');
      var id = box.get('browser_device_id') as String?;
      if (id == null || id.isEmpty) {
        id =
            'web_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 9999}';
        await box.put('browser_device_id', id);
      }
      return (deviceId: id, deviceName: 'Web Browser');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _securityChannel.invokeMapMethod<String, String>(
          'getDeviceInfo',
        );
        if (res != null) {
          final id = res['deviceId'] ?? 'android_unknown';
          final name = res['deviceName'] ?? 'Android Phone';
          return (deviceId: id, deviceName: name);
        }
      } catch (_) {}
    }

    final box = await Hive.openBox('acadeno_device_security');
    var id = box.get('device_id') as String?;
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}';
      await box.put('device_id', id);
    }
    return (deviceId: id, deviceName: 'Registered Device');
  }

  /// Verifies hardware integrity (root, emulator, modified builds).
  static Future<bool> isDeviceCompromised() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _securityChannel.invokeMapMethod<String, bool>(
        'checkDeviceIntegrity',
      );
      if (res != null) {
        final isRooted = res['isRooted'] ?? false;
        return isRooted;
      }
    } catch (_) {}
    return false;
  }

  /// Enforces single-phone binding rule for Sales Executives.
  ///
  /// Returns null if access is authorized, or a failure message if blocked.
  static Future<String?> verifyDeviceBinding({
    required User user,
    required Map<String, dynamic> userData,
    bool alreadyFresh = false,
  }) async {
    // 1. Play Integrity / Root detection check
    if (await isDeviceCompromised()) {
      return 'Security violation: Modified or rooted device detected. Access refused.';
    }

    // 2. Device binding
    final device = await getDeviceIdentifier();
    final currentId = device.deviceId;
    final currentName = device.deviceName;

    // Fetch fresh document from Firestore server only if caller did not already fetch it
    Map<String, dynamic> liveData = userData;
    if (!alreadyFresh) {
      try {
        final docSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));
        if (docSnap.exists && docSnap.data() != null) {
          liveData = docSnap.data()!;
        }
      } catch (_) {
        try {
          final docSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (docSnap.exists && docSnap.data() != null) {
            liveData = docSnap.data()!;
          }
        } catch (_) {}
      }
    }

    final registeredId =
        (liveData['registeredDeviceId'] ?? liveData['deviceId']) as String?;
    final isDeviceBound = (liveData['deviceBound'] as bool?) ?? false;
    final boundDeviceName =
        (liveData['deviceName'] ?? liveData['boundDeviceModel'] ?? '').toString();
    final isPendingBinding = boundDeviceName.toLowerCase().contains('pending');

    final isUnbound = !isDeviceBound ||
        registeredId == null ||
        registeredId.trim().isEmpty ||
        isPendingBinding;

    if (isUnbound) {
      // First login or reset device approval: bind this phone to the executive
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'registeredDeviceId': currentId,
              'deviceId': currentId,
              'deviceName': currentName,
              'deviceBound': true,
              'lastBoundAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (_) {}
      return null;
    }

    if (registeredId == currentId) {
      // Already bound to this physical phone
      return null;
    }

    // Account is actively bound to a different phone
    final boundName =
        boundDeviceName.isNotEmpty ? boundDeviceName : 'another phone';
    return 'Device Binding Violation: Your account is registered to $boundName. Sales executives may only use one registered phone. Contact Super Admin or unbind this account to switch devices.';
  }

  /// Unbinds any registered device for a user in Firestore.
  static Future<void> unbindDevice(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'registeredDeviceId': null,
        'deviceId': null,
        'deviceBound': false,
        'deviceName': 'Pending new phone binding',
        'lastUnboundAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Force-binds current hardware device to the given user account.
  static Future<void> forceBindCurrentDevice(User user) async {
    final device = await getDeviceIdentifier();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'registeredDeviceId': device.deviceId,
      'deviceId': device.deviceId,
      'deviceName': device.deviceName,
      'deviceBound': true,
      'lastBoundAt': FieldValue.serverTimestamp(),
      'forceLogoutToken': null,
      'forceLogoutAt': null,
    }, SetOptions(merge: true));
  }
}

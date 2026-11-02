import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Device Security, Integrity & Hardware Binding Service (PR-5.1 - PR-5.4).
class DeviceSecurityService {
  static const MethodChannel _securityChannel =
      MethodChannel('com.acadeno.crm/security');

  /// Fetches unique hardware deviceId and human-readable device model name.
  static Future<({String deviceId, String deviceName})> getDeviceIdentifier() async {
    if (kIsWeb) {
      final box = await Hive.openBox('acadeno_device_security');
      var id = box.get('browser_device_id') as String?;
      if (id == null || id.isEmpty) {
        id = 'web_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 9999}';
        await box.put('browser_device_id', id);
      }
      return (deviceId: id, deviceName: 'Web Browser');
    }

    if (Platform.isAndroid) {
      try {
        final res = await _securityChannel
            .invokeMapMethod<String, String>('getDeviceInfo');
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
    return (deviceId: id, deviceName: '${Platform.operatingSystem} Device');
  }

  /// Verifies hardware integrity (root, emulator, modified builds - PR-5.4).
  static Future<bool> isDeviceCompromised() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _securityChannel
          .invokeMapMethod<String, bool>('checkDeviceIntegrity');
      if (res != null) {
        final isRooted = res['isRooted'] ?? false;
        return isRooted;
      }
    } catch (_) {}
    return false;
  }

  /// Enforces single-phone binding rule for Sales Executives (PR-5.1).
  ///
  /// Returns null if access is authorized, or a failure message if blocked.
  static Future<String?> verifyDeviceBinding({
    required User user,
    required Map<String, dynamic> userData,
  }) async {
    // 1. Play Integrity / Root detection check (PR-5.4)
    if (await isDeviceCompromised()) {
      return 'Security violation (PR-5.4): Modified or rooted device detected. Access refused.';
    }

    // 2. Device binding (PR-5.1)
    final device = await getDeviceIdentifier();
    final currentId = device.deviceId;
    final currentName = device.deviceName;

    final registeredId = userData['registeredDeviceId'] as String?;
    final isDeviceBound = userData['deviceBound'] as bool? ?? false;

    if (!isDeviceBound || registeredId == null || registeredId.isEmpty) {
      // First login or reset device approval: bind this phone to the executive
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'registeredDeviceId': currentId,
          'deviceName': currentName,
          'deviceBound': true,
          'lastBoundAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
      return null;
    }

    if (registeredId != currentId) {
      // Trying to sign in on a second phone!
      final boundName = (userData['deviceName'] ?? 'another phone').toString();
      return 'Device Binding Violation (PR-5.1): Your account is registered to $boundName. Sales executives may only use one registered phone. Contact Super Admin to approve a device switch.';
    }

    return null;
  }
}

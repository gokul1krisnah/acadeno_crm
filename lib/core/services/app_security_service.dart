import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service responsible for mobile device security controls (PR-2.1/DPDP).
///
/// Prevents:
/// 1. Hardware and software screenshots of student lead phone numbers.
/// 2. Screen recording via native OS or third-party recording apps.
/// 3. OS multitasking app-switcher preview caching (avoids thumbnail leaks).
class AppSecurityService {
  AppSecurityService._();
  static final AppSecurityService instance = AppSecurityService._();

  static const MethodChannel _channel = MethodChannel(
    'com.acadeno.crm/security',
  );

  /// Activates hardware-level FLAG_SECURE window protection.
  Future<bool> enableScreenshotProtection() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final ok = await _channel.invokeMethod<bool>('enableSecure');
        return ok ?? false;
      }
    } on MissingPluginException {
      debugPrint('[AppSecurityService] Native security channel not available.');
    } catch (e) {
      debugPrint(
        '[AppSecurityService] Failed to enable screenshot protection: $e',
      );
    }
    return false;
  }

  /// Disables protection (if ever explicitly permitted by Super Admin).
  Future<bool> disableScreenshotProtection() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final ok = await _channel.invokeMethod<bool>('disableSecure');
        return ok ?? false;
      }
    } on MissingPluginException {
      debugPrint('[AppSecurityService] Native security channel not available.');
    } catch (e) {
      debugPrint(
        '[AppSecurityService] Failed to disable screenshot protection: $e',
      );
    }
    return false;
  }

  /// Verifies whether the secure window flag is currently active.
  Future<bool> isSecureEnabled() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final isSecure = await _channel.invokeMethod<bool>('isSecureEnabled');
        return isSecure ?? false;
      }
    } catch (_) {}
    return false;
  }
}

import 'dart:io';

import '../models/app_info_model.dart';

export '../models/app_info_model.dart';

class AppDetailsService {
  static final AppDetailsService _instance = AppDetailsService._internal();

  factory AppDetailsService() => _instance;

  AppDetailsService._internal();

  String? _cachedDeviceId;

  /// Get full details in JSON format
  Future<Map<String, dynamic>> getAllDetails({Map<String, dynamic>? user}) async {
    final appInfo = await getAppInfo();
    final deviceInfo = await getDeviceInfo();
    final networkInfo = await getNetworkInfo();

    return {
      'app': appInfo.toJson(),
      'device': deviceInfo.toJson(),
      'network': networkInfo.toJson(),
      'user': user ?? {},
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// App Info
  Future<AppInfoModel> getAppInfo() async {
    return const AppInfoModel(
      name: 'Acadeno CRM',
      package: 'com.acadeno.crm',
      version: '1.0.0',
      buildNumber: '1',
    );
  }

  /// Device Info
  Future<DeviceInfoModel> getDeviceInfo() async {
    return DeviceInfoModel(
      platform: Platform.operatingSystem,
      deviceId: await _getDeviceId(),
      model: Platform.operatingSystemVersion,
      osVersion: Platform.version,
    );
  }

  /// Network Info
  Future<NetworkInfoModel> getNetworkInfo() async {
    return const NetworkInfoModel(connectionType: 'connected');
  }

  /// Generate or return cached deviceId
  Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    _cachedDeviceId = '${Platform.operatingSystem}_${Platform.localHostname}';
    return _cachedDeviceId!;
  }
}

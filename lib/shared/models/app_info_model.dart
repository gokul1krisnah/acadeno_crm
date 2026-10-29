class AppInfoModel {
  final String name;
  final String package;
  final String version;
  final String buildNumber;

  const AppInfoModel({
    this.name = 'Acadeno CRM',
    this.package = 'com.acadeno.crm',
    this.version = '1.0.0',
    this.buildNumber = '1',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'package': package,
    'version': version,
    'buildNumber': buildNumber,
  };
}

class DeviceInfoModel {
  final String platform;
  final String deviceId;
  final String? model;
  final String? brand;
  final String? manufacturer;
  final String? osVersion;
  final int? sdkInt;
  final String? systemName;
  final String? systemVersion;
  final String? identifierForVendor;

  const DeviceInfoModel({
    required this.platform,
    required this.deviceId,
    this.model,
    this.brand,
    this.manufacturer,
    this.osVersion,
    this.sdkInt,
    this.systemName,
    this.systemVersion,
    this.identifierForVendor,
  });

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'deviceId': deviceId,
    if (model != null) 'model': model,
    if (brand != null) 'brand': brand,
    if (osVersion != null) 'osVersion': osVersion,
  };
}

class NetworkInfoModel {
  final String connectionType;

  const NetworkInfoModel({required this.connectionType});

  Map<String, dynamic> toJson() => {'connectionType': connectionType};
}

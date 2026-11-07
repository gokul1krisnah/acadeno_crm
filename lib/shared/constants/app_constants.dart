import 'package:flutter/foundation.dart';

abstract class AppConstants {
  static const String defaultFontFamily = 'Poppins';
  static const String defaultAppName = 'Acadeno CRM';
  static const String defaultAndroidIcon = '@drawable/notification';
  static const String defaultNotificationId = 'acadeno_notification';
  static const String defaultNotificationName = 'Acadeno CRM';
  static const String defaultFCMTopicGeneral = kDebugMode
      ? 'acadeno-push-notification-general-test'
      : 'acadeno-push-notification-general';

  static const String englishLocale = 'en';

  static String getFcmTopicKey({
    String? country,
    String? state,
    String? district,
  }) {
    String sanitize(String? value) {
      if (value == null || value.isEmpty) return 'all';
      return value
          .toLowerCase()
          .trim()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    }

    final key =
        'country_${sanitize(country)}_state_${sanitize(state)}_district_${sanitize(district)}';
    return key;
  }
}

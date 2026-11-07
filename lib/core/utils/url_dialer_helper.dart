import 'url_dialer_helper_stub.dart'
    if (dart.library.html) 'url_dialer_helper_web.dart'
    as impl;

/// Cross-platform helper to launch phone dialer pad URLs (`tel:<number>`).
class UrlDialerHelper {
  /// Launches the system phone dialer pad for [phone].
  static Future<bool> openDialer(String phone) => impl.openDialer(phone);
}

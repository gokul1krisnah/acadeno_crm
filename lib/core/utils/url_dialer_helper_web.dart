import 'package:web/web.dart' as web;

/// Web implementation using HTML anchor click or window.location to trigger the tel: dialer protocol.
Future<bool> openDialer(String phone) async {
  try {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final telUri = 'tel:$clean';

    final anchor = web.HTMLAnchorElement()
      ..href = telUri
      ..setAttribute('target', '_self')
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (e) {
    try {
      final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      web.window.location.href = 'tel:$clean';
      return true;
    } catch (_) {
      return false;
    }
  }
}

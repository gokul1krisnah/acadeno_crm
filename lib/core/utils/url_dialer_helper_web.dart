// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation using HTML anchor click or window.location to trigger the tel: dialer protocol.
Future<bool> openDialer(String phone) async {
  try {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final telUri = 'tel:$clean';

    final anchor = html.AnchorElement(href: telUri)
      ..setAttribute('target', '_self')
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    return true;
  } catch (e) {
    try {
      final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      html.window.location.href = 'tel:$clean';
      return true;
    } catch (_) {
      return false;
    }
  }
}


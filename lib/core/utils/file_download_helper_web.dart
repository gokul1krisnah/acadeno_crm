// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> downloadCsv({
  required String fileName,
  required String content,
}) async {
  try {
    // Prepended UTF-8 BOM string (\uFEFF) ensures Excel natively opens the CSV with proper UTF-8 charset
    // and eliminates binary Blob array-coercion issues across browsers.
    final bomContent = '\uFEFF$content';
    final blob = html.Blob([bomContent], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (e) {
    return false;
  }
}

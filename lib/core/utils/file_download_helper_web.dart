// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

Future<bool> downloadCsv({
  required String fileName,
  required String content,
}) async {
  try {
    // UTF-8 BOM so Excel on Windows properly displays unicode text without garbled characters
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
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


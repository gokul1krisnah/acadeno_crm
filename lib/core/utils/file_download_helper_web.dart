import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> downloadCsv({
  required String fileName,
  required String content,
}) async {
  try {
    // Prepended UTF-8 BOM string (\uFEFF) ensures Excel natively opens the CSV with proper UTF-8 charset
    // and eliminates binary Blob array-coercion issues across browsers.
    final bomContent = '\uFEFF$content';
    final blob = web.Blob(
      [bomContent.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    web.document.body?.removeChild(anchor);
    web.URL.revokeObjectURL(url);
    return true;
  } catch (e) {
    return false;
  }
}

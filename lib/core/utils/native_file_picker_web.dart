// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<({Uint8List bytes, String name})?> pickFileImpl() async {
  final completer = Completer<({Uint8List bytes, String name})?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept =
      '.csv, .xlsx, .xls, .txt, text/csv, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  uploadInput.style.display = 'none';

  html.document.body?.children.add(uploadInput);

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      uploadInput.remove();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files[0];
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      uploadInput.remove();
      final res = reader.result;
      if (res is Uint8List) {
        if (!completer.isCompleted) {
          completer.complete((bytes: res, name: file.name));
        }
      } else if (res is List<int>) {
        if (!completer.isCompleted) {
          completer.complete((bytes: Uint8List.fromList(res), name: file.name));
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    reader.onError.listen((_) {
      uploadInput.remove();
      if (!completer.isCompleted) completer.complete(null);
    });

    reader.readAsArrayBuffer(file);
  });

  // Trigger system file selection dialog
  uploadInput.click();
  return completer.future;
}

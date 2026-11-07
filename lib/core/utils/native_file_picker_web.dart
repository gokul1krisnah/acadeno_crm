import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<({Uint8List bytes, String name})?> pickFileImpl() async {
  final completer = Completer<({Uint8List bytes, String name})?>();
  final uploadInput = web.HTMLInputElement()
    ..type = 'file'
    ..accept =
        '.csv, .xlsx, .xls, .txt, text/csv, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ..style.display = 'none';

  web.document.body?.appendChild(uploadInput);

  web.EventListener? focusListener;

  void cleanup() {
    uploadInput.remove();
    if (focusListener != null) {
      web.window.removeEventListener('focus', focusListener);
    }
  }

  uploadInput.onchange = ((web.Event e) {
    final files = uploadInput.files;
    if (files == null || files.length == 0) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.item(0);
    if (file == null) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = web.FileReader();
    reader.onloadend = ((web.ProgressEvent _) {
      cleanup();
      final res = reader.result;
      if (res != null && res.isA<JSArrayBuffer>()) {
        final buffer = (res as JSArrayBuffer).toDart;
        if (!completer.isCompleted) {
          completer.complete((bytes: buffer.asUint8List(), name: file.name));
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    }).toJS;

    reader.onerror = ((web.ProgressEvent _) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    }).toJS;

    reader.readAsArrayBuffer(file);
  }).toJS;

  // Handle dialog cancel when focus returns to the window
  focusListener = ((web.Event _) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!completer.isCompleted &&
          (uploadInput.files == null || uploadInput.files!.length == 0)) {
        cleanup();
        completer.complete(null);
      }
    });
  }).toJS;

  web.window.addEventListener('focus', focusListener);

  uploadInput.click();
  return completer.future;
}

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

Future<bool> downloadCsv({
  required String fileName,
  required String content,
}) async {
  try {
    final rawBytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(content),
    ]);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save CSV Export',
        fileName: fileName,
        bytes: rawBytes,
      );
      if (saved != null) {
        return true;
      }
    } else if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(rawBytes);
        return true;
      }
    }
  } catch (_) {}

  try {
    await Clipboard.setData(ClipboardData(text: content));
    return true;
  } catch (_) {
    return false;
  }
}

import 'package:flutter/services.dart';

Future<bool> downloadCsv({
  required String fileName,
  required String content,
}) async {
  try {
    await Clipboard.setData(ClipboardData(text: content));
    return true;
  } catch (e) {
    return false;
  }
}


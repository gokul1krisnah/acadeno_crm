import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<({Uint8List bytes, String name})?> pickFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'xlsx', 'xls', 'txt'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  if (file.bytes != null) {
    return (bytes: file.bytes!, name: file.name);
  }
  return null;
}


import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<({Uint8List bytes, String name})?> pickFileImpl() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['csv', 'xlsx', 'xls', 'txt'],
  );

  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return (bytes: bytes, name: file.name);
}

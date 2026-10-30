import 'dart:typed_data';
import 'native_file_picker_io.dart'
    if (dart.library.html) 'native_file_picker_web.dart' as impl;

/// Universal native file picker for picking CSV & Excel files across Web, Android, iOS, and Desktop.
class NativeFilePicker {
  static Future<({Uint8List bytes, String name})?> pickFile() =>
      impl.pickFileImpl();
}

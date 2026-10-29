import 'dart:io';

import 'package:flutter/foundation.dart';

abstract class PickImage {
  static Future<void> pickImage({
    required ValueSetter<File> onImagePicked,
    bool shouldCrop = false,
  }) async {
    // Image picking helper for Acadeno CRM
  }
}

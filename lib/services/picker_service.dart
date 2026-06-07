import 'dart:async';
import 'package:flutter/foundation.dart';
import 'picker/picker_stub.dart'
    if (dart.library.js_interop) 'picker/picker_web.dart'
    if (dart.library.io) 'picker/picker_native.dart';

class PickerService {
  static Future<String?> pickDirectory() async {
    try {
      return await pickDirectoryPlatform();
    } catch (e) {
      debugPrint('Directory picking failed: $e');
      return null;
    }
  }
}

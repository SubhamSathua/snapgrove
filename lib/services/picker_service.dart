import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

class PickerService {
  static Future<String?> pickDirectory() async {
    try {
      if (kIsWeb) {
        return await _pickDirectoryWeb();
      } else {
        // Use dynamic to bypass CFE 'Member not found: platform' bug on some environments
        return await (FilePicker as dynamic).platform.getDirectoryPath(
          dialogTitle: 'Select Screenshot Folder',
        );
      }
    } catch (e) {
      debugPrint('Directory picking failed: $e');
      return null;
    }
  }

  static Future<String?> _pickDirectoryWeb() async {
    try {
      // In web, some versions might expose this differently or requires different handling
      return await (FilePicker as dynamic).platform.getDirectoryPath();
    } catch (e) {
      debugPrint('Web directory picking failed: $e');
      return null;
    }
  }
}

import 'dart:async';
import 'package:file_picker/file_picker.dart';

Future<String?> pickDirectoryPlatform() async {
  try {
    // Using dynamic bypass for FilePicker v8.0.0+ on Windows/Native
    // to ensure compilation stability across environments.
    final dynamic pk = FilePicker;
    return await pk.platform.getDirectoryPath(
      dialogTitle: 'Select Screenshot Folder',
    );
  } catch (e) {
    return null;
  }
}

import 'dart:async';
import 'package:file_picker/file_picker.dart';

Future<String?> pickDirectoryPlatform() async {
  // Clean, standard API for native platforms.
  // v6.1.1 uses FilePicker.platform.getDirectoryPath()
  return await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Select Screenshot Folder',
  );
}

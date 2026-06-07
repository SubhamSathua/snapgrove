import 'dart:async';
import 'package:file_picker/file_picker.dart';

Future<String?> pickDirectoryPlatform() async {
  // Use dynamic to bypass CFE 'Member not found: platform' bug on some environments
  return await (FilePicker as dynamic).platform.getDirectoryPath(
    dialogTitle: 'Select Screenshot Folder',
  );
}

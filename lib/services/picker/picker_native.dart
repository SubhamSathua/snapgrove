import 'dart:async';
import 'package:file_picker/file_picker.dart';

Future<String?> pickDirectoryPlatform() async {
  // Use dynamic to bypass 'Member not found: platform' bug on some environments/versions.
  // This is a known issue in some Flutter toolchains where static getters on plugins 
  // aren't correctly resolved during the first few builds.
  return await (FilePicker as dynamic).platform.getDirectoryPath(
    dialogTitle: 'Select Screenshot Folder',
  );
}

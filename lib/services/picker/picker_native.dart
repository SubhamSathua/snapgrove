import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:saf_util/saf_util.dart';

Future<String?> pickDirectoryPlatform() async {
  if (Platform.isAndroid) {
    // For Android, use SAF (Storage Access Framework) via saf_util
    // This is modern, V2-compatible, and handles content:// URIs
    try {
      final selectedDir = await SafUtil().pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      return selectedDir?.uri;
    } catch (e) {
      return null;
    }
  } else if (Platform.isWindows) {
    // For Windows, use the official file_selector package
    // This is the Flutter team's standard and very stable on Windows 11
    try {
      return await fs.getDirectoryPath(
        confirmButtonText: 'Select Folder',
      );
    } catch (e) {
      return null;
    }
  }
  return null;
}

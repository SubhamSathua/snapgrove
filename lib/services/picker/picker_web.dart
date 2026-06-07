import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('window.showDirectoryPicker')
external JSPromise<web.FileSystemDirectoryHandle> showDirectoryPicker();

Future<String?> pickDirectoryPlatform() async {
  try {
    // This is the "FoldersAPI" (File System Access API)
    final JSPromise<web.FileSystemDirectoryHandle> promise = showDirectoryPicker();
    final web.FileSystemDirectoryHandle handle = await promise.toDart;
    // On web, we return the name of the folder as the "path"
    return handle.name;
  } catch (e) {
    // User cancelled or browser doesn't support it
    return null;
  }
}

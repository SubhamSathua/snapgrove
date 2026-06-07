import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('window.showDirectoryPicker')
external JSPromise<web.FileSystemDirectoryHandle> _showDirectoryPicker();

Future<String?> pickDirectoryPlatform() async {
  try {
    final JSPromise<web.FileSystemDirectoryHandle> promise = _showDirectoryPicker();
    final web.FileSystemDirectoryHandle handle = await promise.toDart;
    return handle.name;
  } catch (e) {
    return null;
  }
}

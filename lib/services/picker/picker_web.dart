import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('window.showDirectoryPicker')
external JSPromise<web.FileSystemDirectoryHandle> _showDirectoryPicker();

// Store the handle globally in JS so we can access it by name or reference
@JS('window._lastPickerHandle')
external set _lastPickerHandle(web.FileSystemDirectoryHandle? handle);

@JS('window._lastPickerHandle')
external web.FileSystemDirectoryHandle? get _lastPickerHandle;

Future<String?> pickDirectoryPlatform() async {
  try {
    final JSPromise<web.FileSystemDirectoryHandle> promise = _showDirectoryPicker();
    final web.FileSystemDirectoryHandle handle = await promise.toDart;
    
    // In a real app, we'd store this handle in IndexedDB.
    // For now, we store it in a global JS variable so the FileService can find it.
    _lastPickerHandle = handle;
    
    // Return the name so the UI knows which folder was picked
    return handle.name;
  } catch (e) {
    return null;
  }
}

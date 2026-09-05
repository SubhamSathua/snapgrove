import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

@JS('window.URL.createObjectURL')
external String _createObjectURL(web.Blob blob);

@JS('window.URL.revokeObjectURL')
external void _revokeObjectURL(String url);

@JS('createImageBitmap')
external JSPromise<web.ImageBitmap> _createImageBitmap(web.Blob blob);

@JS('window.addEventListener')
external void _addEventListener(String type, JSFunction listener);

@JS()
extension type JSAsyncIterator(JSObject _) implements JSObject {
  @JS('next')
  external JSPromise<JSIteratorResult> next();
}

@JS()
extension type JSIteratorResult(JSObject _) implements JSObject {
  @JS('value')
  external JSObject? get value;
  @JS('done')
  external bool get done;
}

extension FileSystemDirectoryHandleExtension on web.FileSystemDirectoryHandle {
  @JS('values')
  external JSAsyncIterator values();
}

extension ImageBitmapExtension on web.ImageBitmap {
  @JS('close')
  external void close();
}

@JS('window._lastPickerHandle')
external web.FileSystemDirectoryHandle? get _lastPickerHandle;

class WebImageUtils {
  static final Map<String, String> _blobCache = {};
  static final List<String> _cacheOrder = [];
  static const int maxCacheSize = 800;
  static final Map<String, web.FileSystemFileHandle> _handleMap = {};

  static bool _exitWarningSet = false;

  static web.FileSystemDirectoryHandle? getLastPickerHandle() => _lastPickerHandle;


  /// Registers the "Do you want to quit?" warning
  static void setExitWarning(bool enabled) {
    if (enabled && !_exitWarningSet) {
      // In JS, just returning a non-null value from beforeunload triggers the browser alert
      final JSFunction handler = (web.Event event) {
        event.preventDefault();
        return 'You have unsaved changes. Do you want to quit?'.toJS;
      }.toJS;
      
      _addEventListener('beforeunload', handler);
      _exitWarningSet = true;
    }
  }

  static Future<List<String>> listImages(dynamic root) async {
    final dir = _lastPickerHandle;
    if (dir == null) return [];
    
    final List<String> files = [];
    _handleMap.clear();

    Future<void> walk(web.FileSystemDirectoryHandle dir, String path) async {
      final entries = dir.values();
      while (true) {
        final result = await entries.next().toDart;
        if (result.done) break;
        
        final entry = result.value as web.FileSystemHandle;
        final currentPath = path.isEmpty ? entry.name : '$path/${entry.name}';

        if (entry.kind == 'directory') {
          await walk(entry as web.FileSystemDirectoryHandle, currentPath);
        } else if (entry.kind == 'file') {
          if (_isImage(entry.name)) {
            files.add(currentPath);
            _handleMap[currentPath] = entry as web.FileSystemFileHandle;
          }
        }
      }
    }

    try {
      await walk(dir, '');
      setExitWarning(true); // Trigger warning once a folder is picked
    } catch (e) {
      debugPrint('Error walking directory: $e');
    }
    return files;
  }

  static bool _isImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp');
  }

  static Future<String?> getThumbnail(String path) async {
    if (_blobCache.containsKey(path)) {
      _touch(path);
      return _blobCache[path];
    }

    final handle = _handleMap[path];
    if (handle == null) return null;

    try {
      final file = await handle.getFile().toDart;
      final bitmap = await _createImageBitmap(file).toDart;
      final canvas = web.OffscreenCanvas(300, 400);
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      
      double scale = 300 / bitmap.width;
      if (bitmap.height * scale < 400) scale = 400 / bitmap.height;
      
      final w = bitmap.width * scale;
      final h = bitmap.height * scale;
      final x = (300 - w) / 2;
      final y = (400 - h) / 2;
      
      ctx.drawImage(bitmap as web.CanvasImageSource, x, y, w, h);
      bitmap.close();

      final blob = await canvas.convertToBlob(web.ImageEncodeOptions(
        type: 'image/jpeg',
        quality: 0.7,
      )).toDart;

      final url = _createObjectURL(blob);
      _addToCache(path, url);
      return url;
    } catch (e) {
      debugPrint('Web Thumbnail Error for $path: $e');
      return null;
    }
  }

  static void _touch(String path) {
    _cacheOrder.remove(path);
    _cacheOrder.add(path);
  }

  static void _addToCache(String path, String url) {
    if (_cacheOrder.length >= maxCacheSize) {
      final oldestPath = _cacheOrder.removeAt(0);
      final oldestUrl = _blobCache.remove(oldestPath);
      if (oldestUrl != null) _revokeObjectURL(oldestUrl);
    }
    _blobCache[path] = url;
    _cacheOrder.add(path);
  }

  static Future<List<String>> listSubfolders() async {
    try {
      final dir = getLastPickerHandle();
      if (dir == null) return [];

      final List<String> folders = [];
      final entries = dir.values();
      while (true) {
        final result = await entries.next().toDart;
        if (result.done) break;
        final entry = result.value as web.FileSystemHandle;
        if (entry.kind == 'directory') {
          folders.add(entry.name);
        }
      }
      folders.sort();
      return folders;
    } catch (e) {
      debugPrint('Web Error: listSubfolders failed: $e');
      return [];
    }
  }

  static Future<bool> createSubfolder(String name) async {
    try {
      final dir = getLastPickerHandle();
      if (dir == null) return false;

      await dir.getDirectoryHandle(
        name,
        web.FileSystemGetDirectoryOptions(create: true),
      ).toDart;
      return true;
    } catch (e) {
      debugPrint('Web Error: createSubfolder failed: $e');
      return false;
    }
  }

  static Future<Uint8List?> readFile(String path) async {
    final handle = _handleMap[path];
    if (handle == null) return null;
    final file = await handle.getFile().toDart;
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  static Future<bool> moveFilesToFolder(String folderName, List<String> files) async {
    try {
      final dir = getLastPickerHandle();
      if (dir == null) return false;

      // Get or create target subfolder
      final targetDir = await dir.getDirectoryHandle(
        folderName,
        web.FileSystemGetDirectoryOptions(create: true),
      ).toDart;

      for (final filePath in files) {
        final handle = _handleMap[filePath];
        if (handle == null) continue;

        final file = await handle.getFile().toDart;
        final buffer = await file.arrayBuffer().toDart;
        final fileName = filePath.split('/').last;

        // Create new file in target directory
        final newFile = await targetDir.getFileHandle(
          fileName,
          web.FileSystemGetFileOptions(create: true),
        ).toDart;

        // Write content
        final writable = await newFile.createWritable().toDart;
        await writable.write(buffer).toDart;
        await writable.close().toDart;

        // Remove source file from root
        await dir.removeEntry(fileName).toDart;
        _handleMap.remove(filePath);
      }
      return true;
    } catch (e) {
      debugPrint('Web Error: moveFilesToFolder failed: $e');
      return false;
    }
  }
}

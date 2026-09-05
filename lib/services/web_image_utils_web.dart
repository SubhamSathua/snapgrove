import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';
import 'exif_cleaner.dart';

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

  static String? getCachedThumbnailUrl(String path) => _blobCache[path];

  static Future<List<String>> listImages(dynamic root, {bool includeSubfolders = false}) async {
    final dir = _lastPickerHandle;
    if (dir == null) return [];
    
    final List<String> files = [];
    _handleMap.clear();

    try {
      final entries = dir.values();
      final List<web.FileSystemDirectoryHandle> subDirs = [];
      while (true) {
        final result = await entries.next().toDart;
        if (result.done) break;
        
        final entry = result.value as web.FileSystemHandle;
        if (entry.kind == 'file') {
          if (_isImage(entry.name)) {
            files.add(entry.name);
            _handleMap[entry.name] = entry as web.FileSystemFileHandle;
          }
        } else if (entry.kind == 'directory') {
          subDirs.add(entry as web.FileSystemDirectoryHandle);
        }
      }

      if (includeSubfolders) {
        for (final subDir in subDirs) {
          try {
            final subEntries = subDir.values();
            while (true) {
              final subResult = await subEntries.next().toDart;
              if (subResult.done) break;
              final subEntry = subResult.value as web.FileSystemHandle;
              if (subEntry.kind == 'file' && _isImage(subEntry.name)) {
                final relPath = '${subDir.name}/${subEntry.name}';
                files.add(relPath);
                _handleMap[relPath] = subEntry as web.FileSystemFileHandle;
              }
            }
          } catch (_) {}
        }
      }

      setExitWarning(true);
    } catch (e) {
      debugPrint('Error listing directory: $e');
    }
    return files;
  }

  static bool _isImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp');
  }

  static final Map<String, List<Completer<String?>>> _inFlight = {};

  static Future<String?> getThumbnail(String path) async {
    if (_blobCache.containsKey(path)) {
      _touch(path);
      return _blobCache[path];
    }

    final handle = _handleMap[path];
    if (handle == null) return null;

    if (_inFlight.containsKey(path)) {
      final completer = Completer<String?>();
      _inFlight[path]!.add(completer);
      return completer.future;
    }

    _inFlight[path] = [];

    try {
      final file = await handle.getFile().toDart;
      final bitmap = await _createImageBitmap(file).toDart;
      final canvas = web.OffscreenCanvas(300, 300);
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      
      double scale = 300 / bitmap.width;
      if (bitmap.height * scale < 300) scale = 300 / bitmap.height;
      
      final w = bitmap.width * scale;
      final h = bitmap.height * scale;
      final x = (300 - w) / 2;
      final y = (300 - h) / 2;
      
      ctx.drawImage(bitmap as web.CanvasImageSource, x, y, w, h);
      bitmap.close();

      final blob = await canvas.convertToBlob(web.ImageEncodeOptions(
        type: 'image/jpeg',
        quality: 0.75,
      )).toDart;

      final url = _createObjectURL(blob);
      _addToCache(path, url);

      final listeners = _inFlight.remove(path);
      if (listeners != null) {
        for (final c in listeners) {
          c.complete(url);
        }
      }
      return url;
    } catch (e) {
      debugPrint('Web Thumbnail Error for $path: $e');
      final listeners = _inFlight.remove(path);
      if (listeners != null) {
        for (final c in listeners) {
          c.complete(null);
        }
      }
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

      final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);

      web.FileSystemDirectoryHandle? targetDir;
      if (!isMovingToRoot) {
        targetDir = await dir.getDirectoryHandle(
          folderName,
          web.FileSystemGetDirectoryOptions(create: true),
        ).toDart;
      }

      for (final filePath in files) {
        final handle = _handleMap[filePath];
        if (handle == null) continue;

        if (isMovingToRoot) {
          // If file is already in root, skip
          if (!filePath.contains('/')) continue;

          final file = await handle.getFile().toDart;
          final buffer = await file.arrayBuffer().toDart;
          final fileName = filePath.split('/').last;

          final rootFile = await dir.getFileHandle(
            fileName,
            web.FileSystemGetFileOptions(create: true),
          ).toDart;

          final writable = await rootFile.createWritable().toDart;
          await writable.write(buffer).toDart;
          await writable.close().toDart;

          final srcFolder = filePath.split('/').first;
          try {
            final srcDir = await dir.getDirectoryHandle(srcFolder).toDart;
            await srcDir.removeEntry(fileName).toDart;
          } catch (_) {}

          _handleMap.remove(filePath);
          _handleMap[fileName] = rootFile;
        } else {
          // If file is already in target subfolder, skip
          if (filePath.contains('/') && filePath.split('/').first == folderName) continue;

          final file = await handle.getFile().toDart;
          final buffer = await file.arrayBuffer().toDart;
          final fileName = filePath.contains('/') ? filePath.split('/').last : filePath;

          final newFile = await targetDir!.getFileHandle(
            fileName,
            web.FileSystemGetFileOptions(create: true),
          ).toDart;

          final writable = await newFile.createWritable().toDart;
          await writable.write(buffer).toDart;
          await writable.close().toDart;

          if (filePath.contains('/')) {
            final srcFolder = filePath.split('/').first;
            try {
              final srcDir = await dir.getDirectoryHandle(srcFolder).toDart;
              await srcDir.removeEntry(fileName).toDart;
            } catch (_) {}
          } else {
            await dir.removeEntry(fileName).toDart;
          }

          _handleMap.remove(filePath);
          final newPath = '$folderName/$fileName';
          _handleMap[newPath] = newFile;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Web Error: moveFilesToFolder failed: $e');
      return false;
    }
  }

  static Future<bool> undoMoveFiles(String folderName, List<String> files) async {
    try {
      final dir = getLastPickerHandle();
      if (dir == null) return false;

      final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);

      if (isMovingToRoot) {
        for (final filePath in files) {
          if (!filePath.contains('/')) continue;
          final srcFolder = filePath.split('/').first;
          final fileName = filePath.split('/').last;

          try {
            final rootFileHandle = await dir.getFileHandle(
              fileName,
              web.FileSystemGetFileOptions(create: false),
            ).toDart;

            final file = await rootFileHandle.getFile().toDart;
            final buffer = await file.arrayBuffer().toDart;

            final srcDir = await dir.getDirectoryHandle(srcFolder).toDart;
            final restoredFile = await srcDir.getFileHandle(
              fileName,
              web.FileSystemGetFileOptions(create: true),
            ).toDart;

            final writable = await restoredFile.createWritable().toDart;
            await writable.write(buffer).toDart;
            await writable.close().toDart;

            await dir.removeEntry(fileName).toDart;
            _handleMap.remove(fileName);
            _handleMap[filePath] = restoredFile;
          } catch (e) {
            debugPrint('Web Error: undoMoveFiles restoring $fileName failed: $e');
          }
        }
        return true;
      }

      final targetDir = await dir.getDirectoryHandle(
        folderName,
        web.FileSystemGetDirectoryOptions(create: false),
      ).toDart;

      for (final filePath in files) {
        final fileName = filePath.split('/').last;
        try {
          final subFileHandle = await targetDir.getFileHandle(
            fileName,
            web.FileSystemGetFileOptions(create: false),
          ).toDart;

          final file = await subFileHandle.getFile().toDart;
          final buffer = await file.arrayBuffer().toDart;

          if (filePath.contains('/')) {
            final origFolder = filePath.split('/').first;
            final origDir = await dir.getDirectoryHandle(origFolder).toDart;
            final origFile = await origDir.getFileHandle(
              fileName,
              web.FileSystemGetFileOptions(create: true),
            ).toDart;

            final writable = await origFile.createWritable().toDart;
            await writable.write(buffer).toDart;
            await writable.close().toDart;
            _handleMap[filePath] = origFile;
          } else {
            // Re-create file in root directory
            final rootFile = await dir.getFileHandle(
              fileName,
              web.FileSystemGetFileOptions(create: true),
            ).toDart;

            final writable = await rootFile.createWritable().toDart;
            await writable.write(buffer).toDart;
            await writable.close().toDart;
            _handleMap[filePath] = rootFile;
          }

          // Remove from target subfolder
          await targetDir.removeEntry(fileName).toDart;
          _handleMap.remove('$folderName/$fileName');
        } catch (e) {
          debugPrint('Web Error: restoring file $fileName failed: $e');
        }
      }
      return true;
    } catch (e) {
      debugPrint('Web Error: undoMoveFiles failed: $e');
      return false;
    }
  }

  static Future<bool> deleteFile(String path) async {
    try {
      final dir = getLastPickerHandle();
      if (dir == null) return false;
      final fileName = path.split('/').last;
      await dir.removeEntry(fileName).toDart;
      _handleMap.remove(path);
      return true;
    } catch (e) {
      debugPrint('Web Error: deleteFile failed: $e');
      return false;
    }
  }

  static Future<String?> renameFile(String path, String newName) async {
    try {
      final handle = _handleMap[path];
      final dir = getLastPickerHandle();
      if (handle == null || dir == null) return null;

      final file = await handle.getFile().toDart;
      final buffer = await file.arrayBuffer().toDart;
      final oldName = path.split('/').last;

      final newFile = await dir.getFileHandle(
        newName,
        web.FileSystemGetFileOptions(create: true),
      ).toDart;

      final writable = await newFile.createWritable().toDart;
      await writable.write(buffer).toDart;
      await writable.close().toDart;

      await dir.removeEntry(oldName).toDart;
      _handleMap.remove(path);
      _handleMap[newName] = newFile;
      return newName;
    } catch (e) {
      debugPrint('Web Error: renameFile failed: $e');
      return null;
    }
  }

  static Future<bool> updateModifiedDate(String path, DateTime newDate) async {
    return true;
  }

  static Future<bool> removeExifData(String path) async {
    try {
      final handle = _handleMap[path];
      if (handle == null) return false;

      final file = await handle.getFile().toDart;
      final buffer = await file.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();
      final ext = path.contains('.') ? path.split('.').last : 'jpg';

      final cleaned = ExifCleaner.stripMetadata(bytes, ext);
      final jsArray = [cleaned.toJS].toJS;

      final writable = await handle.createWritable().toDart;
      await writable.write(jsArray).toDart;
      await writable.close().toDart;

      _blobCache.remove(path);
      return true;
    } catch (e) {
      debugPrint('Web Error: removeExifData failed: $e');
      return false;
    }
  }
}

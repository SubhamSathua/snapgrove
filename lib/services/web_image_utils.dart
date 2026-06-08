import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

@JS('window.URL.createObjectURL')
external String _createObjectURL(web.Blob blob);

@JS('window.URL.revokeObjectURL')
external void _revokeObjectURL(String url);

@JS('createImageBitmap')
external JSPromise<web.ImageBitmap> _createImageBitmap(web.Blob blob);

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

class WebImageUtils {
  static final Map<String, String> _blobCache = {};
  static final List<String> _cacheOrder = [];
  static const int maxCacheSize = 800;

  static final Map<String, web.FileSystemFileHandle> _handleMap = {};

  /// Recursively lists images from a directory handle
  static Future<List<String>> listImages(web.FileSystemDirectoryHandle root) async {
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
      await walk(root, '');
    } catch (e) {
      debugPrint('Error walking directory: $e');
    }
    return files;
  }

  static bool _isImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp');
  }

  /// Generates a thumbnail Blob URL for a specific path
  static Future<String?> getThumbnail(String path) async {
    // 1. Check cache first
    if (_blobCache.containsKey(path)) {
      _touch(path);
      return _blobCache[path];
    }

    final handle = _handleMap[path];
    if (handle == null) return null;

    try {
      final file = await handle.getFile().toDart;
      
      // 2. High performance decoding
      final bitmap = await _createImageBitmap(file).toDart;
      
      // 3. Resize using OffscreenCanvas (no DOM lag)
      final canvas = web.OffscreenCanvas(300, 400);
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      
      // Simple cover fit logic
      double scale = 300 / bitmap.width;
      if (bitmap.height * scale < 400) {
        scale = 400 / bitmap.height;
      }
      
      final w = bitmap.width * scale;
      final h = bitmap.height * scale;
      final x = (300 - w) / 2;
      final y = (400 - h) / 2;
      
      // Draw to canvas
      ctx.drawImage(bitmap as web.CanvasImageSource, x, y, w, h);
      
      // Close the bitmap to free GPU memory
      bitmap.close();

      // 4. Convert to Blob
      final blob = await canvas.convertToBlob(web.ImageEncodeOptions(
        type: 'image/jpeg',
        quality: 0.7,
      )).toDart;

      final url = _createObjectURL(blob);
      
      // 5. Manage Cache
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
      if (oldestUrl != null) {
        _revokeObjectURL(oldestUrl);
      }
    }
    _blobCache[path] = url;
    _cacheOrder.add(path);
  }

  static Future<Uint8List?> readFile(String path) async {
    final handle = _handleMap[path];
    if (handle == null) return null;
    
    final file = await handle.getFile().toDart;
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }
}

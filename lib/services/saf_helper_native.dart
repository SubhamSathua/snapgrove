import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_stream/saf_stream.dart';

class SafHelper {
  static final _safStream = SafStream();
  static const _channel = MethodChannel('com.snapgrove.organizer/saf_utils');
  
  // Simple in-memory cache for thumbnails to avoid redundant bridge calls
  static final Map<String, Uint8List> _thumbnailCache = {};
  static final List<String> _cacheOrder = [];
  static const int _maxCacheSize = 500;

  static Future<List<String>> listImages(String uri) async {
    try {
      final contents = await SafUtil().list(uri);
      return contents
          .where((f) {
            if (f.isDir) return false;
            final name = f.name.toLowerCase();
            return name.endsWith('.png') || 
                   name.endsWith('.jpg') || 
                   name.endsWith('.jpeg') ||
                   name.endsWith('.webp');
          })
          .map((f) => f.uri)
          .toList();
    } catch (e) {
      debugPrint('SAF Error: listImages failed: $e');
      return [];
    }
  }

  /// Calls native Android to get a high-performance thumbnail
  static Future<Uint8List?> getThumbnail(String uri, {int width = 300, int height = 400}) async {
    // Check memory cache first
    if (_thumbnailCache.containsKey(uri)) {
      _touchCache(uri);
      return _thumbnailCache[uri];
    }

    try {
      final Uint8List? bytes = await _channel.invokeMethod('getThumbnail', {
        'uri': uri,
        'width': width,
        'height': height,
      });
      
      if (bytes != null) {
        _addToCache(uri, bytes);
      }
      return bytes;
    } catch (e) {
      debugPrint('SAF Error: Native thumbnail failed for $uri: $e');
      return null;
    }
  }

  static void _touchCache(String uri) {
    _cacheOrder.remove(uri);
    _cacheOrder.add(uri);
  }

  static void _addToCache(String uri, Uint8List bytes) {
    if (_cacheOrder.length >= _maxCacheSize) {
      final oldest = _cacheOrder.removeAt(0);
      _thumbnailCache.remove(oldest);
    }
    _thumbnailCache[uri] = bytes;
    _cacheOrder.add(uri);
  }

  static Future<Uint8List?> readFile(String uri) async {
    try {
      return await _safStream.readFileBytes(uri);
    } catch (e) {
      debugPrint('SAF Error: readFile failed: $e');
      return null;
    }
  }

  static Future<List<String>> listSubfolders(String uri) async {
    try {
      final contents = await SafUtil().list(uri);
      return contents
          .where((f) => f.isDir)
          .map((f) => f.name)
          .toList()
        ..sort();
    } catch (e) {
      debugPrint('SAF Error: listSubfolders failed: $e');
      return [];
    }
  }

  static Future<bool> createSubfolder(String parentUri, String name) async {
    try {
      await SafUtil().mkdirp(parentUri, [name]);
      return true;
    } catch (e) {
      debugPrint('SAF Error: createSubfolder failed: $e');
      return false;
    }
  }

  static Future<bool> moveFilesToFolder(String parentUri, String folderName, List<String> files) async {
    try {
      final targetDir = await SafUtil().mkdirp(parentUri, [folderName]);
      for (final fileUri in files) {
        await SafUtil().moveTo(fileUri, false, parentUri, targetDir.uri);
      }
      return true;
    } catch (e) {
      debugPrint('SAF Error: moveFilesToFolder failed: $e');
      return false;
    }
  }

  static Future<bool> undoMoveFiles(String parentUri, String folderName, List<String> files) async {
    try {
      final targetDir = await SafUtil().mkdirp(parentUri, [folderName]);
      for (final fileUri in files) {
        await SafUtil().moveTo(fileUri, false, targetDir.uri, parentUri);
      }
      return true;
    } catch (e) {
      debugPrint('SAF Error: undoMoveFiles failed: $e');
      return false;
    }
  }
}

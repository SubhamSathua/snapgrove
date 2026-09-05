import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'saf_helper_stub.dart' if (dart.library.io) 'saf_helper_native.dart';

class ThumbnailManager {
  static final ThumbnailManager _instance = ThumbnailManager._internal();
  factory ThumbnailManager() => _instance;
  ThumbnailManager._internal();

  static const _windowsChannel = MethodChannel('com.snapgrove.organizer/windows_utils');

  // In-memory LRU cache for 0ms instant thumbnail access
  static const int _maxCacheSize = 1000;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final List<String> _cacheKeys = <String>[];

  // In-flight deduplication to avoid redundant platform calls
  final Map<String, List<Completer<Uint8List?>>> _inFlight = {};

  // Limited parallel execution to avoid overwhelming the platform channel
  final int _maxConcurrent = 6;
  int _running = 0;
  final _queue = ListQueue<String>();

  Future<Uint8List?> getThumbnail(String path) {
    if (_cache.containsKey(path)) {
      _touch(path);
      return SynchronousFuture<Uint8List?>(_cache[path]);
    }

    final completer = Completer<Uint8List?>();

    if (_inFlight.containsKey(path)) {
      _inFlight[path]!.add(completer);
      return completer.future;
    }

    _inFlight[path] = [completer];
    _queue.add(path);
    _processQueue();
    return completer.future;
  }

  void _touch(String path) {
    _cacheKeys.remove(path);
    _cacheKeys.add(path);
  }

  void _addToCache(String path, Uint8List bytes) {
    if (_cacheKeys.length >= _maxCacheSize) {
      final oldest = _cacheKeys.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[path] = bytes;
    _cacheKeys.add(path);
  }

  void _processQueue() {
    while (_running < _maxConcurrent && _queue.isNotEmpty) {
      final path = _queue.removeFirst();
      _running++;

      _fetch(path).then((bytes) {
        if (bytes != null && bytes.isNotEmpty) {
          _addToCache(path, bytes);
        }
        final listeners = _inFlight.remove(path);
        if (listeners != null) {
          for (final c in listeners) {
            c.complete(bytes);
          }
        }
      }).catchError((e) {
        final listeners = _inFlight.remove(path);
        if (listeners != null) {
          for (final c in listeners) {
            c.complete(null);
          }
        }
      }).whenComplete(() {
        _running--;
        _processQueue();
      });
    }
  }

  Future<Uint8List?> _fetch(String path) async {
    if (kIsWeb) return null;

    if (Platform.isAndroid && path.startsWith('content://')) {
      return await SafHelper.getThumbnail(path);
    } else if (Platform.isWindows) {
      try {
        final Uint8List? bytes = await _windowsChannel.invokeMethod('getThumbnail', {
          'path': path,
          'width': 350,
          'height': 350,
        });
        return bytes;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void clearCache() {
    _cache.clear();
    _cacheKeys.clear();
    _inFlight.clear();
    _queue.clear();
  }
}

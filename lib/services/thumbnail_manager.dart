import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'saf_helper_stub.dart' if (dart.library.io) 'saf_helper_native.dart';

class ThumbnailManager {
  static final ThumbnailManager _instance = ThumbnailManager._internal();
  factory ThumbnailManager() => _instance;
  ThumbnailManager._internal();

  static const _windowsChannel = MethodChannel('com.snapgrove.organizer/windows_utils');

  // Limited parallel execution to avoid overwhelming the platform channel
  final int _maxConcurrent = 4;
  int _running = 0;
  final _queue = ListQueue<_ThumbnailRequest>();
  
  // Track which requests are currently being processed
  final Set<String> _processing = {};

  Future<Uint8List?> getThumbnail(String path) async {
    final completer = Completer<Uint8List?>();
    _queue.add(_ThumbnailRequest(path, completer));
    _processQueue();
    return completer.future;
  }

  void _processQueue() {
    while (_running < _maxConcurrent && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      
      _running++;
      _processing.add(request.uri);
      
      _fetch(request.uri).then((bytes) {
        request.completer.complete(bytes);
      }).catchError((e) {
        request.completer.complete(null);
      }).whenComplete(() {
        _running--;
        _processing.remove(request.uri);
        _processQueue();
      });
    }
  }

  Future<Uint8List?> _fetch(String path) async {
    if (Platform.isAndroid && path.startsWith('content://')) {
      return await SafHelper.getThumbnail(path);
    } else if (Platform.isWindows) {
      try {
        final Uint8List? bytes = await _windowsChannel.invokeMethod('getThumbnail', {
          'path': path,
          'width': 300,
          'height': 400,
        });
        return bytes;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

class _ThumbnailRequest {
  final String uri;
  final Completer<Uint8List?> completer;
  _ThumbnailRequest(this.uri, this.completer);
}

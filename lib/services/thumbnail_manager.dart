import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'saf_helper_stub.dart' if (dart.library.io) 'saf_helper_native.dart';

class ThumbnailManager {
  static final ThumbnailManager _instance = ThumbnailManager._internal();
  factory ThumbnailManager() => _instance;
  ThumbnailManager._internal();

  // Limited parallel execution to avoid overwhelming the platform channel
  final int _maxConcurrent = 4;
  int _running = 0;
  final _queue = ListQueue<_ThumbnailRequest>();
  
  // Track which requests are currently being processed
  final Set<String> _processing = {};

  Future<Uint8List?> getThumbnail(String uri) async {
    final completer = Completer<Uint8List?>();
    _queue.add(_ThumbnailRequest(uri, completer));
    _processQueue();
    return completer.future;
  }

  void _processQueue() {
    while (_running < _maxConcurrent && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      
      // Skip if already being processed or fetched
      if (_processing.contains(request.uri)) {
        // We add it back to the end or just wait? 
        // Better: let the UI handle the FutureBuilder logic.
        _processing.add(request.uri); 
      }

      _running++;
      _processing.add(request.uri);
      
      SafHelper.getThumbnail(request.uri).then((bytes) {
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
}

class _ThumbnailRequest {
  final String uri;
  final Completer<Uint8List?> completer;
  _ThumbnailRequest(this.uri, this.completer);
}

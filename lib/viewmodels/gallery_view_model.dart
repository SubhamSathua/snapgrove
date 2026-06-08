import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/saf_helper_stub.dart'
    if (dart.library.io) '../services/saf_helper_native.dart';

class GalleryViewModel extends ChangeNotifier {
  final String path;
  List<String> _files = [];
  bool _isLoading = false;

  GalleryViewModel({required this.path});

  List<String> get files => _files;
  bool get isLoading => _isLoading;

  Future<void> loadFiles() async {
    if (path.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        _files = List.generate(12, (i) => 'Web Screenshot $i');
      } else if (Platform.isAndroid) {
        _files = await SafHelper.listImages(path);
      } else {
        final dir = Directory(path);
        if (await dir.exists()) {
          _files = dir
              .listSync()
              .where((f) =>
                  f is File &&
                  (f.path.toLowerCase().endsWith('.png') || 
                   f.path.toLowerCase().endsWith('.jpg') ||
                   f.path.toLowerCase().endsWith('.jpeg')))
              .map((f) => f.path)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading files: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}

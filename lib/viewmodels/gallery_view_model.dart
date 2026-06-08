import 'package:flutter/foundation.dart';
import '../services/file_service.dart';

class GalleryViewModel extends ChangeNotifier {
  final String path;
  final FileService _fileService;
  
  List<String> _files = [];
  bool _isLoading = false;

  GalleryViewModel({
    required this.path,
    required FileService fileService,
  }) : _fileService = fileService;

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
      _files = await _fileService.listImages(path);
    } catch (e) {
      debugPrint('Error loading files: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}

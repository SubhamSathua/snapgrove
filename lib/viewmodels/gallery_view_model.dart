import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/file_service.dart';

class GalleryViewModel extends ChangeNotifier {
  final String path;
  final FileService _fileService;
  
  List<String> _files = [];
  bool _isLoading = false;
  
  // Selection state
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  
  // Subfolders for chips
  List<String> _subfolders = [];

  GalleryViewModel({
    required this.path,
    required this._fileService,
  });

  List<String> get files => _files;
  bool get isLoading => _isLoading;
  
  // Selection getters
  bool get isSelectionMode => _isSelectionMode;
  Set<int> get selectedIndices => _selectedIndices;
  int get selectedCount => _selectedIndices.length;
  bool isSelected(int index) => _selectedIndices.contains(index);
  
  // Subfolders getter
  List<String> get subfolders => _subfolders;

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
      await _loadSubfolders();
    } catch (e) {
      debugPrint('Error loading files: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSubfolders() async {
    try {
      if (kIsWeb) {
        // Web: subfolder scanning not yet supported via FileSystemAccess API
        _subfolders = [];
      } else if (Platform.isAndroid) {
        // Android: SAF doesn't easily support listing subdirectories
        _subfolders = [];
      } else {
        // Windows/Linux/macOS: use Directory
        final dir = Directory(path);
        if (await dir.exists()) {
          final entities = await dir.list().toList();
          _subfolders = entities
              .whereType<Directory>()
              .map((d) => p.basename(d.path))
              .toList()
            ..sort();
        }
      }
    } catch (e) {
      debugPrint('Error loading subfolders: $e');
      _subfolders = [];
    }
  }

  void enterSelectionMode() {
    if (!_isSelectionMode) {
      _isSelectionMode = true;
      _selectedIndices.clear();
      notifyListeners();
    }
  }

  void exitSelectionMode() {
    if (_isSelectionMode) {
      _isSelectionMode = false;
      _selectedIndices.clear();
      notifyListeners();
    }
  }

  void toggleSelection(int index) {
    if (!_isSelectionMode) return;
    
    if (_selectedIndices.contains(index)) {
      _selectedIndices.remove(index);
    } else {
      _selectedIndices.add(index);
    }
    notifyListeners();
  }

  void selectAll() {
    if (!_isSelectionMode) return;
    _selectedIndices.clear();
    _selectedIndices.addAll(List.generate(_files.length, (i) => i));
    notifyListeners();
  }

  void clearSelection() {
    _selectedIndices.clear();
    notifyListeners();
  }

  List<String> getSelectedFiles() {
    return _selectedIndices.map((i) => _files[i]).toList();
  }

  Future<bool> createSubfolder(String name) async {
    if (name.trim().isEmpty) return false;
    
    try {
      if (kIsWeb) {
        // Web: FileSystemAccess API doesn't support creating directories yet
        return false;
      } else if (Platform.isAndroid) {
        // Android: Would need SAF createDocument - not implemented yet
        return false;
      } else {
        final dir = Directory(p.join(path, name));
        if (await dir.exists()) return false;
        await dir.create(recursive: true);
        await _loadSubfolders();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error creating subfolder: $e');
      return false;
    }
  }

  Future<bool> moveFilesToFolder(List<String> files, String folderName) async {
    try {
      if (kIsWeb) {
        // Web: Cannot move files with FileSystemAccess API (read-only)
        return false;
      } else if (Platform.isAndroid) {
        // Android: Would need SAF move - not implemented yet
        return false;
      } else {
        final targetDir = Directory(p.join(path, folderName));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        
        for (final filePath in files) {
          final file = File(filePath);
          final fileName = p.basename(filePath);
          final destPath = p.join(targetDir.path, fileName);
          await file.rename(destPath);
        }
        
        await loadFiles(); // Reload to reflect changes
        return true;
      }
    } catch (e) {
      debugPrint('Error moving files: $e');
      return false;
    }
  }
}
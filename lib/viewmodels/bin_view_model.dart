import 'package:flutter/foundation.dart';
import '../services/bin_service.dart';
import '../services/notification_service.dart';

class BinViewModel extends ChangeNotifier {
  final BinService _binService;
  final NotificationService _notificationService;

  BinViewModel(this._binService, this._notificationService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<BinFolderInfo> _folders = [];
  List<BinFolderInfo> get folders => _folders;

  String? _currentFolder;
  String? get currentFolder => _currentFolder;

  List<BinFileInfo> _files = [];
  List<BinFileInfo> get files => _files;

  final Set<String> _selectedFilePaths = {};
  Set<String> get selectedFilePaths => _selectedFilePaths;

  bool get isSelectionMode => _selectedFilePaths.isNotEmpty;
  int get selectedCount => _selectedFilePaths.length;
  bool get isAllSelected => _files.isNotEmpty && _selectedFilePaths.length == _files.length;

  int get totalItemsInAllFolders {
    int total = 0;
    for (final f in _folders) {
      total += f.itemCount;
    }
    return total;
  }

  Future<void> loadFolders() async {
    _isLoading = true;
    _currentFolder = null;
    _selectedFilePaths.clear();
    notifyListeners();

    try {
      _folders = await _binService.listFolders();
    } catch (e) {
      debugPrint('BinViewModel: loadFolders error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openFolder(String folderName) async {
    _currentFolder = folderName;
    _selectedFilePaths.clear();
    _isLoading = true;
    notifyListeners();

    try {
      _files = await _binService.listFiles(folderName);
    } catch (e) {
      debugPrint('BinViewModel: openFolder error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentFolder() async {
    if (_currentFolder == null) {
      await loadFolders();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _files = await _binService.listFiles(_currentFolder!);
    } catch (e) {
      debugPrint('BinViewModel: refreshCurrentFolder error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleSelection(String filePath) {
    if (_selectedFilePaths.contains(filePath)) {
      _selectedFilePaths.remove(filePath);
    } else {
      _selectedFilePaths.add(filePath);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedFilePaths.clear();
    for (final f in _files) {
      _selectedFilePaths.add(f.path);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedFilePaths.clear();
    notifyListeners();
  }

  Future<Uint8List?> getDecryptedImageBytes(String filePath) async {
    return await _binService.readDecryptedFile(filePath);
  }

  Future<bool> emptyFullBin() async {
    _isLoading = true;
    notifyListeners();

    final success = await _binService.emptyFullBin();
    if (success) {
      _folders.clear();
      _files.clear();
      _selectedFilePaths.clear();
      _notificationService.showSnackBar('Bin emptied');
    } else {
      _notificationService.showSnackBar('Failed to empty bin', isError: true);
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> emptyCurrentFolder() async {
    if (_currentFolder == null) return false;
    _isLoading = true;
    notifyListeners();

    final success = await _binService.emptyFolder(_currentFolder!);
    if (success) {
      _files.clear();
      _selectedFilePaths.clear();
      _notificationService.showSnackBar('Folder "$_currentFolder" cleared');
      await loadFolders();
    } else {
      _notificationService.showSnackBar('Failed to empty folder', isError: true);
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> deleteSelectedFiles() async {
    if (_selectedFilePaths.isEmpty) return false;
    final toDelete = List<String>.from(_selectedFilePaths);

    _isLoading = true;
    notifyListeners();

    final count = await _binService.deleteMultipleFiles(toDelete);
    _selectedFilePaths.clear();
    _notificationService.showSnackBar('Permanently deleted $count item${count == 1 ? '' : 's'}');

    if (_currentFolder != null) {
      _files = await _binService.listFiles(_currentFolder!);
    }
    _folders = await _binService.listFolders();

    _isLoading = false;
    notifyListeners();
    return count > 0;
  }

  Future<bool> restoreSelectedFiles({String? targetDirectory}) async {
    if (_selectedFilePaths.isEmpty) return false;
    final toRestore = List<String>.from(_selectedFilePaths);

    _isLoading = true;
    notifyListeners();

    final count = await _binService.restoreMultipleFiles(toRestore, targetDirectory: targetDirectory);
    _selectedFilePaths.clear();
    _notificationService.showSnackBar('Restored $count item${count == 1 ? '' : 's'}');

    if (_currentFolder != null) {
      _files = await _binService.listFiles(_currentFolder!);
    }
    _folders = await _binService.listFolders();

    _isLoading = false;
    notifyListeners();
    return count > 0;
  }

  Future<bool> restoreSingleFile(String filePath, {String? targetDirectory}) async {
    final success = await _binService.restoreFile(filePath, targetDirectory: targetDirectory);
    if (success) {
      _notificationService.showSnackBar('Image restored');
      if (_currentFolder != null) {
        _files = await _binService.listFiles(_currentFolder!);
      }
      _folders = await _binService.listFolders();
      notifyListeners();
    } else {
      _notificationService.showSnackBar('Failed to restore image', isError: true);
    }
    return success;
  }

  Future<bool> deleteSingleFile(String filePath) async {
    final success = await _binService.deleteBinFile(filePath);
    if (success) {
      _notificationService.showSnackBar('Image permanently deleted');
      if (_currentFolder != null) {
        _files = await _binService.listFiles(_currentFolder!);
      }
      _folders = await _binService.listFolders();
      notifyListeners();
    } else {
      _notificationService.showSnackBar('Failed to delete image', isError: true);
    }
    return success;
  }
}

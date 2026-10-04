import 'package:flutter/foundation.dart';
import '../services/bin_service.dart';
import '../services/notification_service.dart';

class BinFilterChipData {
  final String label;
  final String? folderName;
  final int count;

  const BinFilterChipData({
    required this.label,
    required this.folderName,
    required this.count,
  });
}

class BinViewModel extends ChangeNotifier {
  final BinService _binService;
  final NotificationService _notificationService;

  BinViewModel(this._binService, this._notificationService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<BinFileInfo> _allFiles = [];
  List<BinFileInfo> get allFiles => _allFiles;

  String? _activeFilter; // null means 'All'
  String? get activeFilter => _activeFilter;
  String? get currentFolder => _activeFilter;

  List<BinFilterChipData> _filterChips = [];
  List<BinFilterChipData> get filterChips => _filterChips;

  List<BinFolderInfo> _folders = [];
  List<BinFolderInfo> get folders => _folders;

  List<BinFileInfo> get files {
    if (_activeFilter == null) return _allFiles;
    return _allFiles.where((f) => f.folderName == _activeFilter).toList();
  }

  final Set<String> _selectedFilePaths = {};
  Set<String> get selectedFilePaths => _selectedFilePaths;

  bool get isSelectionMode => _selectedFilePaths.isNotEmpty;
  int get selectedCount => _selectedFilePaths.length;
  bool get isAllSelected => files.isNotEmpty && _selectedFilePaths.length == files.length;
  int get totalItemsInAllFolders => _allFiles.length;

  Future<void> loadBin() async {
    _isLoading = true;
    _selectedFilePaths.clear();
    notifyListeners();

    try {
      _allFiles = await _binService.listAllFiles();
      _folders = await _binService.listFolders();
      _computeFilterChips();
    } catch (e) {
      debugPrint('BinViewModel: loadBin error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Alias for backward compatibility
  Future<void> loadFolders() => loadBin();

  void _computeFilterChips() {
    final Map<String, int> counts = {};
    final Map<String, Set<String>> folderToBreadcrumbs = {};

    for (final file in _allFiles) {
      counts[file.folderName] = (counts[file.folderName] ?? 0) + 1;
      if (file.parentBreadcrumb != null && file.parentBreadcrumb!.isNotEmpty) {
        folderToBreadcrumbs.putIfAbsent(file.folderName, () => {}).add(file.parentBreadcrumb!);
      }
    }

    final List<BinFilterChipData> chips = [
      BinFilterChipData(label: 'All', folderName: null, count: _allFiles.length),
    ];

    final sortedFolders = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final folder in sortedFolders) {
      final count = counts[folder] ?? 0;
      final breadcrumbs = folderToBreadcrumbs[folder];
      String label = folder;
      if (breadcrumbs != null && breadcrumbs.length > 1) {
        label = folder;
      }
      chips.add(BinFilterChipData(label: label, folderName: folder, count: count));
    }

    _filterChips = chips;
  }

  void setFilter(String? folderName) {
    if (_activeFilter == folderName) return;
    _activeFilter = folderName;
    _selectedFilePaths.clear();
    notifyListeners();
  }

  void openFolder(String folderName) => setFilter(folderName);

  Future<void> refreshCurrentFolder() => loadBin();

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
    for (final f in files) {
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
      _allFiles.clear();
      _folders.clear();
      _filterChips.clear();
      _selectedFilePaths.clear();
      _activeFilter = null;
      _notificationService.showSnackBar('Bin emptied');
    } else {
      _notificationService.showSnackBar('Failed to empty bin', isError: true);
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> emptyCurrentFolder() async {
    if (_activeFilter == null) return emptyFullBin();
    _isLoading = true;
    notifyListeners();

    final success = await _binService.emptyFolder(_activeFilter!);
    if (success) {
      _selectedFilePaths.clear();
      _notificationService.showSnackBar('Folder "$_activeFilter" cleared');
      _activeFilter = null;
      await loadBin();
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

    await loadBin();

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

    await loadBin();

    _isLoading = false;
    notifyListeners();
    return count > 0;
  }

  Future<bool> restoreSingleFile(String filePath, {String? targetDirectory}) async {
    final success = await _binService.restoreFile(filePath, targetDirectory: targetDirectory);
    if (success) {
      _notificationService.showSnackBar('Image restored');
      await loadBin();
    } else {
      _notificationService.showSnackBar('Failed to restore image', isError: true);
    }
    return success;
  }

  Future<bool> deleteSingleFile(String filePath) async {
    final success = await _binService.deleteBinFile(filePath);
    if (success) {
      _notificationService.showSnackBar('Image permanently deleted');
      await loadBin();
    } else {
      _notificationService.showSnackBar('Failed to delete image', isError: true);
    }
    return success;
  }
}

import '../models/folder_node.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../core/locator.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';

enum SortField {
  dateModified,
  name,
  size,
}

enum SortOrder {
  ascending,
  descending,
}

class GalleryViewModel extends ChangeNotifier {
  final String path;
  final FileService _fileService;
  
  List<String> _files = [];
  bool _isLoading = false;
  
  // Sorting state
  SortField _sortField = SortField.dateModified;
  SortOrder _sortOrder = SortOrder.descending;

  // Subfolders toggle state (in-memory per session, OFF by default)
  static bool _sessionIncludeSubfolders = false;
  bool _includeSubfolders = _sessionIncludeSubfolders;

  // Selection state
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  
  // Subfolders for chips
  List<String> _subfolders = [];
  FolderNode? _folderTree;

  // Folder / Tag sorting state
  String _folderSortOrder = 'name_asc';
  bool _isTagsLoading = false;

  GalleryViewModel({
    required this.path,
    required this._fileService,
  });

  List<String> get files => _files;
  bool get isLoading => _isLoading;
  SortField get sortField => _sortField;
  SortOrder get sortOrder => _sortOrder;
  bool get includeSubfolders => _includeSubfolders;
  
  // Selection getters
  bool get isSelectionMode => _isSelectionMode;
  Set<int> get selectedIndices => _selectedIndices;
  int get selectedCount => _selectedIndices.length;
  bool isSelected(int index) => _selectedIndices.contains(index);
  
  // Subfolders getter
  List<String> get subfolders => _subfolders;
  FolderNode? get folderTree => _folderTree;
  String get folderSortOrder => _folderSortOrder;
  bool get isTagsLoading => _isTagsLoading;

  static String? extractSubfolderTag(String rootPath, String filePath) {
    if (filePath.isEmpty) return null;
    if (kIsWeb) {
      if (filePath.contains('/')) {
        return filePath.split('/').first;
      }
      return null;
    }
    if (filePath.startsWith('content://')) {
      try {
        final decodedFile = Uri.decodeFull(filePath).split('?').first;
        final parts = decodedFile.split('/');
        if (parts.length >= 2) {
          final parentPart = parts[parts.length - 2].split(':').last.trim();
          String rootName = '';
          if (rootPath.isNotEmpty) {
            final decodedRoot = Uri.decodeFull(rootPath).split('?').first;
            final lastSlash = decodedRoot.lastIndexOf('/');
            final lastColon = decodedRoot.lastIndexOf(':');
            if (lastSlash != -1 || lastColon != -1) {
              final splitPoint = lastColon > lastSlash ? lastColon : lastSlash;
              rootName = decodedRoot.substring(splitPoint + 1).trim();
            }
          }
          if (parentPart.isNotEmpty &&
              parentPart != 'document' &&
              parentPart != 'tree' &&
              parentPart.toLowerCase() != rootName.toLowerCase()) {
            return parentPart;
          }
        }
      } catch (_) {}
      return null;
    }
    if (rootPath.isNotEmpty) {
      final parent = p.dirname(filePath);
      final normParent = p.normalize(parent).toLowerCase();
      final normRoot = p.normalize(rootPath).toLowerCase();
      if (normParent != normRoot && normParent.startsWith(normRoot)) {
        return p.basename(parent);
      }
      return null;
    }
    return null;
  }

  String? getSubfolderTag(String filePath) {
    return extractSubfolderTag(path, filePath);
  }

  Future<void> loadFiles() async {
    if (path.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Preserve selection by file paths across reload if selection mode is active
    final selectedPaths = _isSelectionMode
        ? _selectedIndices.where((i) => i < _files.length).map((i) => _files[i]).toSet()
        : <String>{};

    try {
      final storage = locator<StorageService>();
      final savedField = await storage.read('settings', 'sort_field');
      final savedOrder = await storage.read('settings', 'sort_order');
      if (savedField is String) {
        _sortField = SortField.values.firstWhere((e) => e.name == savedField, orElse: () => SortField.dateModified);
      }
      if (savedOrder is String) {
        _sortOrder = SortOrder.values.firstWhere((e) => e.name == savedOrder, orElse: () => SortOrder.descending);
      }

      if (locator.isRegistered<SettingsService>()) {
        _folderSortOrder = locator<SettingsService>().folderSortOrder;
      } else {
        final savedFolderSort = await storage.read('settings', 'folder_sort_order');
        if (savedFolderSort is String && savedFolderSort.isNotEmpty) {
          _folderSortOrder = savedFolderSort;
        }
      }
    } catch (_) {}

    try {
      _files = await _fileService.listImages(path, includeSubfolders: _includeSubfolders);
      _applySort();
      await _loadSubfolders();
    } catch (e) {
      debugPrint('Error loading files: $e');
    }

    if (_isSelectionMode && selectedPaths.isNotEmpty) {
      _selectedIndices.clear();
      for (int i = 0; i < _files.length; i++) {
        if (selectedPaths.contains(_files[i])) {
          _selectedIndices.add(i);
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setIncludeSubfolders(bool enabled) async {
    _sessionIncludeSubfolders = enabled;
    _includeSubfolders = enabled;
    await loadFiles();
  }

  void setSort(SortField field, SortOrder order) {
    _sortField = field;
    _sortOrder = order;
    _applySort();
    try {
      locator<StorageService>().write('settings', 'sort_field', field.name);
      locator<StorageService>().write('settings', 'sort_order', order.name);
    } catch (_) {}
    notifyListeners();
  }

  void _applySort() {
    if (_files.isEmpty) return;

    switch (_sortField) {
      case SortField.name:
        _files.sort((a, b) {
          final nameA = _extractFileName(a).toLowerCase();
          final nameB = _extractFileName(b).toLowerCase();
          final cmp = naturalCompare(nameA, nameB);
          return _sortOrder == SortOrder.ascending ? cmp : -cmp;
        });
        break;

      case SortField.dateModified:
        final dateMap = <String, DateTime>{};
        for (final path in _files) {
          dateMap[path] = _getDateForPath(path);
        }

        _files.sort((a, b) {
          final dateA = dateMap[a]!;
          final dateB = dateMap[b]!;
          int cmp = dateA.compareTo(dateB);
          if (cmp == 0) {
            final nameA = _extractFileName(a).toLowerCase();
            final nameB = _extractFileName(b).toLowerCase();
            cmp = naturalCompare(nameA, nameB);
          }
          return _sortOrder == SortOrder.ascending ? cmp : -cmp;
        });
        break;

      case SortField.size:
        final sizeMap = <String, int>{};
        for (final path in _files) {
          sizeMap[path] = _getSizeForPath(path);
        }

        _files.sort((a, b) {
          final sizeA = sizeMap[a]!;
          final sizeB = sizeMap[b]!;
          int cmp = sizeA.compareTo(sizeB);
          if (cmp == 0) {
            final nameA = _extractFileName(a).toLowerCase();
            final nameB = _extractFileName(b).toLowerCase();
            cmp = naturalCompare(nameA, nameB);
          }
          return _sortOrder == SortOrder.ascending ? cmp : -cmp;
        });
        break;
    }
  }

  static int naturalCompare(String a, String b) {
    final regex = RegExp(r'(\d+|\D+)');
    final matchesA = regex.allMatches(a).map((m) => m.group(0)!).toList();
    final matchesB = regex.allMatches(b).map((m) => m.group(0)!).toList();

    final minLength = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
    for (int i = 0; i < minLength; i++) {
      final segA = matchesA[i];
      final segB = matchesB[i];

      final numA = int.tryParse(segA);
      final numB = int.tryParse(segB);

      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      } else {
        final cmp = segA.compareTo(segB);
        if (cmp != 0) return cmp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  static DateTime _getDateForPath(String path) {
    if (!kIsWeb && !path.startsWith('content://')) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return file.lastModifiedSync();
        }
      } catch (_) {}
    }

    final filename = _extractFileName(path);
    final dateMatch = RegExp(r'(\d{4})[-_]?(\d{2})[-_]?(\d{2})(?:[_\s-]?(\d{2})[-_]?(\d{2})[-_]?(\d{2})?)?').firstMatch(filename);
    if (dateMatch != null) {
      try {
        final year = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final day = int.parse(dateMatch.group(3)!);
        final hour = dateMatch.group(4) != null ? int.parse(dateMatch.group(4)!) : 0;
        final minute = dateMatch.group(5) != null ? int.parse(dateMatch.group(5)!) : 0;
        final second = dateMatch.group(6) != null ? int.parse(dateMatch.group(6)!) : 0;
        if (year >= 1990 && year <= 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day, hour, minute, second);
        }
      } catch (_) {}
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int _getSizeForPath(String path) {
    if (!kIsWeb && !path.startsWith('content://')) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return file.lengthSync();
        }
      } catch (_) {}
    }
    return 0;
  }

  static String _extractFileName(String path) {
    if (path.isEmpty) return '';
    final clean = path.replaceAll(r'\', '/');
    final lastSlash = clean.lastIndexOf('/');
    return lastSlash != -1 ? clean.substring(lastSlash + 1) : clean;
  }

  Future<void> _loadSubfolders() async {
    try {
      _subfolders = await _fileService.listSubfolders(path);
      _folderTree = await _fileService.getFolderTree(path);
      _applyFolderSort();
    } catch (e) {
      debugPrint('Error loading subfolders: $e');
      _subfolders = [];
    }
  }

  void _applyFolderSort() {
    if (_subfolders.isEmpty) return;

    final nodeMap = <String, FolderNode>{};
    if (_folderTree != null) {
      for (final child in _folderTree!.children) {
        nodeMap[child.name.toLowerCase()] = child;
      }
    }

    _subfolders.sort((a, b) {
      final nodeA = nodeMap[a.toLowerCase()];
      final nodeB = nodeMap[b.toLowerCase()];

      switch (_folderSortOrder) {
        case 'name_desc':
          return b.toLowerCase().compareTo(a.toLowerCase());
        case 'items_desc':
          final countA = nodeA?.totalImageCount ?? 0;
          final countB = nodeB?.totalImageCount ?? 0;
          final cmp = countB.compareTo(countA);
          return cmp != 0 ? cmp : a.toLowerCase().compareTo(b.toLowerCase());
        case 'items_asc':
          final countA = nodeA?.totalImageCount ?? 0;
          final countB = nodeB?.totalImageCount ?? 0;
          final cmp = countA.compareTo(countB);
          return cmp != 0 ? cmp : a.toLowerCase().compareTo(b.toLowerCase());
        case 'date_desc':
          final dateA = nodeA?.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = nodeB?.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final cmp = dateB.compareTo(dateA);
          return cmp != 0 ? cmp : a.toLowerCase().compareTo(b.toLowerCase());
        case 'date_asc':
          final dateA = nodeA?.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = nodeB?.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final cmp = dateA.compareTo(dateB);
          return cmp != 0 ? cmp : a.toLowerCase().compareTo(b.toLowerCase());
        case 'name_asc':
        default:
          return a.toLowerCase().compareTo(b.toLowerCase());
      }
    });

    if (_folderTree != null && locator.isRegistered<SettingsService>()) {
      locator<SettingsService>().sortFolderNodes(_folderTree!.children);
    }
  }

  /// Smoothly refreshes the tags/subfolders sorting with an animated skeleton loader.
  /// Selection state (_selectedIndices, _isSelectionMode, and _files) is kept 100% intact.
  Future<void> refreshTagsSmoothly({String? newSortOrder}) async {
    if (newSortOrder != null && newSortOrder.isNotEmpty) {
      _folderSortOrder = newSortOrder;
    } else {
      try {
        if (locator.isRegistered<SettingsService>()) {
          _folderSortOrder = locator<SettingsService>().folderSortOrder;
        } else {
          final storage = locator<StorageService>();
          final saved = await storage.read('settings', 'folder_sort_order');
          if (saved is String && saved.isNotEmpty) {
            _folderSortOrder = saved;
          }
        }
      } catch (_) {}
    }

    _isTagsLoading = true;
    notifyListeners();

    // Subtle delay to allow the skeleton chip animation to render smoothly without UI freeze
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      _folderTree = await _fileService.getFolderTree(path);
      final fresh = await _fileService.listSubfolders(path);
      if (fresh.isNotEmpty) {
        _subfolders = fresh;
      }
      _applyFolderSort();
    } catch (e) {
      debugPrint('Error during smooth tags refresh: $e');
      _applyFolderSort();
    } finally {
      // Selection state remains untouched
      _isTagsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFolderTree() async {
    try {
      _folderTree = await _fileService.getFolderTree(path);
      _subfolders = await _fileService.listSubfolders(path);
      _applyFolderSort();
      notifyListeners();
    } catch (_) {}
  }

  void enterSelectionMode({int? initialIndex}) {
    if (_isSelectionMode) {
      if (initialIndex != null) {
        toggleSelection(initialIndex);
      }
      return;
    }
    _isSelectionMode = true;
    _selectedIndices.clear();
    if (initialIndex != null) {
      _selectedIndices.add(initialIndex);
    }
    notifyListeners();
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
    return _selectedIndices
        .where((i) => i >= 0 && i < _files.length)
        .map((i) => _files[i])
        .toList();
  }

  Future<bool> createSubfolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (_subfolders.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }

    // Optimistically update subfolders list in memory
    _subfolders = [..._subfolders, trimmed];
    _applyFolderSort();
    notifyListeners();

    try {
      final success = await _fileService.createSubfolder(path, trimmed);
      if (!success) {
        _subfolders = _subfolders.where((s) => s != trimmed).toList();
        _applyFolderSort();
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error creating subfolder: $e');
      _subfolders = _subfolders.where((s) => s != trimmed).toList();
      _applyFolderSort();
      notifyListeners();
      return false;
    }
  }

  Future<bool> moveFilesToFolder(List<String> files, String folderName) async {
    try {
      final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
      final filesToMove = files.where((f) {
        final currentTag = getSubfolderTag(f);
        if (isMovingToRoot) {
          return currentTag != null;
        } else {
          return currentTag == null || currentTag.toLowerCase() != folderName.toLowerCase();
        }
      }).toList();

      if (filesToMove.isEmpty) {
        return true;
      }

      // Optimistic removal when viewing current folder without subfolders
      if (!_includeSubfolders && !isMovingToRoot) {
        for (final f in filesToMove) {
          _files.remove(f);
        }
        _selectedIndices.clear();
        notifyListeners();
      }

      final success = await _fileService.moveFilesToFolder(path, folderName, filesToMove);
      if (success) {
        if (_includeSubfolders || isMovingToRoot) {
          await loadFiles();
        }
      } else {
        await loadFiles();
      }
      return success;
    } catch (e) {
      debugPrint('Error moving files: $e');
      await loadFiles();
      return false;
    }
  }

  Future<bool> undoMoveFiles(List<String> files, String folderName) async {
    try {
      final success = await _fileService.undoMoveFiles(path, folderName, files);
      if (success) await loadFiles();
      return success;
    } catch (e) {
      debugPrint('Error undoing move files: $e');
      return false;
    }
  }

  Future<bool> deleteFile(String filePath) async {
    final index = _files.indexOf(filePath);
    if (index != -1) {
      _files.removeAt(index);
      _selectedIndices.remove(index);
      notifyListeners();
    }

    try {
      final success = await _fileService.deleteFile(filePath);
      if (!success) {
        await loadFiles();
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      await loadFiles();
      return false;
    }
  }

  Future<bool> moveToBin(List<String> files) async {
    final toRemove = Set<String>.from(files);
    _files = _files.where((f) => !toRemove.contains(f)).toList();
    _selectedIndices.clear();
    notifyListeners();

    try {
      final success = await _fileService.moveToBin(path, files);
      if (!success) {
        await loadFiles();
      }
      return success;
    } catch (e) {
      debugPrint('Error moving files to bin: $e');
      await loadFiles();
      return false;
    }
  }

  Future<bool> deleteFilesPermanently(List<String> files) async {
    final toRemove = Set<String>.from(files);
    _files = _files.where((f) => !toRemove.contains(f)).toList();
    _selectedIndices.clear();
    notifyListeners();

    try {
      final success = await _fileService.deleteFilesPermanently(files);
      if (!success) {
        await loadFiles();
      }
      return success;
    } catch (e) {
      debugPrint('Error permanently deleting files: $e');
      await loadFiles();
      return false;
    }
  }
}
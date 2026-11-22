import '../models/folder_node.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
  final FileService fileService;
  FileService get _fileService => fileService;
  
  List<String> _files = [];
  bool _isLoading = false;
  
  // Sorting state
  SortField _sortField = SortField.dateModified;
  SortOrder _sortOrder = SortOrder.descending;

  // Subfolders toggle state (in-memory per session, OFF by default)
  static bool _sessionIncludeSubfolders = false;
  bool _includeSubfolders = _sessionIncludeSubfolders;

  // Selection state (path-based file identity)
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};
  
  // Subfolders for chips
  List<String> _subfolders = [];
  FolderNode? _folderTree;

  // Folder / Tag sorting state
  String _folderSortOrder = 'name_asc';
  bool _isTagsLoading = false;

  // Live folder watching and lifecycle synchronization
  StreamSubscription<FileSystemEvent>? _watcherSubscription;
  Timer? _watcherDebounceTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _isInternalFileOperation = false;
  bool _isDisposed = false;

  GalleryViewModel({
    required this.path,
    required this.fileService,
  }) {
    try {
      _lifecycleListener = AppLifecycleListener(
        onResume: () async {
          await refreshLiveFiles();
        },
      );
    } catch (_) {
      // Handled in headless test environments where WidgetsBinding is not initialized
    }
  }

  List<String> get files => _files;
  bool get isLoading => _isLoading;
  SortField get sortField => _sortField;
  SortOrder get sortOrder => _sortOrder;
  bool get includeSubfolders => _includeSubfolders;
  
  // Selection getters
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedPaths => Set.unmodifiable(_selectedPaths);
  int get selectedCount => _selectedPaths.length;
  bool isPathSelected(String path) => _selectedPaths.contains(normalizePathKey(path));
  bool isSelected(int index) {
    if (index >= 0 && index < _files.length) {
      return isPathSelected(_files[index]);
    }
    return _selectedPaths.contains('#index_$index');
  }

  Set<int> get selectedIndices => {
        for (int i = 0; i < _files.length; i++)
          if (isPathSelected(_files[i])) i,
        for (final p in _selectedPaths)
          if (p.startsWith('#index_')) int.tryParse(p.substring(7)) ?? -1,
      }..remove(-1);
  
  // Subfolders getter
  List<String> get subfolders => _subfolders;
  FolderNode? get folderTree => _folderTree;
  String get folderSortOrder => _folderSortOrder;
  bool get isTagsLoading => _isTagsLoading;

  static String normalizePathKey(String filePath) {
    if (filePath.isEmpty) return filePath;
    if (kIsWeb || filePath.startsWith('content://')) {
      return Uri.decodeFull(filePath).trim();
    }
    return p.normalize(filePath).toLowerCase();
  }

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

    // Preserve selection by file identity; remove any files that no longer exist on disk
    if (_isSelectionMode && _selectedPaths.isNotEmpty) {
      final currentKeys = _files.map(normalizePathKey).toSet();
      _selectedPaths.retainAll(currentKeys);
    }

    _isLoading = false;
    notifyListeners();
    startWatching();
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
  /// Selection state (_selectedPaths, _isSelectionMode, and _files) is kept 100% intact.
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

  void enterSelectionMode({int? initialIndex, String? initialPath}) {
    if (_isSelectionMode) {
      if (initialPath != null) {
        toggleSelection(initialPath);
      } else if (initialIndex != null) {
        toggleSelection(initialIndex);
      }
      return;
    }
    _isSelectionMode = true;
    _selectedPaths.clear();
    if (initialPath != null) {
      _selectedPaths.add(normalizePathKey(initialPath));
    } else if (initialIndex != null) {
      if (initialIndex >= 0 && initialIndex < _files.length) {
        _selectedPaths.add(normalizePathKey(_files[initialIndex]));
      } else if (_files.isEmpty) {
        _selectedPaths.add('#index_$initialIndex');
      }
    }
    notifyListeners();
  }

  void exitSelectionMode() {
    if (_isSelectionMode) {
      _isSelectionMode = false;
      _selectedPaths.clear();
      notifyListeners();
    }
  }

  void toggleSelection(dynamic item) {
    if (!_isSelectionMode) return;
    String? path;
    if (item is String) {
      path = item;
    } else if (item is int) {
      if (item >= 0 && item < _files.length) {
        path = _files[item];
      } else if (_files.isEmpty) {
        path = '#index_$item';
      }
    }
    if (path == null) return;

    final key = path.startsWith('#index_') ? path : normalizePathKey(path);
    if (_selectedPaths.contains(key)) {
      _selectedPaths.remove(key);
    } else {
      _selectedPaths.add(key);
    }
    notifyListeners();
  }

  void selectAll() {
    if (!_isSelectionMode) return;
    _selectedPaths.clear();
    for (final f in _files) {
      _selectedPaths.add(normalizePathKey(f));
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    notifyListeners();
  }

  List<String> getSelectedFiles() {
    return _files
        .where((f) => _selectedPaths.contains(normalizePathKey(f)))
        .toList();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void startWatching() {
    stopWatching();
    if (path.isEmpty || _isDisposed) return;
    try {
      final stream = _fileService.watchDirectory(path, recursive: _includeSubfolders);
      if (stream != null) {
        _watcherSubscription = stream.listen(
          (event) {
            if (_isInternalFileOperation || _isDisposed) return;
            _watcherDebounceTimer?.cancel();
            _watcherDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
              if (!_isDisposed && !_isInternalFileOperation) {
                await refreshLiveFiles();
              }
            });
          },
          onError: (e) {
            debugPrint('Directory watcher error: $e');
          },
        );
      }
    } catch (e) {
      debugPrint('Error starting directory watcher: $e');
    }
  }

  void stopWatching() {
    _watcherDebounceTimer?.cancel();
    _watcherDebounceTimer = null;
    _watcherSubscription?.cancel();
    _watcherSubscription = null;
  }

  Future<void> refreshLiveFiles() async {
    if (path.isEmpty || _isLoading || _isInternalFileOperation || _isDisposed) return;

    try {
      final newFiles = await _fileService.listImages(path, includeSubfolders: _includeSubfolders);
      if (_isDisposed) return;

      final currentKeys = _files.map(normalizePathKey).toSet();
      final newKeys = newFiles.map(normalizePathKey).toSet();

      if (currentKeys.length == newKeys.length && currentKeys.containsAll(newKeys)) {
        return;
      }

      _files = newFiles;
      _applySort();
      await _loadSubfolders();

      if (_isSelectionMode && _selectedPaths.isNotEmpty) {
        _selectedPaths.retainAll(newKeys);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing live files: $e');
    }
  }

  Future<bool> createSubfolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (_subfolders.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }

    _isInternalFileOperation = true;
    try {
      // Optimistically update subfolders list in memory
      _subfolders = [..._subfolders, trimmed];
      _applyFolderSort();
      notifyListeners();

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
    } finally {
      _isInternalFileOperation = false;
    }
  }

  Future<bool> moveFilesToFolder(List<String> files, String folderName) async {
    _isInternalFileOperation = true;
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
        final movedKeys = filesToMove.map(normalizePathKey).toSet();
        _files.removeWhere((f) => movedKeys.contains(normalizePathKey(f)));
        _selectedPaths.clear();
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
    } finally {
      _isInternalFileOperation = false;
    }
  }

  Future<bool> undoMoveFiles(List<String> files, String folderName) async {
    _isInternalFileOperation = true;
    try {
      final success = await _fileService.undoMoveFiles(path, folderName, files);
      if (success) await loadFiles();
      return success;
    } catch (e) {
      debugPrint('Error undoing move files: $e');
      return false;
    } finally {
      _isInternalFileOperation = false;
    }
  }

  Future<bool> deleteFile(String filePath) async {
    _isInternalFileOperation = true;
    final key = normalizePathKey(filePath);
    _files.removeWhere((f) => normalizePathKey(f) == key);
    _selectedPaths.remove(key);
    notifyListeners();

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
    } finally {
      _isInternalFileOperation = false;
    }
  }

  Future<bool> moveToBin(List<String> files) async {
    _isInternalFileOperation = true;
    final removedKeys = files.map(normalizePathKey).toSet();
    _files = _files.where((f) => !removedKeys.contains(normalizePathKey(f))).toList();
    _selectedPaths.clear();
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
    } finally {
      _isInternalFileOperation = false;
    }
  }

  Future<bool> deleteFilesPermanently(List<String> files) async {
    _isInternalFileOperation = true;
    final removedKeys = files.map(normalizePathKey).toSet();
    _files = _files.where((f) => !removedKeys.contains(normalizePathKey(f))).toList();
    _selectedPaths.clear();
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
    } finally {
      _isInternalFileOperation = false;
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    stopWatching();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    super.dispose();
  }
}
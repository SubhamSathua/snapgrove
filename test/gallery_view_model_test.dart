import 'dart:async';
import 'package:snapgrove/models/folder_node.dart';
import 'package:snapgrove/models/move_transaction.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapgrove/core/locator.dart';
import 'package:snapgrove/services/file_service.dart';
import 'package:snapgrove/services/storage_service.dart';
import 'package:snapgrove/viewmodels/gallery_view_model.dart';

class MockStorageService implements StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.system;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}

  @override
  Future<String?> getScreenshotDir() async => null;

  @override
  Future<void> saveScreenshotDir(String path) async {}

  @override
  Future<String?> getPermanentScreenshotDir() async => null;

  @override
  Future<void> savePermanentScreenshotDir(String path) async {}

  @override
  Future<void> write(String store, String key, dynamic value) async {
    _data['${store}_$key'] = value;
  }

  @override
  Future<dynamic> read(String store, String key) async => _data['${store}_$key'];
}

class MockFileService implements FileService {
  @override
  Future<List<String>> listImages(String path, {bool includeSubfolders = false}) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final files = <String>[];
    await for (final f in dir.list(recursive: includeSubfolders)) {
      if (f is File) {
        final p = f.path.toLowerCase();
        if (p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg')) {
          files.add(f.path);
        }
      }
    }
    return files;
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<List<String>> listSubfolders(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    return entities
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList()
      ..sort();
  }

  @override
  Future<bool> createSubfolder(String path, String name) async {
    final dir = Directory(p.join(path, name));
    if (await dir.exists()) return false;
    await dir.create(recursive: true);
    return true;
  }

  String _generateUniqueFileName(String targetDirPath, String fileName) {
    final ext = p.extension(fileName);
    final baseName = p.basenameWithoutExtension(fileName);
    String candidateName = fileName;
    int counter = 1;
    while (File(p.join(targetDirPath, candidateName)).existsSync()) {
      candidateName = '$baseName ($counter)$ext';
      counter++;
    }
    return candidateName;
  }

  @override
  @override
  Future<MoveResult> moveFilesToFolder(String path, String folderName, List<String> files) async {
    final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
    final targetDirPath = isMovingToRoot ? path : p.join(path, folderName);
    final targetDir = Directory(targetDirPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final targetDirNorm = p.normalize(targetDirPath).toLowerCase();
    final List<MoveRecord> succeeded = [];
    final List<String> failed = [];

    for (final filePath in files) {
      final file = File(filePath);
      if (!await file.exists()) {
        failed.add(filePath);
        continue;
      }

      final sourceDirNorm = p.normalize(file.parent.path).toLowerCase();
      if (sourceDirNorm == targetDirNorm) {
        succeeded.add(MoveRecord(
          originalSource: filePath,
          exactDestination: filePath,
          targetFolder: folderName,
          timestamp: DateTime.now(),
        ));
        continue;
      }

      final fileName = p.basename(filePath);
      final uniqueFileName = _generateUniqueFileName(targetDirPath, fileName);
      final destPath = p.join(targetDirPath, uniqueFileName);
      if (p.normalize(file.path).toLowerCase() != p.normalize(destPath).toLowerCase() && await file.exists()) {
        await file.rename(destPath);
        succeeded.add(MoveRecord(
          originalSource: filePath,
          exactDestination: destPath,
          targetFolder: folderName,
          timestamp: DateTime.now(),
        ));
      } else {
        failed.add(filePath);
      }
    }
    return MoveResult(succeededRecords: succeeded, failedSources: failed);
  }

  @override
  Future<bool> undoMoveFiles(String path, String folderName, List<String> files, {List<MoveRecord>? records}) async {
    int restored = 0;
    if (records != null && records.isNotEmpty) {
      for (final record in records) {
        final destFile = File(record.exactDestination);
        if (await destFile.exists()) {
          final origDir = p.dirname(record.originalSource);
          final uniqueName = _generateUniqueFileName(origDir, p.basename(record.originalSource));
          await destFile.rename(p.join(origDir, uniqueName));
          restored++;
        }
      }
      return restored > 0 || records.isEmpty;
    }

    final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
    final targetDirPath = isMovingToRoot ? path : p.join(path, folderName);
    final targetDir = Directory(targetDirPath);
    for (final filePath in files) {
      final fileName = p.basename(filePath);
      final currentPath = p.join(targetDir.path, fileName);
      final file = File(currentPath);
      if (await file.exists()) {
        final destDir = p.dirname(filePath);
        final uniqueFileName = _generateUniqueFileName(destDir, fileName);
        final destPath = p.join(destDir, uniqueFileName);
        if (p.normalize(file.path).toLowerCase() != p.normalize(destPath).toLowerCase()) {
          await file.rename(destPath);
          restored++;
        }
      }
    }
    return restored > 0 || files.isEmpty;
  }

  @override
  Future<bool> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  @override
  Future<bool> moveToBin(String path, List<String> files) async {
    for (final f in files) {
      await deleteFile(f);
    }
    return true;
  }

  @override
  Future<bool> deleteFilesPermanently(List<String> files) async {
    for (final f in files) {
      await deleteFile(f);
    }
    return true;
  }

  @override
  Future<String?> renameFile(String path, String newName) async {
    final file = File(path);
    if (await file.exists()) {
      final dir = file.parent.path;
      final newPath = p.join(dir, newName);
      final renamed = await file.rename(newPath);
      return renamed.path;
    }
    return null;
  }

  @override
  Future<bool> updateModifiedDate(String path, DateTime newDate) async {
    final file = File(path);
    if (await file.exists()) {
      await file.setLastModified(newDate);
      return true;
    }
    return false;
  }

  @override
  Future<bool> removeExifData(String path) async {
    return true;
  }
  @override
  Future<FolderNode?> getFolderTree(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return null;
    final entities = await rootDir.list().toList();
    final children = <FolderNode>[];
    for (final e in entities) {
      if (e is Directory) {
        children.add(FolderNode(
          name: p.basename(e.path),
          path: e.path,
          relPath: p.basename(e.path),
        ));
      }
    }
    return FolderNode(
      name: 'ROOT',
      path: rootPath,
      relPath: '',
      children: children,
    );
  }

  @override
  Future<bool> createNestedFolder(String parentPath, String folderName) async {
    final dir = Directory(p.join(parentPath, folderName));
    if (await dir.exists()) return false;
    await dir.create(recursive: true);
    return true;
  }

  @override
  Future<bool> renameFolderNode(String currentPath, String newName) async {
    final dir = Directory(currentPath);
    if (!await dir.exists()) return false;
    final parent = dir.parent.path;
    final targetPath = p.join(parent, newName);
    if (await Directory(targetPath).exists()) return false;
    await dir.rename(targetPath);
    return true;
  }

  @override
  Future<bool> deleteFolderNode(String folderPath) async {
    final dir = Directory(folderPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      return true;
    }
    return false;
  }

  @override
  Future<int?> getFolderSizeBytes(String folderPath) async => null;

  @override
  Future<DateTime?> getFolderModifiedDate(String folderPath) async => null;

  Stream<FileSystemEvent>? mockWatcherStream;

  @override
  Stream<FileSystemEvent>? watchDirectory(String path, {bool recursive = false}) {
    return mockWatcherStream;
  }
}

void main() {
  late Directory tempDir;
  late GalleryViewModel viewModel;
  late MockFileService mockFileService;

  setUpAll(() {
    if (!locator.isRegistered<StorageService>()) {
      locator.registerSingleton<StorageService>(MockStorageService());
    }
  });

  setUp(() async {
    GalleryViewModel.resetSessionSettings();
    mockFileService = MockFileService();
    tempDir = await Directory.systemTemp.createTemp('gallery_test_');
    viewModel = GalleryViewModel(
      path: tempDir.path,
      fileService: mockFileService,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Selection', () {
    test('starts in non-selection mode', () {
      expect(viewModel.isSelectionMode, false);
      expect(viewModel.selectedCount, 0);
    });

    test('enterSelectionMode activates selection', () {
      viewModel.enterSelectionMode();
      expect(viewModel.isSelectionMode, true);
      expect(viewModel.selectedCount, 0);
    });

    test('enterSelectionMode is idempotent', () {
      viewModel.enterSelectionMode();
      viewModel.enterSelectionMode();
      expect(viewModel.isSelectionMode, true);
    });

    test('exitSelectionMode deactivates selection', () {
      viewModel.enterSelectionMode();
      viewModel.toggleSelection(0);
      viewModel.exitSelectionMode();
      expect(viewModel.isSelectionMode, false);
      expect(viewModel.selectedCount, 0);
    });

    test('toggleSelection adds and removes indices', () {
      viewModel.enterSelectionMode();
      viewModel.toggleSelection(0);
      expect(viewModel.selectedCount, 1);
      expect(viewModel.isSelected(0), true);
      viewModel.toggleSelection(0);
      expect(viewModel.selectedCount, 0);
      expect(viewModel.isSelected(0), false);
    });

    test('toggleSelection ignored when not in selection mode', () {
      viewModel.toggleSelection(0);
      expect(viewModel.selectedCount, 0);
    });

    test('selectAll selects all files', () async {
      // Create some test files
      for (int i = 0; i < 3; i++) {
        await File('${tempDir.path}\\test$i.png').create();
      }
      await viewModel.loadFiles();

      viewModel.enterSelectionMode();
      viewModel.selectAll();
      expect(viewModel.selectedCount, 3);
    });

    test('clearSelection empties selection', () {
      viewModel.enterSelectionMode();
      viewModel.toggleSelection(1);
      viewModel.clearSelection();
      expect(viewModel.selectedCount, 0);
    });

    test('getSelectedFiles returns correct paths', () async {
      for (int i = 0; i < 3; i++) {
        await File('${tempDir.path}\\test$i.png').create();
      }
      await viewModel.loadFiles();

      viewModel.enterSelectionMode();
      viewModel.toggleSelection(0);
      viewModel.toggleSelection(2);
      final selected = viewModel.getSelectedFiles();
      expect(selected.length, 2);
      expect(selected.any((f) => f.endsWith('test0.png')), true);
      expect(selected.any((f) => f.endsWith('test2.png')), true);
    });

    test('sorting preserves exact selected files by identity even when index shifts', () async {
      final fA = File('${tempDir.path}\\a_file.png');
      final fZ = File('${tempDir.path}\\z_file.png');
      await fA.create();
      await fZ.create();
      await viewModel.loadFiles();

      // Sort A to Z so a_file is index 0
      viewModel.setSort(SortField.name, SortOrder.ascending);
      expect(viewModel.files.first, fA.path);

      // Select a_file.png
      viewModel.enterSelectionMode(initialPath: fA.path);
      expect(viewModel.selectedCount, 1);
      expect(viewModel.isPathSelected(fA.path), true);
      expect(viewModel.isPathSelected(fZ.path), false);

      // Change sort order to descending: z_file becomes index 0, a_file becomes index 1
      viewModel.setSort(SortField.name, SortOrder.descending);
      expect(viewModel.files.first, fZ.path);
      expect(viewModel.files.last, fA.path);

      // VERIFY: The selected file is STILL a_file (NOT z_file, preventing wrong item deletion)
      expect(viewModel.selectedCount, 1);
      expect(viewModel.isPathSelected(fA.path), true);
      expect(viewModel.isPathSelected(fZ.path), false);
      expect(viewModel.getSelectedFiles().single, fA.path);
    });
  });

  group('Sorting', () {
    test('sorts by name ascending and descending', () async {
      await File('${tempDir.path}\\b.png').create();
      await File('${tempDir.path}\\a.png').create();
      await File('${tempDir.path}\\c.png').create();
      await viewModel.loadFiles();

      viewModel.setSort(SortField.name, SortOrder.ascending);
      expect(viewModel.files.map((f) => p.basename(f)).toList(), ['a.png', 'b.png', 'c.png']);

      viewModel.setSort(SortField.name, SortOrder.descending);
      expect(viewModel.files.map((f) => p.basename(f)).toList(), ['c.png', 'b.png', 'a.png']);
    });
  });

  group('Subfolders', () {
    test('loads existing subfolders after createSubfolder', () async {
      final created = await viewModel.createSubfolder('MyFolder');
      expect(created, true);
      expect(viewModel.subfolders, contains('MyFolder'));
    });

    test('createSubfolder returns false if name is empty', () async {
      final result = await viewModel.createSubfolder('  ');
      expect(result, false);
    });

    test('createSubfolder returns false if folder already exists', () async {
      await viewModel.createSubfolder('Existing');
      final result = await viewModel.createSubfolder('Existing');
      expect(result, false);
    });

    test('subfolders are sorted alphabetically', () async {
      await viewModel.createSubfolder('Beta');
      await viewModel.createSubfolder('Alpha');
      await viewModel.createSubfolder('Gamma');
      expect(viewModel.subfolders, ['Alpha', 'Beta', 'Gamma']);
    });

    test('createSubfolder creates new list instance and updates during active selection', () async {
      viewModel.enterSelectionMode();
      final initialList = viewModel.subfolders;
      final created = await viewModel.createSubfolder('Projects');
      expect(created, true);
      expect(viewModel.subfolders, contains('Projects'));
      expect(identical(initialList, viewModel.subfolders), false);
    });
  });

  group('Move files', () {
    test('moves selected files to target subfolder', () async {
      // Create source files
      final srcFiles = [
        '${tempDir.path}\\img1.png',
        '${tempDir.path}\\img2.png',
        '${tempDir.path}\\readme.txt',
      ];
      for (final f in srcFiles) {
        await File(f).create();
      }

      await viewModel.loadFiles();
      // Only PNG files should be loaded by mock
      expect(viewModel.files.length, 2);

      final result = await viewModel.moveFilesToFolder(
        viewModel.files,
        'Moved',
      );
      expect(result.isSuccess, true);

      // Files should be in subfolder
      final movedDir = Directory('${tempDir.path}\\Moved');
      expect(await movedDir.exists(), true);
      final movedFiles = await movedDir.list().toList();
      expect(movedFiles.length, 2);
    });

    test('moveFilesToFolder creates target folder if not exists', () async {
      final file = File('${tempDir.path}\\test.png');
      await file.create();

      final result = await viewModel.moveFilesToFolder(
        [file.path],
        'NewFolder',
      );
      expect(result.isSuccess, true);

      final target = Directory('${tempDir.path}\\NewFolder');
      expect(await target.exists(), true);
      expect(await File('${tempDir.path}\\NewFolder\\test.png').exists(), true);
    });

    test('undoMoveFiles restores moved files back to source directory', () async {
      final file = File('${tempDir.path}\\to_undo.png');
      await file.create();

      await viewModel.loadFiles();
      expect(viewModel.files.contains(file.path), true);

      final moveResult = await viewModel.moveFilesToFolder([file.path], 'Archive');
      expect(moveResult.isSuccess, true);
      expect(await File('${tempDir.path}\\Archive\\to_undo.png').exists(), true);

      final undoResult = await viewModel.undoMoveFiles([file.path], 'Archive');
      expect(undoResult, true);
      expect(await file.exists(), true);
    });

    test('deleteFile removes file from disk and updates file list', () async {
      final file = File('${tempDir.path}\\to_delete.png');
      await file.create();

      await viewModel.loadFiles();
      expect(viewModel.files.contains(file.path), true);

      final deleteResult = await viewModel.deleteFile(file.path);
      expect(deleteResult, true);
      expect(await file.exists(), false);
      expect(viewModel.files.contains(file.path), false);
    });

    test('includeSubfolders toggles subfolder image loading and computes getSubfolderTag', () async {
      final rootImg = File('${tempDir.path}\\root.png');
      await rootImg.create();
      final subDir = Directory('${tempDir.path}\\Tools');
      await subDir.create();
      final subImg = File('${subDir.path}\\tool.png');
      await subImg.create();

      // By default, includeSubfolders is false
      await viewModel.loadFiles();
      expect(viewModel.files.length, 1);
      expect(viewModel.getSubfolderTag(rootImg.path), isNull);

      // Toggle includeSubfolders on
      await viewModel.setIncludeSubfolders(true);
      expect(viewModel.includeSubfolders, true);
      expect(viewModel.files.length, 2);
      expect(viewModel.getSubfolderTag(rootImg.path), isNull);
      expect(viewModel.getSubfolderTag(subImg.path), 'Tools');
    });

    test('CASE-1: moving files from A, B, Y and root to Y skips files already in Y', () async {
      final rootFile = File('${tempDir.path}\\root_img.png');
      await rootFile.create();

      final dirA = await Directory('${tempDir.path}\\FolderA').create();
      final fileA = File('${dirA.path}\\img_a.png');
      await fileA.create();

      final dirB = await Directory('${tempDir.path}\\FolderB').create();
      final fileB = File('${dirB.path}\\img_b.png');
      await fileB.create();

      final dirY = await Directory('${tempDir.path}\\FolderY').create();
      final fileY = File('${dirY.path}\\img_y.png');
      await fileY.create();

      await viewModel.setIncludeSubfolders(true);
      expect(viewModel.files.length, 4);

      final filesToMove = [rootFile.path, fileA.path, fileB.path, fileY.path];
      final moveSuccess = await viewModel.moveFilesToFolder(filesToMove, 'FolderY');
      expect(moveSuccess.isSuccess, true);

      // All 4 files are now inside FolderY
      expect(await File('${dirY.path}\\root_img.png').exists(), true);
      expect(await File('${dirY.path}\\img_a.png').exists(), true);
      expect(await File('${dirY.path}\\img_b.png').exists(), true);
      expect(await File('${dirY.path}\\img_y.png').exists(), true);

      // Original locations in root, A, B should no longer exist
      expect(await rootFile.exists(), false);
      expect(await fileA.exists(), false);
      expect(await fileB.exists(), false);
    });

    test('ROOT CASE: moving files from A, B, and root to ROOT skips files already in root', () async {
      final rootFile = File('${tempDir.path}\\root_already.png');
      await rootFile.create();

      final dirA = await Directory('${tempDir.path}\\SubA').create();
      final fileA = File('${dirA.path}\\from_a.png');
      await fileA.create();

      final dirB = await Directory('${tempDir.path}\\SubB').create();
      final fileB = File('${dirB.path}\\from_b.png');
      await fileB.create();

      await viewModel.setIncludeSubfolders(true);
      expect(viewModel.files.length, 3);

      final filesToMove = [rootFile.path, fileA.path, fileB.path];
      final moveSuccess = await viewModel.moveFilesToFolder(filesToMove, 'ROOT');
      expect(moveSuccess.isSuccess, true);

      // All 3 files are now in root
      expect(await rootFile.exists(), true);
      expect(await File('${tempDir.path}\\from_a.png').exists(), true);
      expect(await File('${tempDir.path}\\from_b.png').exists(), true);

      // And removed from SubA and SubB
      expect(await fileA.exists(), false);
      expect(await fileB.exists(), false);
    });

    test('COLLISION CASE: moving a file into a folder where same filename exists auto-renames without overwriting', () async {
      // Create root file A.png
      final rootFile = File('${tempDir.path}\\A.png');
      await rootFile.create();
      await rootFile.writeAsString('root content');

      // Create subfolder 'places' with existing A.png
      final placesDir = await Directory('${tempDir.path}\\places').create();
      final placesFile = File('${placesDir.path}\\A.png');
      await placesFile.create();
      await placesFile.writeAsString('places content');

      await viewModel.loadFiles();
      // Moving root A.png into places
      final moveSuccess = await viewModel.moveFilesToFolder([rootFile.path], 'places');
      expect(moveSuccess.isSuccess, true);

      // The original places/A.png should still exist with its original content
      expect(await placesFile.exists(), true);
      expect(await placesFile.readAsString(), 'places content');

      // The moved file should have been renamed to A (1).png
      final renamedFile = File('${placesDir.path}\\A (1).png');
      expect(await renamedFile.exists(), true);
      expect(await renamedFile.readAsString(), 'root content');
    });

    test('SESSION SCOPE: includeSubfolders is session-only and not persisted across sessions', () async {
      final storage = locator<StorageService>();
      await storage.write('settings', 'show_subfolders_images', null);

      await viewModel.setIncludeSubfolders(true);
      expect(viewModel.includeSubfolders, true);

      // Storage should NOT have received show_subfolders_images
      final inStorage = await storage.read('settings', 'show_subfolders_images');
      expect(inStorage, isNull);
    });

    test('OPTIMISTIC UPDATE: createSubfolder updates subfolder list immediately', () async {
      expect(viewModel.subfolders.contains('NewAlbum'), false);
      final created = await viewModel.createSubfolder('NewAlbum');
      expect(created, true);
      expect(viewModel.subfolders.contains('NewAlbum'), true);
    });

    test('OPTIMISTIC UPDATE: moveFilesToFolder removes items from root file list immediately when includeSubfolders is false', () async {
      final file1 = File('${tempDir.path}\\opt_move.png');
      await file1.create();
      await viewModel.loadFiles();
      expect(viewModel.files.contains(file1.path), true);

      final moved = await viewModel.moveFilesToFolder([file1.path], 'NewAlbum');
      expect(moved.isSuccess, true);
      expect(viewModel.files.contains(file1.path), false);
    });

    test('OPTIMISTIC UPDATE: deleteFile removes item immediately from memory list', () async {
      final file1 = File('${tempDir.path}\\opt_delete.png');
      await file1.create();
      await viewModel.loadFiles();
      expect(viewModel.files.contains(file1.path), true);

      final deleted = await viewModel.deleteFile(file1.path);
      expect(deleted, true);
      expect(viewModel.files.contains(file1.path), false);
    });

    test('SORTING: correctly sorts by date modified and file size', () async {
      final fileSmall = File('${tempDir.path}\\small.png');
      await fileSmall.create();
      await fileSmall.writeAsString('a');

      final fileLarge = File('${tempDir.path}\\large.png');
      await fileLarge.create();
      await fileLarge.writeAsString('aaaaaaaaaa');

      await viewModel.loadFiles();
      viewModel.setSort(SortField.size, SortOrder.ascending);
      expect(viewModel.files.first, fileSmall.path);

      viewModel.setSort(SortField.size, SortOrder.descending);
      expect(viewModel.files.first, fileLarge.path);
    });

    test('moveToBin removes selected files and clears selection state', () async {
      final f1 = File('${tempDir.path}\\bin1.png');
      final f2 = File('${tempDir.path}\\bin2.png');
      await f1.create();
      await f2.create();
      await viewModel.loadFiles();

      viewModel.enterSelectionMode();
      viewModel.selectAll();
      expect(viewModel.selectedCount, 2);

      final success = await viewModel.moveToBin([f1.path]);
      expect(success, true);
      expect(viewModel.files.contains(f1.path), false);
      expect(viewModel.files.contains(f2.path), true);
      expect(viewModel.selectedCount, 0);
    });

    test('deleteFilesPermanently removes multiple files immediately', () async {
      final f1 = File('${tempDir.path}\\perm1.png');
      final f2 = File('${tempDir.path}\\perm2.png');
      await f1.create();
      await f2.create();
      await viewModel.loadFiles();

      final success = await viewModel.deleteFilesPermanently([f1.path, f2.path]);
      expect(success, true);
      expect(viewModel.files.contains(f1.path), false);
      expect(viewModel.files.contains(f2.path), false);
    });

    test('undoMoveFiles restores moved files back to root directory', () async {
      final f1 = File('${tempDir.path}\\undo_test.png');
      await f1.create();
      await viewModel.createSubfolder('UndoTarget');
      await viewModel.loadFiles();
      expect(viewModel.files.contains(f1.path), true);

      // Move to subfolder
      final moveSuccess = await viewModel.moveFilesToFolder([f1.path], 'UndoTarget');
      expect(moveSuccess.isSuccess, true);
      expect(viewModel.files.contains(f1.path), false);

      // Undo move
      final undoSuccess = await viewModel.undoMoveFiles([f1.path], 'UndoTarget');
      expect(undoSuccess, true);
      expect(viewModel.files.contains(f1.path), true);
    });

    test('normalizePathKey normalizes paths correctly across Windows and URIs', () {
      expect(GalleryViewModel.normalizePathKey('C:\\Path\\To\\IMAGE.PNG'), 'c:\\path\\to\\image.png');
      expect(GalleryViewModel.normalizePathKey('content://media/external/images%201'), 'content://media/external/images 1');
    });

    test('loadFiles retains selected files that still exist and purges deleted files', () async {
      final f1 = File('${tempDir.path}\\keep.png');
      final f2 = File('${tempDir.path}\\todelete.png');
      await f1.create();
      await f2.create();
      await viewModel.loadFiles();

      viewModel.enterSelectionMode(initialPath: f1.path);
      viewModel.toggleSelection(f2.path);
      expect(viewModel.selectedCount, 2);
      expect(viewModel.isPathSelected(f1.path), true);
      expect(viewModel.isPathSelected(f2.path), true);

      // Externally delete f2
      await f2.delete();
      await viewModel.loadFiles();

      // f1 should remain selected, f2 purged from selection
      expect(viewModel.selectedCount, 1);
      expect(viewModel.isPathSelected(f1.path), true);
      expect(viewModel.isPathSelected(f2.path), false);
    });

    test('toggleSelection supports toggling by file path string directly', () async {
      final f1 = File('${tempDir.path}\\toggle1.png');
      await f1.create();
      await viewModel.loadFiles();

      viewModel.enterSelectionMode();
      expect(viewModel.selectedCount, 0);

      viewModel.toggleSelection(f1.path);
      expect(viewModel.selectedCount, 1);
      expect(viewModel.isPathSelected(f1.path), true);

      viewModel.toggleSelection(f1.path);
      expect(viewModel.selectedCount, 0);
      expect(viewModel.isPathSelected(f1.path), false);
    });

    test('refreshLiveFiles detects external file creation non-destructively without loading flash', () async {
      final f1 = File('${tempDir.path}\\live1.png');
      await f1.create();
      await viewModel.loadFiles();
      expect(viewModel.files.length, 1);
      expect(viewModel.isLoading, false);

      // Externally add a file
      final f2 = File('${tempDir.path}\\live2.png');
      await f2.create();

      // Trigger refreshLiveFiles
      await viewModel.refreshLiveFiles();

      expect(viewModel.files.length, 2);
      expect(viewModel.files.contains(f2.path), true);
      // Verify isLoading was NEVER flipped to true during live sync
      expect(viewModel.isLoading, false);
    });

    test('refreshLiveFiles preserves active selection when external changes occur', () async {
      final f1 = File('${tempDir.path}\\sel_live1.png');
      await f1.create();
      await viewModel.loadFiles();

      viewModel.enterSelectionMode(initialPath: f1.path);
      expect(viewModel.selectedCount, 1);
      expect(viewModel.isPathSelected(f1.path), true);

      // Externally add a second file
      final f2 = File('${tempDir.path}\\sel_live2.png');
      await f2.create();

      await viewModel.refreshLiveFiles();

      expect(viewModel.files.length, 2);
      expect(viewModel.selectedCount, 1);
      expect(viewModel.isPathSelected(f1.path), true);
      expect(viewModel.isPathSelected(f2.path), false);
    });

    test('directory watcher debounces events and triggers refreshLiveFiles', () async {
      final streamController = StreamController<FileSystemEvent>.broadcast();
      mockFileService.mockWatcherStream = streamController.stream;

      final f1 = File('${tempDir.path}\\watch1.png');
      await f1.create();
      await viewModel.loadFiles();
      expect(viewModel.files.length, 1);

      // Start watching with mock stream
      viewModel.startWatching();

      // Externally add another file on disk
      final f2 = File('${tempDir.path}\\watch2.png');
      await f2.create();

      // Emit file system create event into watcher
      streamController.add(FileSystemCreateEvent(f2.path, false));

      // Before 350ms debounce, files should not have updated yet
      expect(viewModel.files.length, 1);

      // Wait past debounce threshold
      await Future.delayed(const Duration(milliseconds: 400));

      expect(viewModel.files.length, 2);
      expect(viewModel.files.contains(f2.path), true);

      await streamController.close();
    });

    test('dispose halts directory watcher and safely handles subsequent calls', () async {
      final streamController = StreamController<FileSystemEvent>.broadcast();
      mockFileService.mockWatcherStream = streamController.stream;

      await viewModel.loadFiles();
      viewModel.startWatching();

      viewModel.dispose();

      // Emitting event after disposal should not throw or cause notifyListeners crash
      streamController.add(FileSystemCreateEvent('dummy.png', false));
      await Future.delayed(const Duration(milliseconds: 100));

      // notifyListeners should be a safe no-op after disposal
      expect(() => viewModel.notifyListeners(), returnsNormally);

      await streamController.close();
    });

    test('MoveResult tracks partial failures and keeps failed files selected for easy retry', () async {
      final f1 = File('${tempDir.path}\\good.png');
      await f1.create();
      final nonExistentPath = '${tempDir.path}\\bad_does_not_exist.png';

      await viewModel.loadFiles();
      viewModel.enterSelectionMode(initialPath: f1.path);
      viewModel.toggleSelection(nonExistentPath);
      expect(viewModel.selectedCount, 2);

      final result = await viewModel.moveFilesToFolder([f1.path, nonExistentPath], 'PartialAlbum');

      expect(result.isPartial, true);
      expect(result.totalMoved, 1);
      expect(result.totalFailed, 1);
      expect(result.failedSources.contains(nonExistentPath), true);

      // Successfully moved f1 is removed from selection; failed nonExistentPath remains selected
      expect(viewModel.isPathSelected(f1.path), false);
      expect(viewModel.isPathSelected(nonExistentPath), true);
    });

    test('Canonical path check prevents self-move from creating duplicate renamed files', () async {
      final f1 = File('${tempDir.path}\\self_move.png');
      await f1.create();
      await viewModel.loadFiles();

      final result = await viewModel.moveFilesToFolder([f1.path], 'ROOT');

      expect(result.isSuccess, true);
      // File remains in place with its original name, no (1) collision duplicate created
      expect(await f1.exists(), true);
      expect(await File('${tempDir.path}\\self_move (1).png').exists(), false);
    });

    test('Exact transaction journal undo restores collision-renamed file without hijacking unrelated files', () async {
      // Create existing receipt in folder
      final receiptsDir = await Directory('${tempDir.path}\\Receipts').create();
      final oldReceipt = File('${receiptsDir.path}\\tax.png');
      await oldReceipt.create();
      await oldReceipt.writeAsString('OLD RECEIPT 2024');

      // Create new receipt in root
      final newReceipt = File('${tempDir.path}\\tax.png');
      await newReceipt.create();
      await newReceipt.writeAsString('NEW RECEIPT 2026');

      await viewModel.loadFiles();

      // Move new receipt into Receipts folder (it should be collision-renamed to tax (1).png)
      final moveResult = await viewModel.moveFilesToFolder([newReceipt.path], 'Receipts');
      expect(moveResult.isSuccess, true);

      final renamedAtDest = File('${receiptsDir.path}\\tax (1).png');
      expect(await renamedAtDest.exists(), true);
      expect(await oldReceipt.exists(), true);
      expect(await oldReceipt.readAsString(), 'OLD RECEIPT 2024');

      // Undo the move using exact records journal
      final undoSuccess = await viewModel.undoMoveFiles(
        [newReceipt.path],
        'Receipts',
        records: moveResult.succeededRecords,
      );
      expect(undoSuccess, true);

      // Verify NEW receipt is restored back to root as tax.png (or tax (1).png if root has tax.png)
      expect(await File('${tempDir.path}\\tax.png').exists(), true);
      expect(await File('${tempDir.path}\\tax.png').readAsString(), 'NEW RECEIPT 2026');

      // CRITICAL: verify the OLD receipt was NOT hijacked or touched!
      expect(await oldReceipt.exists(), true);
      expect(await oldReceipt.readAsString(), 'OLD RECEIPT 2024');
    });

    test('FolderNode isDescendantOrSelf prevents folder loops', () {
      const root = FolderNode(
        name: 'Work',
        path: '/Work',
        relPath: 'Work',
      );

      expect(root.isDescendantOrSelf('Work'), true);
      expect(root.isDescendantOrSelf('Work/Projects'), true);
      expect(root.isDescendantOrSelf('Work/Projects/2026'), true);
      expect(root.isDescendantOrSelf('Personal'), false);
      expect(root.isDescendantOrSelf('WorkPersonal'), false);
    });
  });
}

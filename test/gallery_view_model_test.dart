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
  Future<bool> moveFilesToFolder(String path, String folderName, List<String> files) async {
    final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
    final targetDirPath = isMovingToRoot ? path : p.join(path, folderName);
    final targetDir = Directory(targetDirPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    for (final filePath in files) {
      final file = File(filePath);
      final fileName = p.basename(filePath);
      final uniqueFileName = _generateUniqueFileName(targetDirPath, fileName);
      final destPath = p.join(targetDirPath, uniqueFileName);
      if (p.normalize(file.path).toLowerCase() != p.normalize(destPath).toLowerCase() && await file.exists()) {
        await file.rename(destPath);
      }
    }
    return true;
  }

  @override
  Future<bool> undoMoveFiles(String path, String folderName, List<String> files) async {
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
        }
      }
    }
    return true;
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
      expect(result, true);

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
      expect(result, true);

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
      expect(moveResult, true);
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
      expect(moveSuccess, true);

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
      expect(moveSuccess, true);

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
      expect(moveSuccess, true);

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
      expect(moved, true);
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
  });
}

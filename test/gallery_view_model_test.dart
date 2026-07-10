import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:screenshot_organizer/services/file_service.dart';
import 'package:screenshot_organizer/viewmodels/gallery_view_model.dart';

class MockFileService implements FileService {
  @override
  Future<List<String>> listImages(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final files = <String>[];
    await for (final f in dir.list()) {
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

  @override
  Future<bool> moveFilesToFolder(String path, String folderName, List<String> files) async {
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
    return true;
  }
}

void main() {
  late Directory tempDir;
  late GalleryViewModel viewModel;
  late MockFileService mockFileService;

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
      expect(selected[0].endsWith('test0.png'), true);
      expect(selected[1].endsWith('test2.png'), true);
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
  });
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/folder_node.dart';
import 'exif_cleaner.dart';
import 'saf_helper_stub.dart'
    if (dart.library.io) 'saf_helper_native.dart';
import 'web_image_utils.dart';

abstract class FileService {
  Future<List<String>> listImages(String path, {bool includeSubfolders = false});
  Future<Uint8List?> readFile(String path);
  Future<List<String>> listSubfolders(String path);
  Future<bool> createSubfolder(String path, String name);
  Future<bool> moveFilesToFolder(String path, String folderName, List<String> files);
  Future<bool> undoMoveFiles(String path, String folderName, List<String> files);
  Future<bool> deleteFile(String path);
  Future<bool> moveToBin(String path, List<String> files);
  Future<bool> deleteFilesPermanently(List<String> files);
  Future<String?> renameFile(String path, String newName);
  Future<bool> updateModifiedDate(String path, DateTime newDate);
  Future<bool> removeExifData(String path);

  // Hierarchical Folder Tree & Management
  Future<FolderNode?> getFolderTree(String rootPath);
  Future<bool> createNestedFolder(String parentPath, String folderName);
  Future<bool> renameFolderNode(String currentPath, String newName);
  Future<bool> deleteFolderNode(String folderPath);

  /// Returns the total size in bytes of all files inside [folderPath],
  /// computed recursively.  Returns null on unsupported platforms.
  Future<int?> getFolderSizeBytes(String folderPath);

  /// Returns the last-modified DateTime of the directory at [folderPath].
  /// Returns null when unavailable.
  Future<DateTime?> getFolderModifiedDate(String folderPath);

  /// Human-readable string for a byte count, e.g. "3.4 MB", "120 KB".
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class FileServiceImpl implements FileService {
  @override
  Future<List<String>> listImages(String path, {bool includeSubfolders = false}) async {
    if (path.isEmpty) return [];

    try {
      if (kIsWeb) {
        final handle = WebImageUtils.getLastPickerHandle();
        if (handle != null) {
          return await WebImageUtils.listImages(handle, includeSubfolders: includeSubfolders);
        }
        return [];
      } else if (Platform.isAndroid) {
        return await SafHelper.listImages(path, includeSubfolders: includeSubfolders);
      } else {
        final dir = Directory(path);
        if (await dir.exists()) {
          final List<String> files = [];
          await for (final f in dir.list()) {
            if (f is File) {
              final pStr = f.path.toLowerCase();
              if (pStr.endsWith('.png') || pStr.endsWith('.jpg') || pStr.endsWith('.jpeg') || pStr.endsWith('.webp')) {
                files.add(f.path);
              }
            }
          }
          if (includeSubfolders) {
            await for (final d in dir.list(recursive: true)) {
              if (d is File) {
                final pStr = d.path.toLowerCase();
                if (pStr.endsWith('.png') || pStr.endsWith('.jpg') || pStr.endsWith('.jpeg') || pStr.endsWith('.webp')) {
                  files.add(d.path);
                }
              }
            }
          }
          return files;
        }
      }
    } catch (e) {
      debugPrint('Error listing images: $e');
    }
    return [];
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    if (kIsWeb) {
      return await WebImageUtils.readFile(path);
    }
    if (path.startsWith('content://')) {
      return await SafHelper.readFile(path);
    }
    return await File(path).readAsBytes();
  }

  @override
  Future<List<String>> listSubfolders(String path) async {
    try {
      if (kIsWeb) {
        final handle = WebImageUtils.getLastPickerHandle();
        if (handle != null) {
          return await WebImageUtils.listSubfolders();
        }
        return [];
      } else if (Platform.isAndroid) {
        return await SafHelper.listSubfolders(path);
      } else {
        final dir = Directory(path);
        if (await dir.exists()) {
          final entities = await dir.list().toList();
          return entities
              .whereType<Directory>()
              .map((d) => p.basename(d.path))
              .toList()
            ..sort();
        }
        return [];
      }
    } catch (e) {
      debugPrint('Error listing subfolders: $e');
      return [];
    }
  }

  @override
  Future<bool> createSubfolder(String path, String name) async {
    try {
      if (kIsWeb) {
        return await WebImageUtils.createSubfolder(name);
      } else if (Platform.isAndroid) {
        return await SafHelper.createSubfolder(path, name);
      } else {
        final dir = Directory(p.join(path, name));
        if (await dir.exists()) return false;
        await dir.create(recursive: true);
        return true;
      }
    } catch (e) {
      debugPrint('Error creating subfolder: $e');
      return false;
    }
  }

  @override
  Future<FolderNode?> getFolderTree(String rootPath) async {
    if (rootPath.isEmpty) return null;
    try {
      if (kIsWeb) {
        // Flat fallback for web
        final subnames = await listSubfolders(rootPath);
        final children = subnames.map((name) => FolderNode(
          name: name,
          path: name,
          relPath: name,
        )).toList();
        return FolderNode(
          name: 'ROOT',
          path: rootPath,
          relPath: '',
          children: children,
        );
      } else if (Platform.isAndroid) {
        return await SafHelper.getFolderTree(rootPath);
      } else {
        final rootDir = Directory(rootPath);
        if (!await rootDir.exists()) return null;

        Future<FolderNode> scanNode(Directory dir, String relPath) async {
          final dirName = relPath.isEmpty ? 'ROOT' : p.basename(dir.path);
          int directCount = 0;
          final List<FolderNode> subChildren = [];

          try {
            await for (final entity in dir.list()) {
              if (entity is Directory) {
                final childRel = relPath.isEmpty ? p.basename(entity.path) : '$relPath/${p.basename(entity.path)}';
                final childNode = await scanNode(entity, childRel);
                subChildren.add(childNode);
              } else if (entity is File) {
                final lower = entity.path.toLowerCase();
                if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
                  directCount++;
                }
              }
            }
          } catch (_) {}

          subChildren.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          int total = directCount;
          for (final c in subChildren) {
            total += c.totalImageCount;
          }

          DateTime? mdate;
          try {
            mdate = (await dir.stat()).modified;
          } catch (_) {}

          return FolderNode(
            name: dirName,
            path: dir.path,
            relPath: relPath,
            children: subChildren,
            directImageCount: directCount,
            totalImageCount: total,
            modifiedDate: mdate,
          );
        }

        return await scanNode(rootDir, '');
      }
    } catch (e) {
      debugPrint('Error scanning folder tree: $e');
      return null;
    }
  }

  @override
  Future<bool> createNestedFolder(String parentPath, String folderName) async {
    final trimmed = folderName.trim();
    if (trimmed.isEmpty) return false;
    try {
      if (kIsWeb) {
        return await createSubfolder(parentPath, trimmed);
      } else if (Platform.isAndroid) {
        return await SafHelper.createNestedFolder(parentPath, trimmed);
      } else {
        final dir = Directory(p.join(parentPath, trimmed));
        if (await dir.exists()) return false;
        await dir.create(recursive: true);
        return true;
      }
    } catch (e) {
      debugPrint('Error creating nested folder: $e');
      return false;
    }
  }

  @override
  Future<bool> renameFolderNode(String currentPath, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    try {
      if (kIsWeb) {
        return false;
      } else if (Platform.isAndroid) {
        return await SafHelper.renameFolderNode(currentPath, trimmed);
      } else {
        final dir = Directory(currentPath);
        if (!await dir.exists()) return false;
        final parent = dir.parent.path;
        final targetPath = p.join(parent, trimmed);
        if (await Directory(targetPath).exists()) return false;
        await dir.rename(targetPath);
        return true;
      }
    } catch (e) {
      debugPrint('Error renaming folder: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteFolderNode(String folderPath) async {
    try {
      if (kIsWeb) {
        return false;
      } else if (Platform.isAndroid) {
        return await SafHelper.deleteFolderNode(folderPath);
      } else {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting folder node: $e');
      return false;
    }
  }

  @override
  Future<int?> getFolderSizeBytes(String folderPath) async {
    try {
      if (kIsWeb) return null;
      if (Platform.isAndroid) {
        // SAF doesn't expose recursive folder sizes cheaply; return null and
        // let the UI show a "not available" placeholder.
        return null;
      } else {
        final dir = Directory(folderPath);
        if (!await dir.exists()) return null;
        int total = 0;
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            try {
              total += await entity.length();
            } catch (_) {}
          }
        }
        return total;
      }
    } catch (e) {
      debugPrint('Error calculating folder size: $e');
      return null;
    }
  }

  @override
  Future<DateTime?> getFolderModifiedDate(String folderPath) async {
    try {
      if (kIsWeb) return null;
      if (Platform.isAndroid) return null; // SAF doesn't expose dir mtime
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        return (await dir.stat()).modified;
      }
    } catch (e) {
      debugPrint('Error getting folder modified date: $e');
    }
    return null;
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
    try {
      if (kIsWeb) {
        return await WebImageUtils.moveFilesToFolder(folderName, files);
      } else if (Platform.isAndroid) {
        return await SafHelper.moveFilesToFolder(path, folderName, files);
      } else {
        final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
        final targetDirPath = isMovingToRoot ? path : (p.isAbsolute(folderName) ? folderName : p.join(path, folderName));
        final targetDir = Directory(targetDirPath);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        for (final filePath in files) {
          final file = File(filePath);
          if (!await file.exists()) continue;

          final fileName = p.basename(filePath);
          final uniqueFileName = _generateUniqueFileName(targetDirPath, fileName);
          final destPath = p.join(targetDirPath, uniqueFileName);

          if (p.normalize(file.path).toLowerCase() != p.normalize(destPath).toLowerCase()) {
            try {
              await file.rename(destPath);
            } catch (e) {
              try {
                await file.copy(destPath);
                await file.delete();
              } catch (err) {
                debugPrint('Error moving single file $filePath to $destPath: $err');
              }
            }
          }
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error moving files: $e');
      return false;
    }
  }

  @override
  Future<bool> undoMoveFiles(String path, String folderName, List<String> files) async {
    try {
      if (kIsWeb) {
        return await WebImageUtils.undoMoveFiles(folderName, files);
      } else if (Platform.isAndroid) {
        return await SafHelper.undoMoveFiles(path, folderName, files);
      } else {
        final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
        final targetDirPath = isMovingToRoot ? path : (p.isAbsolute(folderName) ? folderName : p.join(path, folderName));
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
              try {
                await file.rename(destPath);
              } catch (e) {
                try {
                  await file.copy(destPath);
                  await file.delete();
                } catch (err) {
                  debugPrint('Error undoing move file $filePath: $err');
                }
              }
            }
          }
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error undoing move files: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteFile(String path) async {
    try {
      if (kIsWeb) {
        return await WebImageUtils.deleteFile(path);
      } else if (Platform.isAndroid) {
        return await SafHelper.deleteFile(path);
      } else {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
    return false;
  }

  Future<bool> _moveToWindowsRecycleBin(List<String> files) async {
    if (files.isEmpty) return false;
    try {
      final joinedPaths = files.map((f) => "'${f.replaceAll("'", "''")}'").join(', ');
      final psScript = '''
Add-Type -AssemblyName Microsoft.VisualBasic
\$paths = @($joinedPaths)
foreach (\$p in \$paths) {
  if (Test-Path -LiteralPath \$p) {
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
      \$p,
      [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
      [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
    )
  }
}
''';
      final result = await Process.run('powershell', ['-NoProfile', '-Command', psScript]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error moving files to Windows Recycle Bin: $e');
      return false;
    }
  }

  @override
  Future<bool> moveToBin(String path, List<String> files) async {
    try {
      if (kIsWeb) {
        return await deleteFilesPermanently(files);
      } else if (Platform.isAndroid) {
        return await SafHelper.moveToBin(path, files);
      } else if (Platform.isWindows) {
        return await _moveToWindowsRecycleBin(files);
      } else {
        return await deleteFilesPermanently(files);
      }
    } catch (e) {
      debugPrint('Error moving to bin: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteFilesPermanently(List<String> files) async {
    try {
      if (kIsWeb) {
        for (final file in files) {
          await WebImageUtils.deleteFile(file);
        }
        return true;
      } else if (Platform.isAndroid) {
        bool allOk = true;
        for (final file in files) {
          final ok = await SafHelper.deleteFile(file);
          if (!ok) allOk = false;
        }
        return allOk;
      } else {
        for (final path in files) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting files permanently: $e');
      return false;
    }
  }

  @override
  Future<String?> renameFile(String path, String newName) async {
    try {
      if (kIsWeb) {
        return null;
      } else if (Platform.isAndroid) {
        return await SafHelper.renameFile(path, newName);
      } else {
        final file = File(path);
        if (await file.exists()) {
          final dir = file.parent.path;
          final target = p.join(dir, newName);
          final renamed = await file.rename(target);
          return renamed.path;
        }
      }
    } catch (e) {
      debugPrint('Error renaming file: $e');
    }
    return null;
  }

  @override
  Future<bool> updateModifiedDate(String path, DateTime newDate) async {
    try {
      if (kIsWeb) {
        return false;
      } else if (Platform.isAndroid) {
        return await SafHelper.updateModifiedDate(path, newDate);
      } else {
        final file = File(path);
        if (await file.exists()) {
          await file.setLastModified(newDate);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error updating modified date: $e');
    }
    return false;
  }

  @override
  Future<bool> removeExifData(String path) async {
    try {
      if (kIsWeb) {
        return false;
      }
      final rawBytes = await readFile(path);
      if (rawBytes == null) return false;

      final ext = p.extension(path).replaceFirst('.', '');
      final cleanedBytes = ExifCleaner.stripMetadata(rawBytes, ext);

      if (path.startsWith('content://')) {
        return await SafHelper.removeExifData(path);
      } else {
        final file = File(path);
        if (await file.exists()) {
          await file.writeAsBytes(cleanedBytes, flush: true);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error removing EXIF data: $e');
    }
    return false;
  }
}

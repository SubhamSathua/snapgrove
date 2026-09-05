import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
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
  Future<String?> renameFile(String path, String newName);
  Future<bool> updateModifiedDate(String path, DateTime newDate);
  Future<bool> removeExifData(String path);
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
            await for (final d in dir.list()) {
              if (d is Directory) {
                try {
                  await for (final subF in d.list()) {
                    if (subF is File) {
                      final pStr = subF.path.toLowerCase();
                      if (pStr.endsWith('.png') || pStr.endsWith('.jpg') || pStr.endsWith('.jpeg') || pStr.endsWith('.webp')) {
                        files.add(subF.path);
                      }
                    }
                  }
                } catch (_) {}
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
  Future<bool> moveFilesToFolder(String path, String folderName, List<String> files) async {
    try {
      if (kIsWeb) {
        return await WebImageUtils.moveFilesToFolder(folderName, files);
      } else if (Platform.isAndroid) {
        return await SafHelper.moveFilesToFolder(path, folderName, files);
      } else {
        final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
        final targetDirPath = isMovingToRoot ? path : p.join(path, folderName);
        final targetDir = Directory(targetDirPath);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        for (final filePath in files) {
          final file = File(filePath);
          final fileName = p.basename(filePath);
          final destPath = p.join(targetDirPath, fileName);
          if (p.normalize(file.path).toLowerCase() != p.normalize(destPath).toLowerCase() && await file.exists()) {
            await file.rename(destPath);
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
        final targetDirPath = isMovingToRoot ? path : p.join(path, folderName);
        final targetDir = Directory(targetDirPath);
        for (final filePath in files) {
          final fileName = p.basename(filePath);
          final currentPath = p.join(targetDir.path, fileName);
          final file = File(currentPath);
          if (await file.exists() && p.normalize(file.path).toLowerCase() != p.normalize(filePath).toLowerCase()) {
            await file.rename(filePath);
          }
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error undoing file move: $e');
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
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  @override
  Future<String?> renameFile(String path, String newName) async {
    try {
      if (kIsWeb) {
        return await WebImageUtils.renameFile(path, newName);
      } else if (Platform.isAndroid && path.startsWith('content://')) {
        return await SafHelper.renameFile(path, newName);
      } else {
        final file = File(path);
        if (await file.exists()) {
          final dir = file.parent.path;
          final newPath = p.join(dir, newName);
          final renamed = await file.rename(newPath);
          return renamed.path;
        }
        return null;
      }
    } catch (e) {
      debugPrint('Error renaming file: $e');
      return null;
    }
  }

  @override
  Future<bool> updateModifiedDate(String path, DateTime newDate) async {
    try {
      if (kIsWeb) {
        return await WebImageUtils.updateModifiedDate(path, newDate);
      } else if (Platform.isAndroid && path.startsWith('content://')) {
        return await SafHelper.updateModifiedDate(path, newDate);
      } else {
        final file = File(path);
        if (await file.exists()) {
          await file.setLastModified(newDate);
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error updating modified date: $e');
      return false;
    }
  }

  @override
  Future<bool> removeExifData(String path) async {
    try {
      if (kIsWeb) {
        return await WebImageUtils.removeExifData(path);
      } else if (Platform.isAndroid && path.startsWith('content://')) {
        return await SafHelper.removeExifData(path);
      } else {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = p.extension(path);
          final cleaned = ExifCleaner.stripMetadata(bytes, ext);
          await file.writeAsBytes(cleaned);
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error removing EXIF data: $e');
      return false;
    }
  }
}

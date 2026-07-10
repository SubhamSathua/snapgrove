import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'saf_helper_stub.dart'
    if (dart.library.io) 'saf_helper_native.dart';
import 'web_image_utils.dart';

abstract class FileService {
  Future<List<String>> listImages(String path);
  Future<Uint8List?> readFile(String path);
  Future<List<String>> listSubfolders(String path);
  Future<bool> createSubfolder(String path, String name);
  Future<bool> moveFilesToFolder(String path, String folderName, List<String> files);
}

class FileServiceImpl implements FileService {
  @override
  Future<List<String>> listImages(String path) async {
    if (path.isEmpty) return [];

    try {
      if (kIsWeb) {
        final handle = WebImageUtils.getLastPickerHandle();
        if (handle != null) {
          return await WebImageUtils.listImages(handle);
        }
        return [];
      } else if (Platform.isAndroid) {
        return await SafHelper.listImages(path);
      } else {
        final dir = Directory(path);
        if (await dir.exists()) {
          final List<String> files = [];
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
    } catch (e) {
      debugPrint('Error moving files: $e');
      return false;
    }
  }
}

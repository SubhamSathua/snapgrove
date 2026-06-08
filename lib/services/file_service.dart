import 'dart:io';
import 'package:flutter/foundation.dart';
import 'saf_helper_stub.dart'
    if (dart.library.io) 'saf_helper_native.dart';
import 'web_image_utils.dart';

abstract class FileService {
  Future<List<String>> listImages(String path);
  Future<Uint8List?> readFile(String path);
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
}

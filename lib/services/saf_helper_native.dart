import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_stream/saf_stream.dart';
import 'exif_cleaner.dart';

class SafHelper {
  static final _safStream = SafStream();
  static const _channel = MethodChannel('com.snapgrove.organizer/saf_utils');
  
  // Simple in-memory cache for thumbnails to avoid redundant bridge calls
  static final Map<String, Uint8List> _thumbnailCache = {};
  static final List<String> _cacheOrder = [];
  static const int _maxCacheSize = 500;

  static Future<List<String>> listImages(String uri, {bool includeSubfolders = false}) async {
    try {
      final contents = await SafUtil().list(uri);
      final List<String> result = [];
      final subdirs = <dynamic>[];
      for (final f in contents) {
        if (!f.isDir) {
          final name = f.name.toLowerCase();
          if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.webp')) {
            result.add(f.uri);
          }
        } else {
          subdirs.add(f);
        }
      }

      if (includeSubfolders) {
        for (final sub in subdirs) {
          try {
            final subContents = await SafUtil().list(sub.uri);
            for (final f in subContents) {
              if (!f.isDir) {
                final name = f.name.toLowerCase();
                if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.webp')) {
                  result.add(f.uri);
                }
              }
            }
          } catch (_) {}
        }
      }

      return result;
    } catch (e) {
      debugPrint('SAF Error: listImages failed: $e');
      return [];
    }
  }

  /// Calls native Android to get a high-performance thumbnail
  static Future<Uint8List?> getThumbnail(String uri, {int width = 300, int height = 400}) async {
    // Check memory cache first
    if (_thumbnailCache.containsKey(uri)) {
      _touchCache(uri);
      return _thumbnailCache[uri];
    }

    try {
      final Uint8List? bytes = await _channel.invokeMethod('getThumbnail', {
        'uri': uri,
        'width': width,
        'height': height,
      });
      
      if (bytes != null) {
        _addToCache(uri, bytes);
      }
      return bytes;
    } catch (e) {
      debugPrint('SAF Error: Native thumbnail failed for $uri: $e');
      return null;
    }
  }

  static void _touchCache(String uri) {
    _cacheOrder.remove(uri);
    _cacheOrder.add(uri);
  }

  static void _addToCache(String uri, Uint8List bytes) {
    if (_cacheOrder.length >= _maxCacheSize) {
      final oldest = _cacheOrder.removeAt(0);
      _thumbnailCache.remove(oldest);
    }
    _thumbnailCache[uri] = bytes;
    _cacheOrder.add(uri);
  }

  static Future<Uint8List?> readFile(String uri) async {
    try {
      return await _safStream.readFileBytes(uri);
    } catch (e) {
      debugPrint('SAF Error: readFile failed: $e');
      return null;
    }
  }

  static Future<List<String>> listSubfolders(String uri) async {
    try {
      final contents = await SafUtil().list(uri);
      return contents
          .where((f) => f.isDir)
          .map((f) => f.name)
          .toList()
        ..sort();
    } catch (e) {
      debugPrint('SAF Error: listSubfolders failed: $e');
      return [];
    }
  }

  static Future<bool> createSubfolder(String parentUri, String name) async {
    try {
      await SafUtil().mkdirp(parentUri, [name]);
      return true;
    } catch (e) {
      debugPrint('SAF Error: createSubfolder failed: $e');
      return false;
    }
  }

  static String _generateUniqueName(Set<String> existingNames, String originalName) {
    final lastDot = originalName.lastIndexOf('.');
    final baseName = lastDot != -1 ? originalName.substring(0, lastDot) : originalName;
    final ext = lastDot != -1 ? originalName.substring(lastDot) : '';

    String candidate = originalName;
    int counter = 1;
    while (existingNames.contains(candidate.toLowerCase())) {
      candidate = '$baseName ($counter)$ext';
      counter++;
    }
    return candidate;
  }

  static Future<bool> moveFilesToFolder(String parentUri, String folderName, List<String> files) async {
    try {
      final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
      final destUri = isMovingToRoot ? parentUri : (await SafUtil().mkdirp(parentUri, [folderName])).uri;
      
      // Query destination folder once for batch collision checking
      Set<String> existingNames = {};
      try {
        final contents = await SafUtil().list(destUri);
        existingNames = contents.map((f) => f.name.toLowerCase()).toSet();
      } catch (_) {}

      for (final fileUri in files) {
        String effectiveFileUri = fileUri;
        try {
          final originalName = Uri.decodeFull(fileUri).split('/').last.split('%2F').last;
          final uniqueName = _generateUniqueName(existingNames, originalName);
          existingNames.add(uniqueName.toLowerCase());
          if (uniqueName != originalName) {
            final renamedDoc = await SafUtil().rename(fileUri, false, uniqueName);
            effectiveFileUri = renamedDoc.uri;
          }
        } catch (_) {}

        bool moved = false;
        try {
          await SafUtil().moveTo(effectiveFileUri, false, parentUri, destUri);
          moved = true;
        } catch (_) {
          moved = false;
        }

        if (!moved) {
          try {
            await SafUtil().copyTo(effectiveFileUri, false, destUri);
            await SafUtil().delete(effectiveFileUri, false);
          } catch (e) {
            debugPrint('SAF Error: copy+delete fallback failed for $effectiveFileUri: $e');
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('SAF Error: moveFilesToFolder failed: $e');
      return false;
    }
  }

  static Future<bool> undoMoveFiles(String parentUri, String folderName, List<String> files) async {
    try {
      final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
      final targetDirUri = isMovingToRoot ? parentUri : (await SafUtil().mkdirp(parentUri, [folderName])).uri;
      
      // Query parent folder once for batch collision checking
      Set<String> existingNames = {};
      try {
        final contents = await SafUtil().list(parentUri);
        existingNames = contents.map((f) => f.name.toLowerCase()).toSet();
      } catch (_) {}

      for (final fileUri in files) {
        String effectiveFileUri = fileUri;
        try {
          final originalName = Uri.decodeFull(fileUri).split('/').last.split('%2F').last;
          final uniqueName = _generateUniqueName(existingNames, originalName);
          existingNames.add(uniqueName.toLowerCase());
          if (uniqueName != originalName) {
            final renamedDoc = await SafUtil().rename(fileUri, false, uniqueName);
            effectiveFileUri = renamedDoc.uri;
          }
        } catch (_) {}

        bool restored = false;
        try {
          await SafUtil().moveTo(effectiveFileUri, false, targetDirUri, parentUri);
          restored = true;
        } catch (_) {
          restored = false;
        }

        if (!restored) {
          try {
            await SafUtil().copyTo(effectiveFileUri, false, parentUri);
            await SafUtil().delete(effectiveFileUri, false);
          } catch (e) {
            debugPrint('SAF Error: undo move copy+delete failed for $effectiveFileUri: $e');
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('SAF Error: undoMoveFiles failed: $e');
      return false;
    }
  }

  static Future<Directory> _getAndroidBinDir(String openedFolderName) async {
    Directory? baseDir;
    try {
      final extDirs = await getExternalStorageDirectories(type: StorageDirectory.pictures);
      if (extDirs != null && extDirs.isNotEmpty) {
        final path = extDirs.first.path;
        final parts = path.split('/Android/');
        if (parts.length > 1) {
          final rootStorage = parts.first;
          baseDir = Directory('$rootStorage/Android/media/com.prism.snapgrove/.bin');
        }
      }
    } catch (_) {}

    baseDir ??= Directory('/storage/emulated/0/Android/media/com.prism.snapgrove/.bin');

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final nomedia = File('${baseDir.path}/.nomedia');
    if (!await nomedia.exists()) {
      await nomedia.create();
    }

    final folderClean = openedFolderName.isEmpty ? 'Screenshots' : openedFolderName;
    final targetFolder = Directory('${baseDir.path}/$folderClean');
    if (!await targetFolder.exists()) {
      await targetFolder.create(recursive: true);
    }
    return targetFolder;
  }

  static Uint8List _alterBytes(Uint8List original) {
    final header = Uint8List.fromList([0x53, 0x47, 0x42, 0x49, 0x4E, 0x01, 0xAA, 0x55]); // SGBIN\x01\xAA\x55
    final result = Uint8List(header.length + original.length);
    result.setRange(0, header.length, header);
    result.setRange(header.length, result.length, original);
    final maskLen = (original.length < 128) ? original.length : 128;
    for (int i = 0; i < maskLen; i++) {
      result[header.length + i] ^= 0xAA;
    }
    return result;
  }

  static Future<bool> moveToBin(String parentUri, List<String> files) async {
    try {
      final openedFolderName = Uri.decodeFull(parentUri).split('/').last.split('%2F').last;
      final targetBinDir = await _getAndroidBinDir(openedFolderName);

      for (final fileUri in files) {
        try {
          final originalName = Uri.decodeFull(fileUri).split('/').last.split('%2F').last;
          final bytes = await _safStream.readFileBytes(fileUri);
          if (bytes.isNotEmpty) {
            final altered = _alterBytes(bytes);
            final destFile = File('${targetBinDir.path}/$originalName.sgbin');
            await destFile.writeAsBytes(altered, flush: true);
            await SafUtil().delete(fileUri, false);
          } else {
            await SafUtil().delete(fileUri, false);
          }
        } catch (e) {
          debugPrint('SAF Error: moveToBin failed for $fileUri: $e');
        }
      }
      return true;
    } catch (e) {
      debugPrint('SAF Error: moveToBin overall failed: $e');
      return false;
    }
  }

  static Future<bool> deleteFile(String uri) async {
    try {
      await SafUtil().delete(uri, false);
      return true;
    } catch (e) {
      debugPrint('SAF Error: deleteFile failed: $e');
      return false;
    }
  }

  static Future<String?> renameFile(String uri, String newName) async {
    try {
      final doc = await SafUtil().rename(uri, false, newName);
      return doc.uri;
    } catch (e) {
      debugPrint('SAF Error: renameFile failed: $e');
      return null;
    }
  }

  static Future<bool> updateModifiedDate(String uri, DateTime newDate) async {
    // SAF doesn't easily allow overriding native filesystem modified timestamp directly
    return true;
  }

  static Future<bool> removeExifData(String uri) async {
    try {
      final bytes = await _safStream.readFileBytes(uri);
      final ext = uri.contains('.') ? uri.split('.').last.split('?').first : 'jpg';
      final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
      final cleaned = ExifCleaner.stripMetadata(bytes, ext);
      final fileName = uri.contains('/') ? uri.split('/').last.split('%2F').last : 'image.$ext';
      await _safStream.writeFileBytes(uri, fileName, mime, cleaned, overwrite: true);
      return true;
    } catch (e) {
      debugPrint('SAF Error: removeExifData failed: $e');
      return false;
    }
  }
}

import '../models/folder_node.dart';
import '../models/move_transaction.dart';
import 'bin_service.dart';
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

  static Future<MoveResult> moveFilesToFolder(String parentUri, String folderName, List<String> files) async {
    try {
      final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
      final destUri = isMovingToRoot ? parentUri : (await SafUtil().mkdirp(parentUri, folderName.split('/'))).uri;
      
      // Query destination folder once for batch collision checking
      Set<String> existingNames = {};
      try {
        final contents = await SafUtil().list(destUri);
        existingNames = contents.map((f) => f.name.toLowerCase()).toSet();
      } catch (_) {}

      final List<MoveRecord> succeeded = [];
      final List<String> failed = [];

      for (final fileUri in files) {
        try {
          final originalName = Uri.decodeFull(fileUri).split('/').last.split('%2F').last;

          // Check if file is already in destination folder (Pillar 4)
          final currentFolder = _extractSubfolderFromUri(parentUri, fileUri);
          final isAlreadyInDest = isMovingToRoot
              ? (currentFolder == null || currentFolder.isEmpty)
              : (currentFolder != null && currentFolder.toLowerCase() == folderName.toLowerCase());

          if (isAlreadyInDest) {
            succeeded.add(MoveRecord(
              originalSource: fileUri,
              exactDestination: fileUri,
              targetFolder: folderName,
              timestamp: DateTime.now(),
            ));
            continue;
          }

          final uniqueName = _generateUniqueName(existingNames, originalName);
          existingNames.add(uniqueName.toLowerCase());

          // Determine the source parent URI
          String sourceParentUri = parentUri;
          if (currentFolder != null && currentFolder.isNotEmpty) {
            try {
              sourceParentUri = (await SafUtil().mkdirp(parentUri, currentFolder.split('/'))).uri;
            } catch (_) {}
          }

          bool moved = false;
          dynamic movedDoc;
          try {
            movedDoc = await SafUtil().moveTo(fileUri, false, sourceParentUri, destUri);
            moved = true;
          } catch (_) {
            moved = false;
          }

          if (moved && movedDoc != null) {
            String finalDocUri = movedDoc.uri;
            if (uniqueName != originalName) {
              try {
                final renamed = await SafUtil().rename(movedDoc.uri, false, uniqueName);
                finalDocUri = renamed.uri;
              } catch (e) {
                debugPrint('SAF Warning: rename at destination failed for ${movedDoc.uri}: $e');
              }
            }
            succeeded.add(MoveRecord(
              originalSource: fileUri,
              exactDestination: finalDocUri,
              targetFolder: folderName,
              timestamp: DateTime.now(),
            ));
          } else {
            try {
              final copiedDoc = await SafUtil().copyTo(fileUri, false, destUri);
              String targetDocUri = copiedDoc.uri;
              if (uniqueName != originalName) {
                try {
                  final renamedDoc = await SafUtil().rename(copiedDoc.uri, false, uniqueName);
                  targetDocUri = renamedDoc.uri;
                } catch (_) {}
              }

              final destExists = await SafUtil().exists(targetDocUri, false);
              if (destExists) {
                await SafUtil().delete(fileUri, false);
                succeeded.add(MoveRecord(
                  originalSource: fileUri,
                  exactDestination: targetDocUri,
                  targetFolder: folderName,
                  timestamp: DateTime.now(),
                ));
              } else {
                debugPrint('SAF Error: fallback copyTo verification failed for $fileUri');
                failed.add(fileUri);
              }
            } catch (e) {
              debugPrint('SAF Error: copy+delete fallback failed for $fileUri: $e');
              failed.add(fileUri);
            }
          }
        } catch (e) {
          debugPrint('SAF Error: moveFilesToFolder single file failed for $fileUri: $e');
          failed.add(fileUri);
        }
      }
      return MoveResult(succeededRecords: succeeded, failedSources: failed);
    } catch (e) {
      debugPrint('SAF Error: moveFilesToFolder failed: $e');
      return MoveResult(succeededRecords: [], failedSources: files);
    }
  }

  static Future<bool> undoMoveFiles(String parentUri, String folderName, List<String> files, {List<MoveRecord>? records}) async {
    try {
      final bool isMovingToRoot = (folderName == 'ROOT' || folderName.isEmpty);
      int restoredCount = 0;

      if (records != null && records.isNotEmpty) {
        // Exact Transaction Journal Undo (Pillar 5): Invert exactDestination -> originalSource directly!
        for (final record in records) {
          try {
            final currentDocUri = record.exactDestination;
            final originalFileUri = record.originalSource;

            String currentFolderUri;
            String originalFolderUri;

            if (isMovingToRoot) {
              currentFolderUri = parentUri;
              final originalSubfolder = _extractSubfolderFromUri(parentUri, originalFileUri);
              if (originalSubfolder == null || originalSubfolder.isEmpty) continue;
              originalFolderUri = (await SafUtil().mkdirp(parentUri, originalSubfolder.split('/'))).uri;
            } else {
              currentFolderUri = (await SafUtil().mkdirp(parentUri, folderName.split('/'))).uri;
              final originalSubfolder = _extractSubfolderFromUri(parentUri, originalFileUri);
              if (originalSubfolder != null && originalSubfolder.isNotEmpty) {
                originalFolderUri = (await SafUtil().mkdirp(parentUri, originalSubfolder.split('/'))).uri;
              } else {
                originalFolderUri = parentUri;
              }
            }

            bool restored = false;
            try {
              await SafUtil().moveTo(currentDocUri, false, currentFolderUri, originalFolderUri);
              restored = true;
            } catch (_) {
              try {
                await SafUtil().copyTo(currentDocUri, false, originalFolderUri);
                await SafUtil().delete(currentDocUri, false);
                restored = true;
              } catch (e) {
                debugPrint('SAF Error: exact undo move copy+delete failed for $currentDocUri: $e');
              }
            }

            if (restored) restoredCount++;
          } catch (e) {
            debugPrint('SAF Error: undo single record failed: $e');
          }
        }
        return restoredCount > 0 || records.isEmpty;
      }

      for (final fileUri in files) {
        final originalName = Uri.decodeFull(fileUri).split('/').last.split('%2F').last;

        // If the file was moved to ROOT, it now resides in parentUri and needs to be moved back to its original subfolder.
        // If the file was moved to a folder, it now resides in that folder and needs to be moved back to parentUri.
        String sourceFolderUri;
        String destFolderUri;

        if (isMovingToRoot) {
          sourceFolderUri = parentUri;
          final originalFolder = _extractSubfolderFromUri(parentUri, fileUri);
          if (originalFolder == null || originalFolder.isEmpty) continue;
          destFolderUri = (await SafUtil().mkdirp(parentUri, originalFolder.split('/'))).uri;
        } else {
          sourceFolderUri = (await SafUtil().mkdirp(parentUri, folderName.split('/'))).uri;
          destFolderUri = parentUri;
        }

        // Query source folder for the file
        List<dynamic> sourceContents = [];
        try {
          sourceContents = await SafUtil().list(sourceFolderUri);
        } catch (e) {
          debugPrint('SAF Error: list sourceFolderUri failed during undo: $e');
        }

        // Query destination folder for collision checking
        Set<String> destExistingNames = {};
        try {
          final destContents = await SafUtil().list(destFolderUri);
          destExistingNames = destContents.map((f) => f.name.toLowerCase()).toSet();
        } catch (_) {}

        // Find the actual existing file in source folder
        dynamic matchingDoc;
        for (final doc in sourceContents) {
          if (!doc.isDir && doc.name.toLowerCase() == originalName.toLowerCase()) {
            matchingDoc = doc;
            break;
          }
        }
        if (matchingDoc == null) {
          final dotIdx = originalName.lastIndexOf('.');
          final baseName = dotIdx != -1 ? originalName.substring(0, dotIdx) : originalName;
          final ext = dotIdx != -1 ? originalName.substring(dotIdx) : '';
          for (final doc in sourceContents) {
            if (!doc.isDir &&
                doc.name.toLowerCase().startsWith(baseName.toLowerCase()) &&
                doc.name.toLowerCase().endsWith(ext.toLowerCase())) {
              matchingDoc = doc;
              break;
            }
          }
        }

        final docUri = matchingDoc?.uri ?? fileUri;
        String effectiveFileUri = docUri;
        try {
          final uniqueName = _generateUniqueName(destExistingNames, matchingDoc?.name ?? originalName);
          destExistingNames.add(uniqueName.toLowerCase());
          if (uniqueName != (matchingDoc?.name ?? originalName)) {
            final renamedDoc = await SafUtil().rename(docUri, false, uniqueName);
            effectiveFileUri = renamedDoc.uri;
          }
        } catch (_) {}

        bool restored = false;
        try {
          await SafUtil().moveTo(effectiveFileUri, false, sourceFolderUri, destFolderUri);
          restored = true;
        } catch (_) {
          restored = false;
        }

        if (!restored) {
          try {
            await SafUtil().copyTo(effectiveFileUri, false, destFolderUri);
            await SafUtil().delete(effectiveFileUri, false);
            restored = true;
          } catch (e) {
            debugPrint('SAF Error: undo move copy+delete failed for $effectiveFileUri: $e');
          }
        }

        if (restored) restoredCount++;
      }
      return restoredCount > 0 || files.isEmpty;
    } catch (e) {
      debugPrint('SAF Error: undoMoveFiles failed: $e');
      return false;
    }
  }

  static String? _extractSubfolderFromUri(String rootPath, String filePath) {
    if (filePath.isEmpty) return null;
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

  static String _extractCleanFolderName(String uri) {
    if (uri.isEmpty) return 'Screenshots';
    try {
      final decoded = Uri.decodeFull(uri).split('?').first;
      final lastSlash = decoded.lastIndexOf('/');
      final lastColon = decoded.lastIndexOf(':');
      String name = decoded;
      if (lastSlash != -1 || lastColon != -1) {
        final splitPoint = lastColon > lastSlash ? lastColon : lastSlash;
        name = decoded.substring(splitPoint + 1);
      }
      name = name.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
      if (name.isNotEmpty && name != 'tree' && name != 'document') {
        return name;
      }
    } catch (_) {}
    return 'Screenshots';
  }

  static String _extractFileFolder(String fileUri, String defaultParentUri) {
    try {
      final decoded = Uri.decodeFull(fileUri).split('?').first;
      final parts = decoded.split('/');
      if (parts.length >= 2) {
        String parentPart = parts[parts.length - 2];
        if (parentPart.contains(':')) {
          parentPart = parentPart.split(':').last;
        }
        parentPart = parentPart.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
        if (parentPart.isNotEmpty && parentPart != 'document' && parentPart != 'tree') {
          return parentPart;
        }
      }
    } catch (_) {}
    return _extractCleanFolderName(defaultParentUri);
  }

  static String _extractCleanFileName(String fileUri) {
    try {
      final decoded = Uri.decodeFull(fileUri).split('?').first;
      final lastSlash = decoded.lastIndexOf('/');
      final lastColon = decoded.lastIndexOf(':');
      String name = decoded;
      if (lastSlash != -1 || lastColon != -1) {
        final splitPoint = lastColon > lastSlash ? lastColon : lastSlash;
        name = decoded.substring(splitPoint + 1);
      }
      name = name.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return 'image.png';
  }

  static String _generateUniqueBinFileName(Directory dir, String originalName) {
    final lastDot = originalName.lastIndexOf('.');
    final baseName = lastDot != -1 ? originalName.substring(0, lastDot) : originalName;
    final ext = lastDot != -1 ? originalName.substring(lastDot) : '';

    String candidate = '$originalName.sgbin';
    int counter = 1;
    while (File('${dir.path}/$candidate').existsSync()) {
      candidate = '$baseName ($counter)$ext.sgbin';
      counter++;
    }
    return candidate;
  }

  static Future<Directory> _getAndroidBinDir(String folderName) async {
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

    final folderClean = folderName.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
    final effectiveFolder = folderClean.isEmpty ? 'Screenshots' : folderClean;
    final targetFolder = Directory('${baseDir.path}/$effectiveFolder');
    if (!await targetFolder.exists()) {
      await targetFolder.create(recursive: true);
    }
    return targetFolder;
  }



  static Future<bool> moveToBin(String parentUri, List<String> files) async {
    try {
      bool anySuccess = false;
      for (final fileUri in files) {
        try {
          final originalName = _extractCleanFileName(fileUri);
          final folderName = _extractFileFolder(fileUri, parentUri);
          final parentBreadcrumb = _extractCleanFolderName(parentUri);
          final targetBinDir = await _getAndroidBinDir(folderName);
          final binFileName = _generateUniqueBinFileName(targetBinDir, originalName);

          final bytes = await _safStream.readFileBytes(fileUri);
          if (bytes.isNotEmpty) {
            final altered = BinService.alterBytesV2(
              originalBytes: bytes,
              originalName: originalName,
              folderName: folderName,
              parentBreadcrumb: parentBreadcrumb,
              originUri: fileUri,
            );
            final destFile = File('${targetBinDir.path}/$binFileName');
            await destFile.writeAsBytes(altered, flush: true);

            // Verify the encrypted bin file was safely written to disk before deleting source
            if (await destFile.exists() && (await destFile.length()) >= bytes.length) {
              await SafUtil().delete(fileUri, false);
              anySuccess = true;
            } else {
              debugPrint('SAF Warning: Dest bin file verification failed for $binFileName. Preserving original file $fileUri');
            }
          } else {
            debugPrint('SAF Warning: readFileBytes returned empty bytes for $fileUri. Preserving original file.');
          }
        } catch (e) {
          debugPrint('SAF Error: moveToBin failed for $fileUri: $e');
        }
      }
      return anySuccess || files.isEmpty;
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

  static Future<FolderNode?> getFolderTree(String rootUri, {int maxDepth = 3}) async {
    try {
      Future<FolderNode> scanNode(String currentUri, String currentName, String relPath, int depth) async {
        final contents = await SafUtil().list(currentUri);
        int directCount = 0;
        final List<FolderNode> children = [];

        for (final item in contents) {
          if (item.isDir) {
            if (depth < maxDepth) {
              final childRel = relPath.isEmpty ? item.name : '$relPath/${item.name}';
              final childNode = await scanNode(item.uri, item.name, childRel, depth + 1);
              children.add(childNode);
            }
          } else {
            final lower = item.name.toLowerCase();
            if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
              directCount++;
            }
          }
        }

        children.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        int total = directCount;
        for (final c in children) {
          total += c.totalImageCount;
        }

        return FolderNode(
          name: currentName,
          path: currentUri,
          relPath: relPath,
          children: children,
          directImageCount: directCount,
          totalImageCount: total,
        );
      }

      final rootCleanName = _extractCleanFolderName(rootUri);
      return await scanNode(rootUri, rootCleanName, '', 0);
    } catch (e) {
      debugPrint('SAF Error: getFolderTree failed: $e');
      return null;
    }
  }

  static Future<bool> createNestedFolder(String parentUri, String folderName) async {
    try {
      final segments = folderName.split('/').where((s) => s.trim().isNotEmpty).toList();
      await SafUtil().mkdirp(parentUri, segments);
      return true;
    } catch (e) {
      debugPrint('SAF Error: createNestedFolder failed: $e');
      return false;
    }
  }

  static Future<bool> renameFolderNode(String currentUri, String newName) async {
    try {
      await SafUtil().rename(currentUri, true, newName);
      return true;
    } catch (e) {
      debugPrint('SAF Error: renameFolderNode failed: $e');
      return false;
    }
  }

  static Future<bool> deleteFolderNode(String folderUri) async {
    try {
      await SafUtil().delete(folderUri, true);
      return true;
    } catch (e) {
      debugPrint('SAF Error: deleteFolderNode failed: $e');
      return false;
    }
  }
}

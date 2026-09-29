import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';

class BinFolderInfo {
  final String name;
  final String path;
  final int itemCount;
  final int totalBytes;

  const BinFolderInfo({
    required this.name,
    required this.path,
    required this.itemCount,
    required this.totalBytes,
  });

  String get formattedSize {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class BinFileInfo {
  final String path;
  final String originalName;
  final String folderName;
  final int sizeBytes;
  final DateTime deletedDate;
  final int daysRemaining;

  const BinFileInfo({
    required this.path,
    required this.originalName,
    required this.folderName,
    required this.sizeBytes,
    required this.deletedDate,
    required this.daysRemaining,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedDeletedDate {
    final y = deletedDate.year;
    final m = deletedDate.month.toString().padLeft(2, '0');
    final d = deletedDate.day.toString().padLeft(2, '0');
    final h = deletedDate.hour.toString().padLeft(2, '0');
    final min = deletedDate.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class BinService {
  static const List<int> _magicHeader = [0x53, 0x47, 0x42, 0x49, 0x4E, 0x01, 0xAA, 0x55]; // SGBIN\x01\xAA\x55
  static const int _retentionDays = 30;

  Future<Directory> getBinRootDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Bin is not supported on web.');
    }

    Directory? baseDir;
    if (Platform.isAndroid) {
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
    } else {
      final appSupport = await getApplicationSupportDirectory();
      baseDir = Directory(p.join(appSupport.path, '.bin'));
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final nomedia = File(p.join(baseDir.path, '.nomedia'));
    if (!await nomedia.exists()) {
      try {
        await nomedia.create();
      } catch (_) {}
    }

    return baseDir;
  }

  static Uint8List decryptBytes(Uint8List encrypted) {
    if (encrypted.length < _magicHeader.length) return encrypted;

    bool matches = true;
    for (int i = 0; i < _magicHeader.length; i++) {
      if (encrypted[i] != _magicHeader[i]) {
        matches = false;
        break;
      }
    }

    if (!matches) {
      return encrypted;
    }

    final originalLen = encrypted.length - _magicHeader.length;
    final decrypted = Uint8List(originalLen);
    decrypted.setRange(0, originalLen, encrypted.sublist(_magicHeader.length));

    final maskLen = (originalLen < 128) ? originalLen : 128;
    for (int i = 0; i < maskLen; i++) {
      decrypted[i] ^= 0xAA;
    }

    return decrypted;
  }

  Future<Uint8List?> readDecryptedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return decryptBytes(bytes);
    } catch (e) {
      debugPrint('BinService: Error reading decrypted file: $e');
      return null;
    }
  }

  Future<List<BinFolderInfo>> listFolders() async {
    try {
      final root = await getBinRootDirectory();
      final entities = await root.list().toList();
      final List<BinFolderInfo> folders = [];

      for (final entity in entities) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);
          if (dirName.startsWith('.')) continue;

          int count = 0;
          int totalSize = 0;

          try {
            final files = await entity.list().toList();
            for (final f in files) {
              if (f is File && !p.basename(f.path).startsWith('.')) {
                count++;
                try {
                  totalSize += await f.length();
                } catch (_) {}
              }
            }
          } catch (_) {}

          folders.add(BinFolderInfo(
            name: dirName,
            path: entity.path,
            itemCount: count,
            totalBytes: totalSize,
          ));
        }
      }

      folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return folders;
    } catch (e) {
      debugPrint('BinService: listFolders failed: $e');
      return [];
    }
  }

  Future<int> getTotalBinItemCount() async {
    try {
      final folders = await listFolders();
      int total = 0;
      for (final f in folders) {
        total += f.itemCount;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<List<BinFileInfo>> listFiles(String folderName) async {
    try {
      final root = await getBinRootDirectory();
      final folderDir = Directory(p.join(root.path, folderName));
      if (!await folderDir.exists()) return [];

      final entities = await folderDir.list().toList();
      final List<BinFileInfo> result = [];
      final now = DateTime.now();

      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (fileName.startsWith('.')) continue;

          String originalName = fileName;
          if (originalName.toLowerCase().endsWith('.sgbin')) {
            originalName = originalName.substring(0, originalName.length - 6);
          }

          int size = 0;
          DateTime deletedDate = now;
          try {
            final stat = await entity.stat();
            size = stat.size;
            deletedDate = stat.modified;
          } catch (_) {}

          final daysPassed = now.difference(deletedDate).inDays;
          final daysRemaining = (_retentionDays - daysPassed).clamp(0, _retentionDays);

          result.add(BinFileInfo(
            path: entity.path,
            originalName: originalName,
            folderName: folderName,
            sizeBytes: size,
            deletedDate: deletedDate,
            daysRemaining: daysRemaining,
          ));
        }
      }

      result.sort((a, b) => b.deletedDate.compareTo(a.deletedDate));
      return result;
    } catch (e) {
      debugPrint('BinService: listFiles failed: $e');
      return [];
    }
  }

  Future<bool> deleteBinFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      debugPrint('BinService: deleteBinFile failed: $e');
      return false;
    }
  }

  Future<int> deleteMultipleFiles(List<String> filePaths) async {
    int count = 0;
    for (final path in filePaths) {
      final ok = await deleteBinFile(path);
      if (ok) count++;
    }
    return count;
  }

  Future<bool> emptyFolder(String folderName) async {
    try {
      final root = await getBinRootDirectory();
      final folderDir = Directory(p.join(root.path, folderName));
      if (await folderDir.exists()) {
        await folderDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint('BinService: emptyFolder failed: $e');
      return false;
    }
  }

  Future<bool> emptyFullBin() async {
    try {
      final root = await getBinRootDirectory();
      if (await root.exists()) {
        final entities = await root.list().toList();
        for (final entity in entities) {
          final name = p.basename(entity.path);
          if (name == '.nomedia') continue;
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else if (entity is File) {
            await entity.delete();
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('BinService: emptyFullBin failed: $e');
      return false;
    }
  }

  String _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<bool> restoreFile(String binFilePath, {String? targetDirectory}) async {
    try {
      final file = File(binFilePath);
      if (!await file.exists()) return false;

      final encryptedBytes = await file.readAsBytes();
      final decryptedBytes = decryptBytes(encryptedBytes);

      final fileName = p.basename(binFilePath);
      String originalName = fileName;
      if (originalName.toLowerCase().endsWith('.sgbin')) {
        originalName = originalName.substring(0, originalName.length - 6);
      }

      if (targetDirectory != null && targetDirectory.isNotEmpty) {
        if (targetDirectory.startsWith('content://')) {
          // Write back using SAF Stream
          final mime = _getMimeType(originalName);
          await SafStream().writeFileBytes(targetDirectory, originalName, mime, decryptedBytes, overwrite: false);
          await file.delete();
          return true;
        } else {
          final targetDir = Directory(targetDirectory);
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          final destFile = File(p.join(targetDir.path, originalName));
          await destFile.writeAsBytes(decryptedBytes, flush: true);
          await file.delete();
          return true;
        }
      } else {
        // Default restore location on Android: Pictures/Restored or DCIM
        if (Platform.isAndroid) {
          Directory? destDir;
          try {
            final extDirs = await getExternalStorageDirectories(type: StorageDirectory.pictures);
            if (extDirs != null && extDirs.isNotEmpty) {
              final path = extDirs.first.path;
              final parts = path.split('/Android/');
              if (parts.length > 1) {
                final rootStorage = parts.first;
                destDir = Directory('$rootStorage/Pictures/Restored');
              }
            }
          } catch (_) {}
          destDir ??= Directory('/storage/emulated/0/Pictures/Restored');
          if (!await destDir.exists()) {
            await destDir.create(recursive: true);
          }
          final destFile = File(p.join(destDir.path, originalName));
          await destFile.writeAsBytes(decryptedBytes, flush: true);
          await file.delete();
          return true;
        } else {
          final picDir = await getApplicationDocumentsDirectory();
          final destFile = File(p.join(picDir.path, originalName));
          await destFile.writeAsBytes(decryptedBytes, flush: true);
          await file.delete();
          return true;
        }
      }
    } catch (e) {
      debugPrint('BinService: restoreFile failed: $e');
      return false;
    }
  }

  Future<int> restoreMultipleFiles(List<String> binFilePaths, {String? targetDirectory}) async {
    int restored = 0;
    for (final path in binFilePaths) {
      final success = await restoreFile(path, targetDirectory: targetDirectory);
      if (success) restored++;
    }
    return restored;
  }

  /// Performs lightweight background cleanup of files older than 30 days.
  /// Checks DB for `last_bin_cleanup_check`. If within 24h, stops immediately.
  /// If > 24h, deletes expired files in all folders, clears empty folders, and updates timestamp.
  Future<int> cleanOldBinFiles({required dynamic storage}) async {
    if (kIsWeb) return 0;

    try {
      // 1. Check last check timestamp in DB
      final lastCheckRaw = await storage.read('settings', 'last_bin_cleanup_check');
      if (lastCheckRaw != null) {
        DateTime? lastCheck;
        if (lastCheckRaw is int) {
          lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckRaw);
        } else if (lastCheckRaw is String) {
          lastCheck = DateTime.tryParse(lastCheckRaw);
        }

        if (lastCheck != null) {
          final diff = DateTime.now().difference(lastCheck);
          // If within 24 hours, STOP immediately (0 disk I/O)
          if (diff.inHours < 24 && !diff.isNegative) {
            debugPrint('BinService: Periodic cleanup skipped (last checked ${diff.inHours}h ago < 24h)');
            return 0;
          }
        }
      }

      debugPrint('BinService: Running 24h periodic bin auto-cleanup check...');
      final root = await getBinRootDirectory();
      if (!await root.exists()) {
        await storage.write('settings', 'last_bin_cleanup_check', DateTime.now().millisecondsSinceEpoch);
        return 0;
      }

      final now = DateTime.now();
      int deletedCount = 0;
      final entities = await root.list().toList();

      for (final entity in entities) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);
          if (dirName.startsWith('.')) continue;

          final files = await entity.list().toList();
          int remainingInFolder = 0;

          for (final f in files) {
            if (f is File && !p.basename(f.path).startsWith('.')) {
              try {
                final stat = await f.stat();
                final ageInDays = now.difference(stat.modified).inDays;
                if (ageInDays >= _retentionDays) {
                  await f.delete();
                  deletedCount++;
                } else {
                  remainingInFolder++;
                }
              } catch (_) {
                remainingInFolder++;
              }
            }
          }

          // If folder became empty after deleting expired files, delete the empty directory
          if (remainingInFolder == 0) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }

      // 2. Save new timestamp in DB
      await storage.write('settings', 'last_bin_cleanup_check', DateTime.now().millisecondsSinceEpoch);
      debugPrint('BinService: Periodic cleanup finished. Purged $deletedCount expired items.');
      return deletedCount;
    } catch (e) {
      debugPrint('BinService: cleanOldBinFiles error: $e');
      return 0;
    }
  }
}

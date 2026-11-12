import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import '../core/locator.dart';
import '../viewmodels/app_view_model.dart';

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

class BinFileMetadata {
  final String originalName;
  final String folderName;
  final String? parentBreadcrumb;
  final String? originUri;
  final String? originPath;
  final DateTime deletedAt;
  final int sizeBytes;

  const BinFileMetadata({
    required this.originalName,
    required this.folderName,
    this.parentBreadcrumb,
    this.originUri,
    this.originPath,
    required this.deletedAt,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'origName': originalName,
        'folder': folderName,
        if (parentBreadcrumb != null) 'breadcrumb': parentBreadcrumb,
        if (originUri != null) 'originUri': originUri,
        if (originPath != null) 'originPath': originPath,
        'deletedAt': deletedAt.millisecondsSinceEpoch,
        'size': sizeBytes,
      };

  factory BinFileMetadata.fromJson(Map<String, dynamic> json) => BinFileMetadata(
        originalName: json['origName'] as String? ?? 'image.png',
        folderName: json['folder'] as String? ?? 'Screenshots',
        parentBreadcrumb: json['breadcrumb'] as String?,
        originUri: json['originUri'] as String?,
        originPath: json['originPath'] as String?,
        deletedAt: json['deletedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['deletedAt'] as int)
            : DateTime.now(),
        sizeBytes: json['size'] as int? ?? 0,
      );
}

class BinFileInfo {
  final String path;
  final String originalName;
  final String folderName;
  final String? parentBreadcrumb;
  final String? originUri;
  final String? originPath;
  final int sizeBytes;
  final DateTime deletedDate;
  final int daysRemaining;

  const BinFileInfo({
    required this.path,
    required this.originalName,
    required this.folderName,
    this.parentBreadcrumb,
    this.originUri,
    this.originPath,
    required this.sizeBytes,
    required this.deletedDate,
    required this.daysRemaining,
  });

  String get displayName {
    if (parentBreadcrumb != null &&
        parentBreadcrumb!.isNotEmpty &&
        parentBreadcrumb != 'Screenshots' &&
        parentBreadcrumb != folderName) {
      return '$folderName ($parentBreadcrumb)';
    }
    return folderName;
  }

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
  static const List<int> _magicHeaderV1 = [0x53, 0x47, 0x42, 0x49, 0x4E, 0x01, 0xAA, 0x55]; // SGBIN\x01\xAA\x55
  static const List<int> _magicHeaderV2 = [0x53, 0x47, 0x42, 0x49, 0x4E, 0x02]; // SGBIN\x02
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

  /// Encrypts raw bytes with .sgbin v2 format including self-describing metadata
  static Uint8List alterBytesV2({
    required Uint8List originalBytes,
    required String originalName,
    required String folderName,
    String? parentBreadcrumb,
    String? originUri,
    String? originPath,
    DateTime? deletedAt,
  }) {
    final meta = BinFileMetadata(
      originalName: originalName,
      folderName: folderName,
      parentBreadcrumb: parentBreadcrumb,
      originUri: originUri,
      originPath: originPath,
      deletedAt: deletedAt ?? DateTime.now(),
      sizeBytes: originalBytes.length,
    );

    final jsonBytes = utf8.encode(jsonEncode(meta.toJson()));
    final metaLen = jsonBytes.length;

    // Header: 6 bytes magic (SGBIN\x02) + 4 bytes big endian length
    final header = Uint8List(10 + metaLen);
    header.setRange(0, 6, _magicHeaderV2);
    header[6] = (metaLen >> 24) & 0xFF;
    header[7] = (metaLen >> 16) & 0xFF;
    header[8] = (metaLen >> 8) & 0xFF;
    header[9] = metaLen & 0xFF;
    header.setRange(10, 10 + metaLen, jsonBytes);

    final totalLen = header.length + originalBytes.length;
    final result = Uint8List(totalLen);
    result.setRange(0, header.length, header);
    result.setRange(header.length, totalLen, originalBytes);

    // Apply fast XOR mask on first 128 bytes of image payload
    final maskLen = (originalBytes.length < 128) ? originalBytes.length : 128;
    for (int i = 0; i < maskLen; i++) {
      result[header.length + i] ^= 0xAA;
    }

    return result;
  }

  /// Decrypts bytes supporting both v1 (SGBIN\x01\xAA\x55) and v2 (SGBIN\x02)
  static Uint8List decryptBytes(Uint8List encrypted) {
    if (encrypted.length < 6) return encrypted;

    // Check V2 magic: SGBIN\x02
    if (encrypted[0] == 0x53 &&
        encrypted[1] == 0x47 &&
        encrypted[2] == 0x42 &&
        encrypted[3] == 0x49 &&
        encrypted[4] == 0x4E &&
        encrypted[5] == 0x02) {
      if (encrypted.length < 10) return encrypted;
      final metaLen = (encrypted[6] << 24) |
          (encrypted[7] << 16) |
          (encrypted[8] << 8) |
          encrypted[9];
      final payloadOffset = 10 + metaLen;
      if (encrypted.length < payloadOffset) return encrypted;

      final originalLen = encrypted.length - payloadOffset;
      final decrypted = Uint8List(originalLen);
      decrypted.setRange(0, originalLen, encrypted.sublist(payloadOffset));

      final maskLen = (originalLen < 128) ? originalLen : 128;
      for (int i = 0; i < maskLen; i++) {
        decrypted[i] ^= 0xAA;
      }
      return decrypted;
    }

    // Check V1 magic: SGBIN\x01\xAA\x55
    if (encrypted.length >= _magicHeaderV1.length &&
        encrypted[0] == _magicHeaderV1[0] &&
        encrypted[1] == _magicHeaderV1[1] &&
        encrypted[2] == _magicHeaderV1[2] &&
        encrypted[3] == _magicHeaderV1[3] &&
        encrypted[4] == _magicHeaderV1[4] &&
        encrypted[5] == _magicHeaderV1[5] &&
        encrypted[6] == _magicHeaderV1[6] &&
        encrypted[7] == _magicHeaderV1[7]) {
      final originalLen = encrypted.length - 8;
      final decrypted = Uint8List(originalLen);
      decrypted.setRange(0, originalLen, encrypted.sublist(8));

      final maskLen = (originalLen < 128) ? originalLen : 128;
      for (int i = 0; i < maskLen; i++) {
        decrypted[i] ^= 0xAA;
      }
      return decrypted;
    }

    return encrypted;
  }

  /// Fast metadata reader reading only the header bytes (<512 bytes)
  Future<BinFileInfo?> readMetadata(File file, {String? defaultFolderName}) async {
    try {
      if (!await file.exists()) return null;
      final filePath = file.path;
      final folderName = defaultFolderName ?? p.basename(p.dirname(filePath));
      final stat = await file.stat();

      // Read first 1024 bytes for fast header extraction
      final raf = await file.open(mode: FileMode.read);
      final headerBytes = await raf.read(1024);
      await raf.close();

      final now = DateTime.now();

      // Check for V2 header: SGBIN\x02
      if (headerBytes.length >= 10 &&
          headerBytes[0] == 0x53 &&
          headerBytes[1] == 0x47 &&
          headerBytes[2] == 0x42 &&
          headerBytes[3] == 0x49 &&
          headerBytes[4] == 0x4E &&
          headerBytes[5] == 0x02) {
        final metaLen = (headerBytes[6] << 24) |
            (headerBytes[7] << 16) |
            (headerBytes[8] << 8) |
            headerBytes[9];
        if (headerBytes.length >= 10 + metaLen) {
          final jsonStr = utf8.decode(headerBytes.sublist(10, 10 + metaLen));
          final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
          final meta = BinFileMetadata.fromJson(jsonMap);

          final daysPassed = now.difference(meta.deletedAt).inDays;
          final daysRemaining = (_retentionDays - daysPassed).clamp(0, _retentionDays);

          return BinFileInfo(
            path: filePath,
            originalName: meta.originalName,
            folderName: meta.folderName.isNotEmpty ? meta.folderName : folderName,
            parentBreadcrumb: meta.parentBreadcrumb,
            originUri: meta.originUri,
            originPath: meta.originPath,
            sizeBytes: meta.sizeBytes > 0 ? meta.sizeBytes : stat.size,
            deletedDate: meta.deletedAt,
            daysRemaining: daysRemaining,
          );
        }
      }

      // Fallback for V1 format or legacy files
      String originalName = p.basename(filePath);
      if (originalName.toLowerCase().endsWith('.sgbin')) {
        originalName = originalName.substring(0, originalName.length - 6);
      }

      final daysPassed = now.difference(stat.modified).inDays;
      final daysRemaining = (_retentionDays - daysPassed).clamp(0, _retentionDays);

      return BinFileInfo(
        path: filePath,
        originalName: originalName,
        folderName: folderName,
        sizeBytes: stat.size,
        deletedDate: stat.modified,
        daysRemaining: daysRemaining,
      );
    } catch (e) {
      debugPrint('BinService: readMetadata failed for ${file.path}: $e');
      return null;
    }
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
      final all = await listAllFiles();
      return all.length;
    } catch (_) {
      return 0;
    }
  }

  /// Lists all files in the bin across all folders, sorted newest first
  Future<List<BinFileInfo>> listAllFiles() async {
    try {
      final root = await getBinRootDirectory();
      if (!await root.exists()) return [];

      final entities = await root.list(recursive: true).toList();
      final List<BinFileInfo> result = [];

      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (fileName.startsWith('.')) continue;

          final info = await readMetadata(entity);
          if (info != null) {
            result.add(info);
          }
        }
      }

      result.sort((a, b) => b.deletedDate.compareTo(a.deletedDate));
      return result;
    } catch (e) {
      debugPrint('BinService: listAllFiles failed: $e');
      return [];
    }
  }

  Future<List<BinFileInfo>> listFiles(String folderName) async {
    try {
      final root = await getBinRootDirectory();
      final folderDir = Directory(p.join(root.path, folderName));
      if (!await folderDir.exists()) return [];

      final entities = await folderDir.list().toList();
      final List<BinFileInfo> result = [];

      for (final entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (fileName.startsWith('.')) continue;

          final info = await readMetadata(entity, defaultFolderName: folderName);
          if (info != null) {
            result.add(info);
          }
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

      final metadata = await readMetadata(file);
      final encryptedBytes = await file.readAsBytes();
      final decryptedBytes = decryptBytes(encryptedBytes);

      final originalName = metadata?.originalName ??
          (p.basename(binFilePath).toLowerCase().endsWith('.sgbin')
              ? p.basename(binFilePath).substring(0, p.basename(binFilePath).length - 6)
              : p.basename(binFilePath));

      final folderName = metadata?.folderName ?? p.basename(p.dirname(binFilePath));
      final originParentBreadcrumb = metadata?.parentBreadcrumb;

      if (targetDirectory == null || targetDirectory.isEmpty) {
        if (locator.isRegistered<AppViewModel>()) {
          final appVm = locator<AppViewModel>();
          targetDirectory = appVm.screenshotDir ?? appVm.permanentScreenshotDir;
        }
      }

      if (targetDirectory != null && targetDirectory.isNotEmpty) {
        if (targetDirectory.startsWith('content://')) {
          // Write back using SAF Stream
          final mime = _getMimeType(originalName);
          final newFile = await SafStream().writeFileBytes(
            targetDirectory,
            originalName,
            mime,
            decryptedBytes,
            overwrite: false,
          );

          if (folderName.isNotEmpty &&
              folderName != 'Screenshots' &&
              folderName != 'ROOT' &&
              folderName != originParentBreadcrumb) {
            try {
              final subDoc = await SafUtil().mkdirp(targetDirectory, folderName.split('/'));
              final newFileUri = newFile.uri.toString();
              try {
                await SafUtil().moveTo(newFileUri, false, targetDirectory, subDoc.uri);
              } catch (_) {
                try {
                  await SafUtil().copyTo(newFileUri, false, subDoc.uri);
                  await SafUtil().delete(newFileUri, false);
                } catch (_) {}
              }
            } catch (_) {}
          }

          await file.delete();
          return true;
        } else {
          try {
            final baseDir = Directory(targetDirectory);
            Directory destDir = baseDir;
            if (folderName.isNotEmpty &&
                folderName != 'Screenshots' &&
                folderName != 'ROOT' &&
                folderName != originParentBreadcrumb) {
              destDir = Directory(p.join(baseDir.path, folderName));
            }
            if (!await destDir.exists()) {
              await destDir.create(recursive: true);
            }
            final destFile = File(p.join(destDir.path, originalName));
            await destFile.writeAsBytes(decryptedBytes, flush: true);
            await file.delete();
            return true;
          } on FileSystemException catch (e) {
            debugPrint('BinService: File restore failed with FileSystemException: $e');
            return false;
          } catch (e) {
            debugPrint('BinService: File restore failed: $e');
            return false;
          }
        }
      } else {
        // Default restore location on Android: Pictures/Restored or origin path
        if (Platform.isAndroid) {
          try {
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
            if (folderName.isNotEmpty && folderName != 'Screenshots' && folderName != 'ROOT') {
              destDir = Directory(p.join(destDir.path, folderName));
            }
            if (!await destDir.exists()) {
              await destDir.create(recursive: true);
            }
            final destFile = File(p.join(destDir.path, originalName));
            await destFile.writeAsBytes(decryptedBytes, flush: true);
            await file.delete();
            return true;
          } on FileSystemException catch (e) {
            debugPrint('BinService: Android fallback direct File write failed with FileSystemException: $e');
            return false;
          } catch (e) {
            debugPrint('BinService: Android fallback direct File write failed: $e');
            return false;
          }
        } else {
          final picDir = await getApplicationDocumentsDirectory();
          Directory destDir = picDir;
          if (folderName.isNotEmpty && folderName != 'Screenshots' && folderName != 'ROOT') {
            destDir = Directory(p.join(picDir.path, folderName));
          }
          if (!await destDir.exists()) {
            await destDir.create(recursive: true);
          }
          final destFile = File(p.join(destDir.path, originalName));
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

  Future<int> restoreMultipleFiles(
    List<String> binFilePaths, {
    String? targetDirectory,
    void Function(int completed, int total)? onProgress,
  }) async {
    int restored = 0;
    for (int i = 0; i < binFilePaths.length; i++) {
      final success = await restoreFile(binFilePaths[i], targetDirectory: targetDirectory);
      if (success) restored++;
      onProgress?.call(i + 1, binFilePaths.length);
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

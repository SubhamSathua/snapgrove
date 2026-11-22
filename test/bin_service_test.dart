import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/services/bin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  group('BinService Encryption & Decryption', () {
    test('decryptBytes reverses XOR alteration with header', () {
      final originalData = Uint8List.fromList(List.generate(256, (i) => i % 256));
      
      // Simulate SafHelper._alterBytes
      final header = Uint8List.fromList([0x53, 0x47, 0x42, 0x49, 0x4E, 0x01, 0xAA, 0x55]);
      final altered = Uint8List(header.length + originalData.length);
      altered.setRange(0, header.length, header);
      altered.setRange(header.length, altered.length, originalData);
      const maskLen = 128;
      for (int i = 0; i < maskLen; i++) {
        altered[header.length + i] ^= 0xAA;
      }

      // Decrypt
      final decrypted = BinService.decryptBytes(altered);

      expect(decrypted.length, equals(originalData.length));
      expect(decrypted, equals(originalData));
    });

    test('decryptBytes handles unencrypted fallback gracefully', () {
      final normalBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = BinService.decryptBytes(normalBytes);
      expect(result, equals(normalBytes));
    });

    test('alterBytesV2 encodes metadata and decryptBytes recovers original payload', () {
      final originalData = Uint8List.fromList(List.generate(512, (i) => (i * 3) % 256));
      final encrypted = BinService.alterBytesV2(
        originalBytes: originalData,
        originalName: 'pic.png',
        folderName: 'Reddit',
        parentBreadcrumb: 'Pictures/Screenshots',
        originUri: 'content://tree/primary%3APictures%2FScreenshots/document/123',
      );

      // Verify V2 Magic
      expect(encrypted[0], equals(0x53));
      expect(encrypted[1], equals(0x47));
      expect(encrypted[2], equals(0x42));
      expect(encrypted[3], equals(0x49));
      expect(encrypted[4], equals(0x4E));
      expect(encrypted[5], equals(0x02));

      // Decrypt
      final decrypted = BinService.decryptBytes(encrypted);
      expect(decrypted, equals(originalData));
    });

    test('readMetadata extracts V2 metadata correctly even when metadata JSON > 1014 bytes', () async {
      final binService = BinService();
      final tempDir = await Directory.systemTemp.createTemp('sgbin_test_');
      try {
        final longOriginUri = 'content://com.android.externalstorage.documents/tree/primary%3A${'A' * 1200}';
        final encrypted = BinService.alterBytesV2(
          originalBytes: Uint8List.fromList([10, 20, 30, 40]),
          originalName: 'large_meta.png',
          folderName: 'LongFolder',
          parentBreadcrumb: 'Deep/Breadcrumb/Path',
          originUri: longOriginUri,
          deletedAt: DateTime(2026, 11, 20, 10, 0),
        );

        final testFile = File('${tempDir.path}/large_meta.png.sgbin');
        await testFile.writeAsBytes(encrypted);

        final info = await binService.readMetadata(testFile);
        expect(info, isNotNull);
        expect(info!.originalName, equals('large_meta.png'));
        expect(info.folderName, equals('LongFolder'));
        expect(info.parentBreadcrumb, equals('Deep/Breadcrumb/Path'));
        expect(info.originUri, equals(longOriginUri));
        expect(info.deletedDate, equals(DateTime(2026, 11, 20, 10, 0)));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('readMetadata handles truncated files (<10 bytes) with graceful fallback', () async {
      final binService = BinService();
      final tempDir = await Directory.systemTemp.createTemp('sgbin_truncated_');
      try {
        final testFile = File('${tempDir.path}/short.png.sgbin');
        await testFile.writeAsBytes([0x53, 0x47, 0x42]); // Only 3 bytes

        final info = await binService.readMetadata(testFile);
        expect(info, isNotNull);
        expect(info!.originalName, equals('short.png'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('readMetadata handles corrupted V2 payload with fallback', () async {
      final binService = BinService();
      final tempDir = await Directory.systemTemp.createTemp('sgbin_corrupted_');
      try {
        final testFile = File('${tempDir.path}/corrupt.png.sgbin');
        // Valid 10-byte header with length 4, but payload is invalid JSON
        final corruptedBytes = [
          0x53, 0x47, 0x42, 0x49, 0x4E, 0x02, // Magic
          0x00, 0x00, 0x00, 0x04,             // metaLen = 4
          0xFF, 0xFF, 0xFF, 0xFF              // Invalid UTF-8 JSON
        ];
        await testFile.writeAsBytes(corruptedBytes);

        final info = await binService.readMetadata(testFile);
        expect(info, isNotNull);
        expect(info!.originalName, equals('corrupt.png'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('BinFolderInfo formats bytes correctly', () {
      const folderInfo = BinFolderInfo(
        name: 'Screenshots',
        path: '/path/to/.bin/Screenshots',
        itemCount: 5,
        totalBytes: 2048 * 1024,
      );

      expect(folderInfo.formattedSize, equals('2.00 MB'));
      expect(folderInfo.itemCount, equals(5));
      expect(folderInfo.name, equals('Screenshots'));
    });

    test('BinFileInfo calculates metadata and formatting', () {
      final fileInfo = BinFileInfo(
        path: '/path/to/.bin/Screenshots/test.png.sgbin',
        originalName: 'test.png',
        folderName: 'Screenshots',
        sizeBytes: 1536,
        deletedDate: DateTime(2026, 9, 28, 14, 30),
        daysRemaining: 27,
      );

      expect(fileInfo.formattedSize, equals('1.5 KB'));
      expect(fileInfo.originalName, equals('test.png'));
      expect(fileInfo.daysRemaining, equals(27));
      expect(fileInfo.formattedDeletedDate, equals('2026-09-28 14:30'));
    });

    test('cleanOldBinFiles skips if checked within 24 hours', () async {
      final binService = BinService();
      final mockStorage = _MockMemoryStorage();
      // Set last check to 2 hours ago
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      await mockStorage.write('settings', 'last_bin_cleanup_check', twoHoursAgo.millisecondsSinceEpoch);

      final deleted = await binService.cleanOldBinFiles(storage: mockStorage);
      expect(deleted, equals(0));
      // Timestamp should remain unchanged
      final lastCheck = await mockStorage.read('settings', 'last_bin_cleanup_check');
      expect(lastCheck, equals(twoHoursAgo.millisecondsSinceEpoch));
    });

    test('cleanOldBinFiles runs and updates timestamp if checked > 24 hours ago', () async {
      final binService = BinService();
      final mockStorage = _MockMemoryStorage();
      // Set last check to 30 hours ago
      final thirtyHoursAgo = DateTime.now().subtract(const Duration(hours: 30));
      await mockStorage.write('settings', 'last_bin_cleanup_check', thirtyHoursAgo.millisecondsSinceEpoch);

      await binService.cleanOldBinFiles(storage: mockStorage);
      final newCheck = await mockStorage.read('settings', 'last_bin_cleanup_check') as int;
      expect(newCheck, isNotNull);
      expect(newCheck, greaterThan(thirtyHoursAgo.millisecondsSinceEpoch));
    });
  });
}

class _MockMemoryStorage {
  final Map<String, dynamic> _data = {};

  Future<void> write(String store, String key, dynamic value) async {
    _data['${store}_$key'] = value;
  }

  Future<dynamic> read(String store, String key) async {
    return _data['${store}_$key'];
  }
}

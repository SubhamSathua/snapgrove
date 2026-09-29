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

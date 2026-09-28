import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/services/bin_service.dart';

void main() {
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
  });
}

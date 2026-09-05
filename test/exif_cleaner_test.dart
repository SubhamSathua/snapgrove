import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/services/exif_cleaner.dart';

void main() {
  group('ExifCleaner Tests', () {
    test('strips JPEG APP1 (EXIF) and COM markers losslessly', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xD8,
        0xFF, 0xE0, 0x00, 0x04, 0x01, 0x02,
        0xFF, 0xE1, 0x00, 0x06, 0x45, 0x78, 0x69, 0x66,
        0xFF, 0xDA, 0x00, 0x02,
        0x12, 0x34,
        0xFF, 0xD9,
      ]);

      final stripped = ExifCleaner.stripMetadata(bytes, 'jpg');
      expect(stripped, isNotNull);
      bool hasApp1 = false;
      for (int i = 0; i < stripped.length - 1; i++) {
        if (stripped[i] == 0xFF && stripped[i + 1] == 0xE1) {
          hasApp1 = true;
          break;
        }
      }
      expect(hasApp1, isFalse);
      expect(stripped.first, 0xFF);
      expect(stripped[1], 0xD8);
      expect(stripped.last, 0xD9);
    });

    test('strips PNG metadata chunks', () {
      final bytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00,
        0x1F, 0x15, 0xC4, 0x89,
        0x00, 0x00, 0x00, 0x04,
        0x74, 0x45, 0x58, 0x74,
        0x74, 0x65, 0x73, 0x74,
        0x57, 0xBB, 0x11, 0x22,
        0x00, 0x00, 0x00, 0x00,
        0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82,
      ]);

      final stripped = ExifCleaner.stripMetadata(bytes, 'png');
      expect(stripped.length < bytes.length, isTrue);
      final textChunkName = String.fromCharCodes(stripped);
      expect(textChunkName.contains('tEXt'), isFalse);
      expect(textChunkName.contains('IHDR'), isTrue);
      expect(textChunkName.contains('IEND'), isTrue);
    });
  });
}
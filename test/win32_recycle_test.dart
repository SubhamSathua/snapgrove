import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/services/win32/win32_recycle_stub.dart'
    if (dart.library.io) 'package:snapgrove/services/win32/win32_recycle_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Win32 Recycle Bin Tests', () {
    test('win32MoveToRecycleBin returns false for empty file list', () async {
      final result = await win32MoveToRecycleBin([]);
      expect(result, isFalse);
    });

    test('win32MoveToRecycleBin returns false for nonexistent files without throwing', () async {
      final result = await win32MoveToRecycleBin(['C:\\non_existent_folder\\fake_file_12345.png']);
      expect(result, isFalse);
    });

    test('win32MoveToRecycleBin successfully recycles real file on Windows', () async {
      if (!Platform.isWindows) return;

      final tempDir = await Directory.systemTemp.createTemp('snapgrove_win32_test_');
      try {
        final testFile = File('${tempDir.path}\\recycle_me.png');
        await testFile.writeAsString('test screenshot content');
        expect(await testFile.exists(), isTrue);

        final result = await win32MoveToRecycleBin([testFile.path]);
        expect(result, isTrue);

        // File must no longer exist at original path because it was moved to Recycle Bin
        expect(await testFile.exists(), isFalse);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('win32MoveToRecycleBin successfully batch recycles multiple files', () async {
      if (!Platform.isWindows) return;

      final tempDir = await Directory.systemTemp.createTemp('snapgrove_win32_batch_');
      try {
        final f1 = File('${tempDir.path}\\batch1.png');
        final f2 = File('${tempDir.path}\\batch2.png');
        await f1.writeAsString('f1');
        await f2.writeAsString('f2');
        expect(await f1.exists(), isTrue);
        expect(await f2.exists(), isTrue);

        final result = await win32MoveToRecycleBin([f1.path, f2.path]);
        expect(result, isTrue);

        expect(await f1.exists(), isFalse);
        expect(await f2.exists(), isFalse);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

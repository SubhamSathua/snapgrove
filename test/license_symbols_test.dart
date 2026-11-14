import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/core/app_constants.dart';
import 'package:snapgrove/theme/snap_symbols.dart';
import 'package:snapgrove/theme/app_theme.dart';
import 'package:snapgrove/views/licenses_view.dart';

void main() {
  group('SnapSymbols Icon Constants Tests', () {
    test('All SnapSymbols use MaterialSymbolsRounded font family', () {
      const family = 'MaterialSymbolsRounded';

      expect(SnapSymbols.home.fontFamily, equals(family));
      expect(SnapSymbols.arrow_back.fontFamily, equals(family));
      expect(SnapSymbols.close.fontFamily, equals(family));
      expect(SnapSymbols.folder.fontFamily, equals(family));
      expect(SnapSymbols.delete.fontFamily, equals(family));
      expect(SnapSymbols.restore.fontFamily, equals(family));
      expect(SnapSymbols.search.fontFamily, equals(family));
      expect(SnapSymbols.settings.fontFamily, equals(family));
      expect(SnapSymbols.shield.fontFamily, equals(family));
      expect(SnapSymbols.blur_on.fontFamily, equals(family));
      expect(SnapSymbols.battery_saver.fontFamily, equals(family));
      expect(SnapSymbols.drive_file_rename_outline.fontFamily, equals(family));
    });

    test('SnapSymbols aliases are identical to canonical icons', () {
      expect(SnapSymbols.bin, equals(SnapSymbols.delete));
      expect(SnapSymbols.clear, equals(SnapSymbols.close));
      expect(SnapSymbols.restore_rounded, equals(SnapSymbols.restore));
      expect(SnapSymbols.folder_rounded, equals(SnapSymbols.folder));
      expect(SnapSymbols.folder_special_rounded, equals(SnapSymbols.folder_special));
    });
  });

  group('Consolidated License Assets Tests', () {
    test('assets/licenses directory contains all 3 font license files', () {
      final licensesDir = Directory('assets/licenses');
      expect(licensesDir.existsSync(), isTrue);

      final materialLicense = File('assets/licenses/LICENSE-MaterialSymbols.txt');
      expect(materialLicense.existsSync(), isTrue);
      expect(materialLicense.readAsStringSync().contains('Apache License'), isTrue);

      final loraLicense = File('assets/licenses/OFL-Lora.txt');
      expect(loraLicense.existsSync(), isTrue);
      expect(loraLicense.readAsStringSync().contains('SIL OPEN FONT LICENSE'), isTrue);

      final jbLicense = File('assets/licenses/OFL-JetBrains.txt');
      expect(jbLicense.existsSync(), isTrue);
      expect(jbLicense.readAsStringSync().contains('SIL OPEN FONT LICENSE'), isTrue);
    });

    test('Old font license paths in assets/fonts no longer exist', () {
      expect(File('assets/fonts/LICENSE-MaterialSymbols.txt').existsSync(), isFalse);
      expect(File('assets/fonts/OFL-Lora.txt').existsSync(), isFalse);
      expect(File('assets/fonts/OFL-JetBrains.txt').existsSync(), isFalse);
    });

    test('openSourcePackages includes Material Symbols, Lora, and JetBrains Mono', () {
      final names = AppConstants.openSourcePackages.map((p) => p['name']).toList();
      expect(names, contains('Material Symbols Rounded'));
      expect(names, contains('Lora Font'));
      expect(names, contains('JetBrains Mono Font'));
    });
  });

  group('LicensesView Widget Tests', () {
    testWidgets('Renders LicensesView and searches for font packages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [SnapgroveColors.light],
          ),
          home: const LicensesView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Source Licenses'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Search for Material Symbols
      await tester.enterText(find.byType(TextField), 'Material Symbols');
      await tester.pumpAndSettle();

      expect(find.text('Material Symbols Rounded'), findsOneWidget);

      // Clear search and search for Lora
      await tester.enterText(find.byType(TextField), 'Lora');
      await tester.pumpAndSettle();

      expect(find.text('Lora Font'), findsOneWidget);
    });
  });
}

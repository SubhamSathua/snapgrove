import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/views/debug/icons_debug_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IconsDebugView Tests', () {
    testWidgets('Renders PC 3-column layout at 1200x800', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: IconsDebugView(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify PC layout is active
      expect(find.byKey(const Key('icons_debug_pc_layout')), findsOneWidget);
      expect(find.byKey(const Key('icons_debug_mobile_layout')), findsNothing);

      // Verify left column controls
      expect(find.text('Axes Sliders & Presets'), findsOneWidget);
      expect(find.byKey(const Key('fill_slider')), findsOneWidget);
      expect(find.byKey(const Key('wght_slider')), findsOneWidget);
      expect(find.byKey(const Key('grad_slider')), findsOneWidget);
      expect(find.byKey(const Key('opsz_slider')), findsOneWidget);
      expect(find.byKey(const Key('font_size_slider')), findsOneWidget);

      // Verify center column spotlight and symbol count
      expect(find.byKey(const Key('spotlight_symbol_text')), findsOneWidget);
      expect(find.text('home'), findsWidgets);
      expect(find.text('Showing 139 of 139 symbols'), findsOneWidget);

      // Verify right column JSON preview and Flutter code snippet
      expect(find.text('Live JSON Configuration'), findsOneWidget);
      expect(find.text('Flutter Code Snippet'), findsOneWidget);
      expect(find.byKey(const Key('copy_json_btn')), findsOneWidget);
      expect(find.byKey(const Key('copy_code_btn')), findsOneWidget);
    });

    testWidgets('Renders Mobile layout at 400x800 with bottom sheets', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: IconsDebugView(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Mobile layout is active
      expect(find.byKey(const Key('icons_debug_mobile_layout')), findsOneWidget);
      expect(find.byKey(const Key('icons_debug_pc_layout')), findsNothing);

      // Verify mobile app bar buttons
      expect(find.byKey(const Key('mobile_controls_btn')), findsOneWidget);
      expect(find.byKey(const Key('mobile_json_btn')), findsOneWidget);

      // Open mobile controls bottom sheet
      await tester.tap(find.byKey(const Key('mobile_controls_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Axes Sliders & Presets'), findsOneWidget);
      expect(find.byKey(const Key('fill_slider')), findsOneWidget);

      // Close bottom sheet by tapping barrier at top
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();

      // Open mobile JSON bottom sheet
      await tester.tap(find.byKey(const Key('mobile_json_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Live JSON Configuration'), findsOneWidget);
      expect(find.text('Flutter Code Snippet'), findsOneWidget);

      // Close bottom sheet
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();
    });

    testWidgets('Search and category filtering work correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: IconsDebugView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Showing 139 of 139 symbols'), findsOneWidget);

      // Search for "cloud"
      await tester.enterText(find.byKey(const Key('search_input')), 'cloud');
      await tester.pumpAndSettle();

      // "cloud", "cloud_upload", "cloud_download", "cloud_done" = 4 symbols
      expect(find.text('Showing 4 of 139 symbols'), findsOneWidget);

      // Clear search
      await tester.enterText(find.byKey(const Key('search_input')), '');
      await tester.pumpAndSettle();
      expect(find.text('Showing 139 of 139 symbols'), findsOneWidget);

      // Filter by Navigation category
      await tester.tap(find.byKey(const Key('category_chip_Navigation')));
      await tester.pumpAndSettle();
      expect(find.text('Showing 18 of 139 symbols'), findsOneWidget);
    });

    testWidgets('Custom ligature tester adds and tests new symbol', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: IconsDebugView(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('custom_symbol_input')), 'brand_rocket');
      await tester.tap(find.byKey(const Key('add_custom_btn')));
      await tester.pumpAndSettle();

      // Spotlight should now show 'brand_rocket'
      final spotlightText = tester.widget<Text>(find.byKey(const Key('spotlight_symbol_text')));
      expect(spotlightText.data, equals('brand_rocket'));
    });

    testWidgets('Presets and sliders update axes and font variations', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: IconsDebugView(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially home with default axes (FILL 0.0, wght 400.0, GRAD 0.0, opsz 24.0)
      Text spotlight = tester.widget<Text>(find.byKey(const Key('spotlight_symbol_text')));
      List<FontVariation>? variations = spotlight.style?.fontVariations;
      expect(variations, isNotNull);
      expect(variations!.firstWhere((v) => v.axis == 'FILL').value, equals(0.0));
      expect(variations.firstWhere((v) => v.axis == 'wght').value, equals(400.0));
      expect(variations.firstWhere((v) => v.axis == 'GRAD').value, equals(0.0));
      expect(variations.firstWhere((v) => v.axis == 'opsz').value, equals(24.0));

      // Click FILL 1 preset
      await tester.tap(find.byKey(const Key('preset_fill_1')));
      await tester.pumpAndSettle();

      // Click wght 700 preset
      await tester.tap(find.byKey(const Key('preset_wght_700')));
      await tester.pumpAndSettle();

      // Click GRAD 200 preset
      await tester.tap(find.byKey(const Key('preset_grad_200')));
      await tester.pumpAndSettle();

      // Click opsz 48 preset
      await tester.tap(find.byKey(const Key('preset_opsz_48')));
      await tester.pumpAndSettle();

      // Verify updated variations
      spotlight = tester.widget<Text>(find.byKey(const Key('spotlight_symbol_text')));
      variations = spotlight.style?.fontVariations;
      expect(variations!.firstWhere((v) => v.axis == 'FILL').value, equals(1.0));
      expect(variations.firstWhere((v) => v.axis == 'wght').value, equals(700.0));
      expect(variations.firstWhere((v) => v.axis == 'GRAD').value, equals(200.0));
      expect(variations.firstWhere((v) => v.axis == 'opsz').value, equals(48.0));

      // Tap Reset All
      await tester.tap(find.byKey(const Key('reset_all_btn')));
      await tester.pumpAndSettle();

      // Verify reset back to defaults
      spotlight = tester.widget<Text>(find.byKey(const Key('spotlight_symbol_text')));
      variations = spotlight.style?.fontVariations;
      expect(variations!.firstWhere((v) => v.axis == 'FILL').value, equals(0.0));
      expect(variations.firstWhere((v) => v.axis == 'wght').value, equals(400.0));
      expect(variations.firstWhere((v) => v.axis == 'GRAD').value, equals(0.0));
      expect(variations.firstWhere((v) => v.axis == 'opsz').value, equals(24.0));
    });
  });
}

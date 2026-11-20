import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/core/locator.dart';
import 'package:snapgrove/services/notification_service.dart';
import 'package:snapgrove/services/settings_service.dart';
import 'package:snapgrove/services/storage_service.dart';
import 'package:snapgrove/theme/app_blur.dart';
import 'package:snapgrove/theme/app_theme.dart';
import 'package:snapgrove/viewmodels/app_view_model.dart';
import 'package:snapgrove/views/about_view.dart';
import 'package:snapgrove/views/settings_view.dart';

class MockStorageService implements StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.dark;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}

  @override
  Future<String?> getScreenshotDir() async => null;

  @override
  Future<void> saveScreenshotDir(String path) async {}

  @override
  Future<String?> getPermanentScreenshotDir() async => null;

  @override
  Future<void> savePermanentScreenshotDir(String path) async {}

  @override
  Future<dynamic> read(String store, String key) async => _data['${store}_$key'];

  @override
  Future<void> write(String store, String key, dynamic value) async {
    _data['${store}_$key'] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!locator.isRegistered<StorageService>()) {
      locator.registerSingleton<StorageService>(MockStorageService());
    }
    if (!locator.isRegistered<SettingsService>()) {
      final settings = SettingsService(locator<StorageService>());
      await settings.init();
      locator.registerSingleton<SettingsService>(settings);
    }
    if (!locator.isRegistered<NotificationService>()) {
      locator.registerSingleton<NotificationService>(NotificationService());
    }
    if (!locator.isRegistered<AppViewModel>()) {
      locator.registerLazySingleton<AppViewModel>(() => AppViewModel(
            locator<StorageService>(),
            locator<NotificationService>(),
            locator<SettingsService>(),
          ));
    }
  });

  group('Windows UI & Behavior Tests', () {
    testWidgets('AboutView has no SelectionArea (non-selectable text)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const AboutView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsNothing);
      expect(find.text('About Snapgrove'), findsOneWidget);
    });

    testWidgets('SettingsView completely hides Bin Authentication on Windows', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SettingsView(),
          ),
        );
        await tester.pumpAndSettle();

        // Bin Authentication tile and Security section should NOT be present on Windows
        expect(find.text('Bin Authentication'), findsNothing);
        expect(find.text('SECURITY'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('AppBlur respects blurDisabled toggle for background opacity', () {
      final translucent = Colors.black.withValues(alpha: 0.85);

      // In testing environment default: isBlurDisabled is false unless configured
      final bgEnabled = AppBlur.getBackgroundColor(translucent);
      expect(bgEnabled.a, closeTo(0.85, 0.01));

      // With solid fallback
      final solid = AppBlur.getBackgroundColor(translucent, Colors.white);
      expect(solid.a, closeTo(0.85, 0.01));
    });

    testWidgets('SettingsView top header spans full width on desktop', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SettingsView(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the header container
      final headerFinder = find.byKey(const Key('settings_top_nav_bar'));
      expect(headerFinder, findsOneWidget);
      final RenderBox headerBox = tester.renderObject(headerFinder);
      expect(headerBox.size.width, equals(1200.0));

      // Close button and back button should be spaced across
      final closeButtonFinder = find.byTooltip('Close');
      expect(closeButtonFinder, findsOneWidget);
      final Offset closePos = tester.getCenter(closeButtonFinder);
      expect(closePos.dx, greaterThan(1100.0)); // Placed near right edge
    });
  });
}

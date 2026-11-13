import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/core/locator.dart';
import 'package:snapgrove/services/battery_service.dart';
import 'package:snapgrove/services/notification_service.dart';
import 'package:snapgrove/services/settings_service.dart';
import 'package:snapgrove/services/storage_service.dart';
import 'package:snapgrove/theme/app_blur.dart';
import 'package:snapgrove/viewmodels/app_view_model.dart';

class _FakeStorageService implements StorageService {
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
  Future<void> write(String store, String key, dynamic value) async {
    _data['${store}_$key'] = value;
  }

  @override
  Future<dynamic> read(String store, String key) async => _data['${store}_$key'];
}

void main() {
  group('AppBlur & BatteryService Tests', () {
    late _FakeStorageService storage;
    late SettingsService settings;

    setUp(() async {
      storage = _FakeStorageService();
      settings = SettingsService(storage);
      await settings.init();

      if (locator.isRegistered<StorageService>()) {
        locator.unregister<StorageService>();
      }
      locator.registerSingleton<StorageService>(storage);

      if (locator.isRegistered<SettingsService>()) {
        locator.unregister<SettingsService>();
      }
      locator.registerSingleton<SettingsService>(settings);

      if (!locator.isRegistered<NotificationService>()) {
        locator.registerSingleton<NotificationService>(NotificationService());
      }
      if (!locator.isRegistered<BatteryService>()) {
        locator.registerSingleton<BatteryService>(BatteryService());
      }
      if (!locator.isRegistered<AppViewModel>()) {
        locator.registerLazySingleton<AppViewModel>(() => AppViewModel(
              locator<StorageService>(),
              locator<NotificationService>(),
              locator<SettingsService>(),
            ));
      }
    });

    testWidgets('AppBlur renders BackdropFilter when blur is enabled', (tester) async {
      await settings.setDisableBlur(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBlur(
              solidColor: Color(0xFF1E1E1E),
              blurOpacity: 0.8,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color?.a, closeTo(0.8, 0.01));
    });

    testWidgets('AppBlur completely omits BackdropFilter and has 1.0 opacity when blur is disabled', (tester) async {
      await settings.setDisableBlur(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBlur(
              solidColor: Color(0xFF1E1E1E),
              blurOpacity: 0.8,
              child: Text('Content'),
            ),
          ),
        ),
      );

      // BackdropFilter MUST be completely omitted
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Content'), findsOneWidget);

      // Container background opacity MUST be 1.0 (fully solid, no translucency)
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color?.a, equals(1.0));
    });

    testWidgets('AppBlur reactively updates when runtime blur is disabled', (tester) async {
      await settings.setDisableBlur(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBlur(
              solidColor: Color(0xFF1E1E1E),
              blurOpacity: 0.8,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);

      // Set runtime blur disabled (e.g. low battery trigger)
      settings.setRuntimeBlurDisabled(true);
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color?.a, equals(1.0));
    });

    test('AppBlur static helpers return solid color and zero sigma when blur is disabled', () async {
      await settings.setDisableBlur(true);

      expect(AppBlur.isBlurDisabled, isTrue);
      expect(AppBlur.getSigma(20.0), equals(0.0));

      const translucent = Color(0x991E1E1E);
      final solid = AppBlur.getBackgroundColor(translucent);
      expect(solid.a, equals(1.0));
    });

    test('BatteryService and SettingsService low battery threshold handling', () {
      expect(settings.lowBatteryThreshold, equals(35.0));

      // Battery at 40%: above default 35% threshold -> blur not disabled
      settings.updateBatteryLevel(40.0);
      expect(settings.runtimeBlurDisabled, isFalse);
      expect(settings.shouldDisableBlur(), isFalse);

      // Battery at 30%: <= 35% threshold -> runtime blur disabled
      settings.updateBatteryLevel(30.0);
      expect(settings.runtimeBlurDisabled, isTrue);
      expect(settings.shouldDisableBlur(), isTrue);

      // Disabling the toggle re-enables blur even if battery is low
      settings.setDisableBlurLowBattery(false);
      expect(settings.runtimeBlurDisabled, isFalse);
      expect(settings.shouldDisableBlur(), isFalse);
    });
  });
}

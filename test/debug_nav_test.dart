import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/core/locator.dart';
import 'package:snapgrove/services/battery_service.dart';
import 'package:snapgrove/services/notification_service.dart';
import 'package:snapgrove/services/settings_service.dart';
import 'package:snapgrove/services/storage_service.dart';
import 'package:snapgrove/theme/app_theme.dart';
import 'package:snapgrove/viewmodels/app_view_model.dart';
import 'package:snapgrove/views/debug/debug_view.dart';
import 'package:snapgrove/views/debug/icons_debug_view.dart';
import 'package:snapgrove/views/landing_page.dart';
import 'package:snapgrove/views/settings_view.dart';

class InMemoryStorageService implements StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  Future<ThemeMode> getThemeMode() async {
    final mode = _data['theme_mode'];
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    _data['theme_mode'] = mode.name;
  }

  @override
  Future<String?> getScreenshotDir() async => _data['screenshot_dir'] as String?;

  @override
  Future<void> saveScreenshotDir(String path) async {
    _data['screenshot_dir'] = path;
  }

  @override
  Future<String?> getPermanentScreenshotDir() async => _data['permanent_screenshot_dir'] as String?;

  @override
  Future<void> savePermanentScreenshotDir(String path) async {
    _data['permanent_screenshot_dir'] = path;
  }

  @override
  Future<void> write(String store, String key, dynamic value) async {
    _data['${store}_$key'] = value;
  }

  @override
  Future<dynamic> read(String store, String key) async {
    return _data['${store}_$key'];
  }
}

class MockNavObserver extends NavigatorObserver {
  Route<dynamic>? pushedRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoute = route;
    super.didPush(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryStorageService storage;
  late SettingsService settings;

  setUp(() async {
    await locator.reset();
    storage = InMemoryStorageService();
    locator.registerSingleton<StorageService>(storage);

    settings = SettingsService(storage);
    await settings.init();
    locator.registerSingleton<SettingsService>(settings);

    locator.registerLazySingleton<BatteryService>(() => BatteryService());
    locator.registerLazySingleton<NotificationService>(() => NotificationService());
    locator.registerLazySingleton<AppViewModel>(
      () => AppViewModel(storage, locator<NotificationService>(), settings),
    );
  });

  tearDown(() async {
    await locator.reset();
  });

  group('SettingsService Debug Settings', () {
    test('isDebugAvailable reflects kDebugMode', () {
      expect(settings.isDebugAvailable, equals(kDebugMode));
    });

    test('debugModeEnabled defaults to false', () {
      expect(settings.debugModeEnabled, isFalse);
    });

    test('setDebugModeEnabled updates state and notifies listeners', () async {
      bool notified = false;
      settings.addListener(() => notified = true);

      await settings.setDebugModeEnabled(true);
      expect(notified, isTrue);
      expect(settings.debugModeEnabled, equals(kDebugMode));

      final saved = await storage.read(
        SettingsService.storeName,
        SettingsService.keyDebugModeEnabled,
      );
      expect(saved, isTrue);

      await settings.setDebugModeEnabled(false);
      expect(settings.debugModeEnabled, isFalse);
    });
  });

  group('DebugView UI & Navigation', () {
    Widget buildTestApp(Widget child) {
      return MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [
            SnapgroveColors.light,
          ],
        ),
        home: child,
      );
    }

    testWidgets('Renders Debug Tools AppBar, badge, switch and sections', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const DebugView()));
      await tester.pumpAndSettle();

      expect(find.text('Debug Tools'), findsOneWidget);
      expect(find.text('kDebugMode'), findsNWidgets(2)); // Badge and tile
      expect(find.text('Enable Debug Tools'), findsOneWidget);
      expect(find.text('Material 3 Symbols Tester (iconsDebug)'), findsOneWidget);
      expect(find.text('APP RUNTIME DIAGNOSTICS'), findsOneWidget);
      expect(find.text('Platform Target'), findsOneWidget);
      expect(find.text('AppBlur Shaders'), findsOneWidget);
      expect(find.text('Battery Level'), findsOneWidget);
    });

    testWidgets('Tapping switch toggles setDebugModeEnabled', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(const DebugView()));
      await tester.pumpAndSettle();

      expect(settings.debugModeEnabled, isFalse);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(settings.debugModeEnabled, isTrue);
    });

    testWidgets('Tapping Icons Debug navigates to IconsDebugView', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final navObserver = MockNavObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [navObserver],
          theme: ThemeData.light().copyWith(
            extensions: [
              SnapgroveColors.light,
            ],
          ),
          home: const DebugView(),
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.text('Material 3 Symbols Tester (iconsDebug)');
      expect(tileFinder, findsOneWidget);

      await tester.tap(tileFinder);
      await tester.pump(); // Pushes route

      expect(navObserver.pushedRoute, isA<MaterialPageRoute>());
      final route = navObserver.pushedRoute as MaterialPageRoute;
      final builtWidget = route.builder(tester.element(tileFinder));
      expect(builtWidget, isA<IconsDebugView>());
    });

    testWidgets('SettingsView shows Debug Tools tile when kDebugMode is true and navigates', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final navObserver = MockNavObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [navObserver],
          theme: ThemeData.light().copyWith(
            extensions: [
              SnapgroveColors.light,
            ],
          ),
          home: const SettingsView(),
        ),
      );
      await tester.pumpAndSettle();

      final debugTile = find.text('Debug Tools');
      expect(debugTile, findsOneWidget);

      await tester.tap(debugTile);
      await tester.pump();

      expect(navObserver.pushedRoute, isA<MaterialPageRoute>());
      final route = navObserver.pushedRoute as MaterialPageRoute;
      final builtWidget = route.builder(tester.element(find.byType(SettingsView)));
      expect(builtWidget, isA<DebugView>());
    });

    testWidgets('LandingPage popup menu contains Debug item and navigates to DebugView', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final navObserver = MockNavObserver();
      final appViewModel = locator<AppViewModel>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [navObserver],
          theme: ThemeData.light().copyWith(
            extensions: [
              SnapgroveColors.light,
            ],
          ),
          home: LandingPage(viewModel: appViewModel),
        ),
      );
      await tester.pumpAndSettle();

      // Open more menu via the top right InkWell
      final moreBtn = find.byType(InkWell).first;
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      final debugMenuItem = find.text('Debug');
      expect(debugMenuItem, findsOneWidget);

      await tester.tap(debugMenuItem);
      // Wait for _removeMenu delay (120ms) and route push
      await tester.pump(const Duration(milliseconds: 200));

      expect(navObserver.pushedRoute, isA<MaterialPageRoute>());
      final route = navObserver.pushedRoute as MaterialPageRoute;
      final builtWidget = route.builder(tester.element(find.byType(LandingPage)));
      expect(builtWidget, isA<DebugView>());
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/models/folder_node.dart';
import 'package:snapgrove/services/settings_service.dart';
import 'package:snapgrove/services/storage_service.dart';
import 'package:snapgrove/views/settings_view.dart';
import 'package:snapgrove/viewmodels/app_view_model.dart';
import 'package:snapgrove/services/notification_service.dart';
import 'package:snapgrove/theme/app_theme.dart';
import 'package:snapgrove/core/locator.dart';

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

void main() {
  group('SettingsService Unit Tests', () {
    late InMemoryStorageService storage;
    late SettingsService settings;

    setUp(() async {
      storage = InMemoryStorageService();
      settings = SettingsService(storage);
      await settings.init();
    });

    test('Initializes with default values', () {
      expect(settings.folderSortOrder, equals('name_asc'));
      expect(settings.themeMode, equals(ThemeMode.system));
      expect(settings.disableBlur, isFalse);
      expect(settings.disableBlurLowBattery, isTrue);
      expect(settings.lowBatteryThreshold, equals(35.0));
      expect(settings.binAuthEnabled, isTrue);
    });

    test('Updates and persists all settings', () async {
      await settings.setThemeMode(ThemeMode.dark);
      expect(settings.themeMode, equals(ThemeMode.dark));
      expect(await storage.getThemeMode(), equals(ThemeMode.dark));

      await settings.setFolderSortOrder('items_desc');
      expect(settings.folderSortOrder, equals('items_desc'));
      expect(await storage.read('settings', 'folder_sort_order'), equals('items_desc'));

      await settings.setDisableBlur(true);
      expect(settings.disableBlur, isTrue);
      expect(await storage.read('settings', 'disable_blur'), isTrue);

      await settings.setDisableBlurLowBattery(false);
      expect(settings.disableBlurLowBattery, isFalse);
      expect(await storage.read('settings', 'disable_blur_low_battery'), isFalse);

      await settings.setLowBatteryThreshold(20.0);
      expect(settings.lowBatteryThreshold, equals(20.0));
      expect(await storage.read('settings', 'low_battery_threshold'), equals(20.0));

      await settings.setBinAuthEnabled(false);
      expect(settings.binAuthEnabled, isFalse);
      expect(await storage.read('settings', 'bin_auth_enabled'), isFalse);
    });

    test('Loads previously persisted values from storage on init', () async {
      await storage.write('settings', 'folder_sort_order', 'date_desc');
      await storage.write('settings', 'disable_blur', true);
      await storage.write('settings', 'disable_blur_low_battery', false);
      await storage.write('settings', 'low_battery_threshold', 50.0);
      await storage.write('settings', 'bin_auth_enabled', false);
      await storage.saveThemeMode(ThemeMode.light);

      final newSettings = SettingsService(storage);
      await newSettings.init();

      expect(newSettings.folderSortOrder, equals('date_desc'));
      expect(newSettings.disableBlur, isTrue);
      expect(newSettings.disableBlurLowBattery, isFalse);
      expect(newSettings.lowBatteryThreshold, equals(50.0));
      expect(newSettings.binAuthEnabled, isFalse);
      expect(newSettings.themeMode, equals(ThemeMode.light));
    });

    test('shouldDisableBlur logic works accurately', () async {
      // Default: disableBlur=false, disableBlurLowBattery=true, lowBatteryThreshold=35.0
      expect(settings.shouldDisableBlur(batteryLevelPercent: 50), isFalse);
      expect(settings.shouldDisableBlur(batteryLevelPercent: 35), isTrue);
      expect(settings.shouldDisableBlur(batteryLevelPercent: 10), isTrue);

      // When lowBatteryThreshold is 0 (Off), it never disables for battery
      await settings.setLowBatteryThreshold(0.0);
      expect(settings.shouldDisableBlur(batteryLevelPercent: 5), isFalse);

      // When global disableBlur is true, it always disables blur
      await settings.setDisableBlur(true);
      expect(settings.shouldDisableBlur(batteryLevelPercent: 100), isTrue);
    });

    test('sortFolderNodes sorts accurately based on folderSortOrder', () async {
      final nodes = [
        const FolderNode(
          name: 'Zebra',
          path: '/zebra',
          relPath: 'Zebra',
          totalImageCount: 5,
        ),
        const FolderNode(
          name: 'Apple',
          path: '/apple',
          relPath: 'Apple',
          totalImageCount: 20,
        ),
        const FolderNode(
          name: 'Mango',
          path: '/mango',
          relPath: 'Mango',
          totalImageCount: 1,
        ),
      ];

      // Default: name_asc
      settings.sortFolderNodes(nodes);
      expect(nodes.map((e) => e.name).toList(), equals(['Apple', 'Mango', 'Zebra']));

      // Name desc
      await settings.setFolderSortOrder('name_desc');
      settings.sortFolderNodes(nodes);
      expect(nodes.map((e) => e.name).toList(), equals(['Zebra', 'Mango', 'Apple']));

      // Items desc
      await settings.setFolderSortOrder('items_desc');
      settings.sortFolderNodes(nodes);
      expect(nodes.map((e) => e.name).toList(), equals(['Apple', 'Zebra', 'Mango']));

      // Items asc
      await settings.setFolderSortOrder('items_asc');
      settings.sortFolderNodes(nodes);
      expect(nodes.map((e) => e.name).toList(), equals(['Mango', 'Zebra', 'Apple']));
    });
  });

  group('SettingsView Widget Tests', () {
    setUp(() {
      if (!locator.isRegistered<StorageService>()) {
        locator.registerSingleton<StorageService>(InMemoryStorageService());
      }
      if (!locator.isRegistered<SettingsService>()) {
        locator.registerSingleton<SettingsService>(SettingsService(locator<StorageService>()));
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

    testWidgets('Renders SettingsView with sections and search bar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
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

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Search settings...'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('PERFORMANCE & BATTERY'), findsOneWidget);
      expect(find.text('FOLDERS & TAGS'), findsOneWidget);
      expect(find.text('SECURITY'), findsOneWidget);

      expect(find.text('Disable Blur'), findsOneWidget);
      expect(find.text('Disable Blur on Low Battery'), findsOneWidget);
      expect(find.text('Low Battery Threshold'), findsOneWidget);
      expect(find.text('Folder Sort Order'), findsOneWidget);
      expect(find.text('Bin Authentication'), findsOneWidget);
    });

    testWidgets('Search query filters settings items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SettingsView(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'security');
      await tester.pumpAndSettle();

      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('Bin Authentication'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsNothing);
      expect(find.text('FOLDERS & TAGS'), findsNothing);
    });
  });
}

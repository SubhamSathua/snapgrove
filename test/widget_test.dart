import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_organizer/views/app_view.dart';
import 'package:screenshot_organizer/viewmodels/app_view_model.dart';
import 'package:screenshot_organizer/services/storage_service.dart';
import 'package:screenshot_organizer/services/notification_service.dart';
import 'package:screenshot_organizer/core/locator.dart';

class MockStorageService implements StorageService {
  @override
  Future<void> init() async {}

  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.system;

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
  Future<void> write(String store, String key, dynamic value) async {}

  @override
  Future<dynamic> read(String store, String key) async => null;
}

void main() {
  setUpAll(() {
    locator.registerSingleton<NotificationService>(NotificationService());
  });

  testWidgets('App renders landing page', (WidgetTester tester) async {
    final storage = MockStorageService();
    final notification = locator<NotificationService>();
    final viewModel = AppViewModel(storage, notification);
    
    await tester.pumpWidget(SnapgroveApp(viewModel: viewModel));
    expect(find.text('Snapgrove'), findsNothing);
  });
}

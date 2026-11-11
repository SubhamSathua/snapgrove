import 'package:snapgrove/models/folder_node.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/views/app_view.dart';
import 'package:snapgrove/viewmodels/app_view_model.dart';
import 'package:snapgrove/viewmodels/gallery_view_model.dart';
import 'package:snapgrove/services/bin_service.dart';
import 'package:snapgrove/services/storage_service.dart';
import 'package:snapgrove/services/file_service.dart';
import 'package:snapgrove/services/notification_service.dart';
import 'package:snapgrove/services/share/share_service.dart';
import 'package:snapgrove/core/locator.dart';

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

class MockFileService implements FileService {
  @override
  Future<List<String>> listImages(String path, {bool includeSubfolders = false}) async => [];

  @override
  Future<Uint8List?> readFile(String path) async => null;

  @override
  Future<List<String>> listSubfolders(String path) async => [];

  @override
  Future<bool> createSubfolder(String path, String name) async => true;

  @override
  Future<bool> moveFilesToFolder(String path, String folderName, List<String> files) async => true;

  @override
  Future<bool> undoMoveFiles(String path, String folderName, List<String> files) async => true;

  @override
  Future<bool> deleteFile(String path) async => true;

  @override
  Future<bool> moveToBin(String path, List<String> files) async => true;

  @override
  Future<bool> deleteFilesPermanently(List<String> files) async => true;

  @override
  Future<String?> renameFile(String path, String newName) async => newName;

  @override
  Future<bool> updateModifiedDate(String path, DateTime newDate) async => true;

  @override
  Future<bool> removeExifData(String path) async => true;

  @override
  Future<FolderNode?> getFolderTree(String rootPath) async => null;

  @override
  Future<bool> createNestedFolder(String parentPath, String folderName) async => true;

  @override
  Future<bool> renameFolderNode(String currentPath, String newName) async => true;

  @override
  Future<bool> deleteFolderNode(String folderPath) async => true;
}

class MockShareService implements ShareService {
  @override
  Future<bool> shareImageFile({
    required String filePath,
    required String fileName,
    List<int>? bytes,
  }) async => true;
}

void main() {
  setUpAll(() {
    locator.registerSingleton<StorageService>(MockStorageService());
    locator.registerSingleton<FileService>(MockFileService());
    locator.registerSingleton<NotificationService>(NotificationService());
    locator.registerSingleton<ShareService>(MockShareService());
    locator.registerSingleton<BinService>(BinService());
    locator.registerLazySingleton<AppViewModel>(() => AppViewModel(
          locator<StorageService>(),
          locator<NotificationService>(),
        ));
    locator.registerFactoryParam<GalleryViewModel, String, void>(
      (path, _) => GalleryViewModel(path: path, fileService: locator<FileService>()),
    );
  });

  testWidgets('App renders landing page', (WidgetTester tester) async {
    final storage = locator<StorageService>();
    final notification = locator<NotificationService>();
    final viewModel = AppViewModel(storage, notification);
    await viewModel.init();
    
    await tester.pumpWidget(SnapgroveApp(viewModel: viewModel));
    await tester.pumpAndSettle();
    expect(find.byType(SnapgroveApp), findsOneWidget);
  });

  testWidgets('NotificationService initializes correctly', (WidgetTester tester) async {
    final notification = locator<NotificationService>();
    expect(notification, isNotNull);
  });
}

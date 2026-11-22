import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrove/core/locator.dart';
import 'package:snapgrove/models/folder_node.dart';
import 'package:snapgrove/services/bin_service.dart';
import 'package:snapgrove/services/file_service.dart';
import 'package:snapgrove/services/notification_service.dart';
import 'package:snapgrove/services/share/share_service.dart';
import 'package:snapgrove/services/storage_service.dart';
import 'package:snapgrove/viewmodels/app_view_model.dart';
import 'package:snapgrove/viewmodels/gallery_view_model.dart';
import 'package:snapgrove/views/image_preview_view.dart';
import 'package:snapgrove/theme/snap_symbols.dart';

final Uint8List _transparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

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
  Future<Uint8List?> readFile(String path) async => _transparentPng;
  @override
  Future<List<String>> listSubfolders(String path) async => ['FolderA', 'FolderB'];
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
  @override
  Future<int?> getFolderSizeBytes(String folderPath) async => null;
  @override
  Future<DateTime?> getFolderModifiedDate(String folderPath) async => null;
  @override
  Stream<FileSystemEvent>? watchDirectory(String path, {bool recursive = false}) => null;
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
  late NotificationService notificationService;

  setUpAll(() {
    locator.registerSingleton<StorageService>(MockStorageService());
    locator.registerSingleton<FileService>(MockFileService());
    notificationService = NotificationService();
    locator.registerSingleton<NotificationService>(notificationService);
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

  testWidgets('NotificationService showSnackBar applies bottomOffset when provided', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: notificationService.messengerKey,
        home: const Scaffold(body: Center(child: Text('Home'))),
      ),
    );

    notificationService.showSnackBar('Test with offset', bottomOffset: 72);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final SnackBar snackBar = tester.widget(snackBarFinder);
    expect(snackBar.margin, equals(const EdgeInsets.fromLTRB(16, 0, 16, 72)));
  });

  testWidgets('SnackBar floats above bottom action bar in mobile ImagePreviewView', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: notificationService.messengerKey,
        home: const ImagePreviewView(
          files: ['content://media/external/images/media/101'],
          initialIndex: 0,
          directoryPath: '/storage/emulated/0/Pictures/Screenshots',
          subfolders: ['FolderA', 'FolderB'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify bottom navigation bar buttons are present (icons with tooltips, no labels)
    expect(find.byIcon(SnapSymbols.delete_outline), findsOneWidget);
    expect(find.byIcon(SnapSymbols.info_outline), findsOneWidget);
    expect(find.byIcon(SnapSymbols.share_outlined), findsOneWidget);
    expect(find.byIcon(SnapSymbols.fullscreen), findsOneWidget);

    // Show undo toast
    notificationService.showSnackBar(
      'Moved "image101.png" to FolderA',
      actionLabel: 'Undo',
      onAction: () {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final snackBarRect = tester.getRect(snackBarFinder);
    final binRect = tester.getRect(find.byIcon(SnapSymbols.delete_outline));

    // SnackBar's bottom must be strictly above the bottom action bar's top
    expect(
      snackBarRect.bottom <= binRect.top,
      isTrue,
      reason: 'SnackBar bottom (${snackBarRect.bottom}) should be <= bottom bar item top (${binRect.top})',
    );
  });

  testWidgets('ImagePreviewView PageView uses PageScrollPhysics with BouncingScrollPhysics when unzoomed', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: notificationService.messengerKey,
        home: const ImagePreviewView(
          files: ['content://media/external/images/media/101', 'content://media/external/images/media/102'],
          initialIndex: 0,
          directoryPath: '/storage/emulated/0/Pictures/Screenshots',
          subfolders: ['FolderA', 'FolderB'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.physics, isA<PageScrollPhysics>());
    final pagePhysics = pageView.physics as PageScrollPhysics;
    expect(pagePhysics.parent, isA<BouncingScrollPhysics>());
  });
}

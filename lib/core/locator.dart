import 'package:get_it/get_it.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/file_service.dart';
import '../services/notification_service.dart';
import '../services/share/share_service.dart';
import '../services/bin_service.dart';
import '../viewmodels/app_view_model.dart';
import '../viewmodels/gallery_view_model.dart';
import '../viewmodels/bin_view_model.dart';

final locator = GetIt.instance;

Future<void> setupLocator() async {
  // Services
  final storage = StorageService();
  await storage.init();
  locator.registerSingleton<StorageService>(storage);

  final settingsService = SettingsService(storage);
  await settingsService.init();
  locator.registerSingleton<SettingsService>(settingsService);

  locator.registerLazySingleton<FileService>(() => FileServiceImpl());
  locator.registerSingleton<NotificationService>(NotificationService());
  locator.registerLazySingleton<ShareService>(() => getShareService());
  locator.registerLazySingleton<BinService>(() => BinService());

  // ViewModels
  locator.registerLazySingleton<AppViewModel>(() => AppViewModel(
        locator<StorageService>(),
        locator<NotificationService>(),
        locator<SettingsService>(),
      ));
  locator.registerFactoryParam<GalleryViewModel, String, void>(
    (path, _) => GalleryViewModel(path: path, fileService: locator<FileService>()),
  );
  locator.registerFactory<BinViewModel>(
    () => BinViewModel(locator<BinService>(), locator<NotificationService>()),
  );
}

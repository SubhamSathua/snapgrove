import 'package:get_it/get_it.dart';
import '../services/storage_service.dart';
import '../services/file_service.dart';
import '../services/notification_service.dart';
import '../viewmodels/app_view_model.dart';
import '../viewmodels/gallery_view_model.dart';

final locator = GetIt.instance;

Future<void> setupLocator() async {
  // Services
  final storage = StorageService();
  await storage.init();
  locator.registerSingleton<StorageService>(storage);
  locator.registerLazySingleton<FileService>(() => FileServiceImpl());
  locator.registerSingleton<NotificationService>(NotificationService());

  // ViewModels
  locator.registerFactory(() => AppViewModel(
        locator<StorageService>(),
        locator<NotificationService>(),
      ));
  locator.registerFactoryParam<GalleryViewModel, String, void>(
    (path, _) => GalleryViewModel(path: path, fileService: locator<FileService>()),
  );
}

import 'share_service_stub.dart'
    if (dart.library.io) 'share_service_native.dart'
    if (dart.library.js_interop) 'share_service_web.dart';

abstract class ShareService {
  Future<bool> shareImageFile({
    required String filePath,
    required String fileName,
    List<int>? bytes,
  });
}

ShareService getShareService() => createShareService();

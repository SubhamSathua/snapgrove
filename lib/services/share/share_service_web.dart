import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'share_service.dart';

@JS('navigator.canShare')
external bool _navigatorCanShare(JSObject data);

@JS('navigator.share')
external JSPromise<JSAny?> _navigatorShare(JSObject data);

class WebShareService implements ShareService {
  @override
  Future<bool> shareImageFile({
    required String filePath,
    required String fileName,
    List<int>? bytes,
  }) async {
    try {
      // 1. Validate secure context (HTTPS or localhost)
      if (!web.window.isSecureContext) {
        debugPrint('WebShareService: Secure context required (HTTPS or localhost).');
        return false;
      }

      if (bytes == null || bytes.isEmpty) {
        debugPrint('WebShareService: No file bytes provided for web share.');
        return false;
      }

      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'png';
      final mimeType = _getMimeType(ext);

      // Create web File
      final byteData = Uint8List.fromList(bytes);
      final jsArray = [byteData.toJS].toJS;
      final options = web.FilePropertyBag()..type = mimeType;
      final file = web.File(
        jsArray,
        fileName,
        options,
      );

      // Construct ShareData payload
      final payload = JSObject();
      payload.setProperty('files'.toJS, [file].toJS);
      payload.setProperty('title'.toJS, fileName.toJS);
      payload.setProperty('text'.toJS, fileName.toJS);

      // 2. Validate payload compatibility using navigator.canShare({ files })
      bool canShareFiles = false;
      try {
        canShareFiles = _navigatorCanShare(payload);
      } catch (e) {
        debugPrint('WebShareService: navigator.canShare check failed: $e');
        canShareFiles = false;
      }

      if (!canShareFiles) {
        debugPrint('WebShareService: Browser does not support sharing this file payload.');
        return false;
      }

      // 3. Trigger native web share dialog
      await _navigatorShare(payload).toDart;
      return true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      // If user aborted/dismissed the share dialog, do not treat as error
      if (errorStr.contains('aborterror') || errorStr.contains('abort')) {
        return true;
      }
      debugPrint('WebShareService error: $e');
      return false;
    }
  }

  String _getMimeType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'avif':
        return 'image/avif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/png';
    }
  }
}

ShareService createShareService() => WebShareService();

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'share_service.dart';

class NativeShareService implements ShareService {
  @override
  Future<bool> shareImageFile({
    required String filePath,
    required String fileName,
    List<int>? bytes,
  }) async {
    try {
      if (bytes != null && bytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);
        final result = await Share.shareXFiles(
          [XFile(tempFile.path, name: fileName)],
          text: fileName,
          subject: fileName,
        );
        return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
      }

      if (filePath.startsWith('content://')) {
        final result = await Share.shareXFiles(
          [XFile(filePath, name: fileName)],
          text: fileName,
          subject: fileName,
        );
        return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
      }

      final file = File(filePath);
      if (await file.exists()) {
        final result = await Share.shareXFiles(
          [XFile(filePath, name: fileName)],
          text: fileName,
          subject: fileName,
        );
        return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
      }

      return false;
    } catch (e) {
      debugPrint('NativeShareService error: $e');
      return false;
    }
  }
}

ShareService createShareService() => NativeShareService();

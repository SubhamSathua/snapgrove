import 'dart:typed_data';
import '../models/move_transaction.dart';

/// A stub class that does nothing on native platforms but 
/// defines the interface for our web optimizations.
class WebImageUtils {
  static String? getCachedThumbnailUrl(String path) => null;
  static Future<List<String>> listImages(dynamic root, {bool includeSubfolders = false}) async => [];
  static Future<String?> getThumbnail(String path) async => null;
  static Future<Uint8List?> readFile(String path) async => null;
  static void setExitWarning(bool enabled) {}
  static dynamic getLastPickerHandle() => null;
  static Future<List<String>> listSubfolders() async => [];
  static Future<bool> createSubfolder(String name) async => false;
  static Future<MoveResult> moveFilesToFolder(String folderName, List<String> files) async =>
      const MoveResult(succeededRecords: []);
  static Future<bool> undoMoveFiles(String folderName, List<String> files, {List<MoveRecord>? records}) async => false;
  static Future<bool> deleteFile(String path) async => false;
  static Future<String?> renameFile(String path, String newName) async => null;
  static Future<bool> updateModifiedDate(String path, DateTime newDate) async => false;
  static Future<bool> removeExifData(String path) async => false;
}

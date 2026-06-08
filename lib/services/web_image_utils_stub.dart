import 'dart:typed_data';

/// A stub class that does nothing on native platforms but 
/// defines the interface for our web optimizations.
class WebImageUtils {
  static Future<List<String>> listImages(dynamic root) async => [];
  static Future<String?> getThumbnail(String path) async => null;
  static Future<Uint8List?> readFile(String path) async => null;
  static void setExitWarning(bool enabled) {}
  static dynamic getLastPickerHandle() => null;
}

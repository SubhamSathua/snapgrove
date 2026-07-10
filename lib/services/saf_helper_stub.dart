import 'dart:async';
import 'package:flutter/services.dart';

abstract class SafHelper {
  static Future<List<String>> listImages(String uri) async => [];
  static Future<Uint8List?> readFile(String uri) async => null;
  static Future<Uint8List?> getThumbnail(String uri, {int width = 300, int height = 400}) async => null;
  static Future<List<String>> listSubfolders(String uri) async => [];
  static Future<bool> createSubfolder(String parentUri, String name) async => false;
  static Future<bool> moveFilesToFolder(String parentUri, String folderName, List<String> files) async => false;
}

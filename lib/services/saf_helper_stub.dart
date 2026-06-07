import 'dart:async';
import 'package:flutter/services.dart';

abstract class SafHelper {
  static Future<List<String>> listImages(String uri) async => [];
  static Future<Uint8List?> readFile(String uri) async => null;
}

import 'dart:async';
import 'package:flutter/material.dart';

abstract class StorageService {
  Future<void> init();
  
  // Theme
  Future<void> saveThemeMode(ThemeMode mode);
  Future<ThemeMode> getThemeMode();
  
  // Screenshot Directory
  Future<void> saveScreenshotDir(String path);
  Future<String?> getScreenshotDir();
  
  // Future-proofing: Generic data storage
  Future<void> write(String store, String key, dynamic value);
  Future<dynamic> read(String store, String key);
}

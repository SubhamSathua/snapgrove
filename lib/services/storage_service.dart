import 'dart:async';
import 'package:flutter/material.dart';
import 'storage/storage_stub.dart'
    if (dart.library.js_interop) 'storage/idb_storage.dart'
    if (dart.library.io) 'storage/sp_storage.dart';

abstract class StorageService {
  factory StorageService() => createStorage();

  Future<void> init();
  
  // Theme
  Future<void> saveThemeMode(ThemeMode mode);
  Future<ThemeMode> getThemeMode();
  
  // Screenshot Directory (Temporary/Current Session)
  Future<void> saveScreenshotDir(String path);
  Future<String?> getScreenshotDir();

  // Screenshot Folder Path (Permanent/System Source)
  Future<void> savePermanentScreenshotDir(String path);
  Future<String?> getPermanentScreenshotDir();
  
  // Future-proofing: Generic data storage
  Future<void> write(String store, String key, dynamic value);
  Future<dynamic> read(String store, String key);
}

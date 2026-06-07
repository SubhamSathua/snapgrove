import 'package:flutter/material.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/idb_browser.dart';
import '../storage_service.dart';

class IndexedDBStorage implements StorageService {
  late Database _db;
  final String _dbName = 'SnapgroveDB';
  final String _settingsStore = 'settings';

  @override
  Future<void> init() async {
    final idbFactory = idbFactoryBrowser;
    _db = await idbFactory.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final db = event.database;
        db.createObjectStore(_settingsStore);
        db.createObjectStore('folders', autoIncrement: true);
        // Future-proofing: Create a general data store
        db.createObjectStore('app_data');
      },
    );
  }

  @override
  Future<ThemeMode> getThemeMode() async {
    final mode = await _readSetting('theme_mode');
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    await _saveSetting('theme_mode', mode.name);
  }

  @override
  Future<String?> getScreenshotDir() async {
    return await _readSetting('screenshot_dir') as String?;
  }

  @override
  Future<void> saveScreenshotDir(String path) async {
    await _saveSetting('screenshot_dir', path);
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final txn = _db.transaction(_settingsStore, idbModeReadWrite);
    final store = txn.objectStore(_settingsStore);
    await store.put(value, key);
    await txn.completed;
  }

  Future<dynamic> _readSetting(String key) async {
    final txn = _db.transaction(_settingsStore, idbModeReadOnly);
    final store = txn.objectStore(_settingsStore);
    final value = await store.getObject(key);
    await txn.completed;
    return value;
  }

  @override
  Future<void> write(String storeName, String key, dynamic value) async {
    // Ensure store exists or use app_data as default
    final txn = _db.transaction(storeName, idbModeReadWrite);
    final store = txn.objectStore(storeName);
    await store.put(value, key);
    await txn.completed;
  }

  @override
  Future<dynamic> read(String storeName, String key) async {
    final txn = _db.transaction(storeName, idbModeReadOnly);
    final store = txn.objectStore(storeName);
    final value = await store.getObject(key);
    await txn.completed;
    return value;
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage_service.dart';

StorageService createStorage() => SharedPrefsStorage();

class SharedPrefsStorage implements StorageService {
  late SharedPreferences _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<ThemeMode> getThemeMode() async {
    final mode = _prefs.getString('theme_mode');
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    await _prefs.setString('theme_mode', mode.name);
  }

  @override
  Future<String?> getScreenshotDir() async {
    return _prefs.getString('screenshot_dir');
  }

  @override
  Future<void> saveScreenshotDir(String path) async {
    await _prefs.setString('screenshot_dir', path);
  }

  @override
  Future<String?> getPermanentScreenshotDir() async {
    return _prefs.getString('permanent_screenshot_dir');
  }

  @override
  Future<void> savePermanentScreenshotDir(String path) async {
    await _prefs.setString('permanent_screenshot_dir', path);
  }

  @override
  Future<void> write(String store, String key, dynamic value) async {
    final compositeKey = '${store}_$key';
    if (value is String) {
      await _prefs.setString(compositeKey, value);
    } else if (value is int) {
      await _prefs.setInt(compositeKey, value);
    } else if (value is bool) {
      await _prefs.setBool(compositeKey, value);
    } else if (value is double) {
      await _prefs.setDouble(compositeKey, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(compositeKey, value);
    }
  }

  @override
  Future<dynamic> read(String store, String key) async {
    return _prefs.get('${store}_$key');
  }
}

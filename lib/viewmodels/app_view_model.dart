import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class AppViewModel extends ChangeNotifier {
  final StorageService _storage;
  
  ThemeMode _themeMode = ThemeMode.system;
  String? _screenshotDir;
  String? _permanentScreenshotDir;
  bool _isLoading = true;

  AppViewModel(this._storage);

  ThemeMode get themeMode => _themeMode;
  String? get screenshotDir => _screenshotDir;
  String? get permanentScreenshotDir => _permanentScreenshotDir;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _themeMode = await _storage.getThemeMode();
    _screenshotDir = await _storage.getScreenshotDir();
    _permanentScreenshotDir = await _storage.getPermanentScreenshotDir();
    _isLoading = false;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _storage.saveThemeMode(mode);
    notifyListeners();
  }

  void setScreenshotDir(String path) {
    _screenshotDir = path;
    _storage.saveScreenshotDir(path);
    notifyListeners();
  }

  void setPermanentScreenshotDir(String path) {
    _permanentScreenshotDir = path;
    _storage.savePermanentScreenshotDir(path);
    notifyListeners();
  }
}

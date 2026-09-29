import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/locator.dart';
import '../services/bin_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AppViewModel extends ChangeNotifier {
  final StorageService _storage;
  final NotificationService _notification;
  
  ThemeMode _themeMode = ThemeMode.system;
  String? _screenshotDir;
  String? _permanentScreenshotDir;
  bool _isLoading = true;

  AppViewModel(this._storage, this._notification);

  ThemeMode get themeMode => _themeMode;
  String? get screenshotDir => _screenshotDir;
  String? get permanentScreenshotDir => _permanentScreenshotDir;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    try {
      _themeMode = await _storage.getThemeMode();
      _screenshotDir = await _storage.getScreenshotDir();
      _permanentScreenshotDir = await _storage.getPermanentScreenshotDir();
    } catch (e) {
      _notification.showSnackBar('Failed to load settings', isError: true);
    }
    _isLoading = false;
    notifyListeners();

    // Lightweight non-blocking background 24h periodic bin cleanup check
    if (!kIsWeb) {
      unawaited(locator<BinService>().cleanOldBinFiles(storage: _storage));
    }
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

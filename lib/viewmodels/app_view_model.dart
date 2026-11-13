import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/locator.dart';
import '../services/battery_service.dart';
import '../services/bin_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';

class AppViewModel extends ChangeNotifier {
  final StorageService _storage;
  final NotificationService _notification;
  final SettingsService? _settingsService;
  
  ThemeMode _themeMode = ThemeMode.system;
  String? _screenshotDir;
  String? _permanentScreenshotDir;
  bool _isLoading = true;

  AppViewModel(this._storage, this._notification, [this._settingsService]) {
    _settingsService?.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    final settings = _settingsService;
    if (settings != null && _themeMode != settings.themeMode) {
      _themeMode = settings.themeMode;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _settingsService?.removeListener(_onSettingsChanged);
    super.dispose();
  }

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

    // Check battery level on startup to adjust blur if needed
    if (!kIsWeb) {
      try {
        final batteryService = locator<BatteryService>();
        final info = await batteryService.getBatteryInfo();
        if (info != null && info.level != null) {
          final level = info.level!.toDouble();
          _settingsService?.updateBatteryLevel(level);
          final settings = _settingsService;
          if (settings != null &&
              settings.disableBlurLowBattery &&
              level <= settings.lowBatteryThreshold) {
            settings.setRuntimeBlurDisabled(true);
          }
        }
      } catch (_) {}
    }

    // Lightweight non-blocking background 24h periodic bin cleanup check
    if (!kIsWeb) {
      unawaited(locator<BinService>().cleanOldBinFiles(storage: _storage));
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _storage.saveThemeMode(mode);
    _settingsService?.setThemeMode(mode);
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

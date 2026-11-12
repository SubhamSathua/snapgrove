import 'dart:async';
import 'package:flutter/material.dart';
import '../models/folder_node.dart';
import 'storage_service.dart';

class SettingsService extends ChangeNotifier {
  final StorageService _storage;

  SettingsService(this._storage);

  static const String storeName = 'settings';
  static const String keyFolderSortOrder = 'folder_sort_order';
  static const String keyDisableBlur = 'disable_blur';
  static const String keyDisableBlurLowBattery = 'disable_blur_low_battery';
  static const String keyLowBatteryThreshold = 'low_battery_threshold';
  static const String keyBinAuthEnabled = 'bin_auth_enabled';

  ThemeMode _themeMode = ThemeMode.system;
  String _folderSortOrder = 'name_asc';
  bool _disableBlur = false;
  bool _disableBlurLowBattery = true;
  double _lowBatteryThreshold = 35.0; // 0 to 100; 0 means Off
  bool _binAuthEnabled = true;

  ThemeMode get themeMode => _themeMode;
  String get folderSortOrder => _folderSortOrder;
  bool get disableBlur => _disableBlur;
  bool get disableBlurLowBattery => _disableBlurLowBattery;
  double get lowBatteryThreshold => _lowBatteryThreshold;
  bool get binAuthEnabled => _binAuthEnabled;

  /// Returns true if blur should currently be disabled based on settings and optional battery level.
  bool shouldDisableBlur({double? batteryLevelPercent}) {
    if (_disableBlur) return true;
    if (_disableBlurLowBattery && _lowBatteryThreshold > 0 && batteryLevelPercent != null) {
      return batteryLevelPercent <= _lowBatteryThreshold;
    }
    return false;
  }

  Future<void> init() async {
    try {
      _themeMode = await _storage.getThemeMode();
    } catch (_) {}

    try {
      final savedSort = await _storage.read(storeName, keyFolderSortOrder);
      if (savedSort is String && savedSort.isNotEmpty) {
        _folderSortOrder = savedSort;
      }
    } catch (_) {}

    try {
      final savedBlur = await _storage.read(storeName, keyDisableBlur);
      if (savedBlur is bool) {
        _disableBlur = savedBlur;
      }
    } catch (_) {}

    try {
      final savedLowBatt = await _storage.read(storeName, keyDisableBlurLowBattery);
      if (savedLowBatt is bool) {
        _disableBlurLowBattery = savedLowBatt;
      }
    } catch (_) {}

    try {
      final savedThreshold = await _storage.read(storeName, keyLowBatteryThreshold);
      if (savedThreshold is num) {
        _lowBatteryThreshold = savedThreshold.toDouble();
      }
    } catch (_) {}

    try {
      final savedBinAuth = await _storage.read(storeName, keyBinAuthEnabled);
      if (savedBinAuth is bool) {
        _binAuthEnabled = savedBinAuth;
      }
    } catch (_) {}

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.saveThemeMode(mode);
  }

  Future<void> setFolderSortOrder(String order) async {
    if (_folderSortOrder == order) return;
    _folderSortOrder = order;
    notifyListeners();
    await _storage.write(storeName, keyFolderSortOrder, order);
  }

  Future<void> setDisableBlur(bool value) async {
    if (_disableBlur == value) return;
    _disableBlur = value;
    notifyListeners();
    await _storage.write(storeName, keyDisableBlur, value);
  }

  Future<void> setDisableBlurLowBattery(bool value) async {
    if (_disableBlurLowBattery == value) return;
    _disableBlurLowBattery = value;
    notifyListeners();
    await _storage.write(storeName, keyDisableBlurLowBattery, value);
  }

  Future<void> setLowBatteryThreshold(double value) async {
    if (_lowBatteryThreshold == value) return;
    _lowBatteryThreshold = value;
    notifyListeners();
    await _storage.write(storeName, keyLowBatteryThreshold, value);
  }

  Future<void> setBinAuthEnabled(bool value) async {
    if (_binAuthEnabled == value) return;
    _binAuthEnabled = value;
    notifyListeners();
    await _storage.write(storeName, keyBinAuthEnabled, value);
  }

  /// Sorts a list of [FolderNode] in place according to [folderSortOrder].
  void sortFolderNodes(List<FolderNode> nodes) {
    switch (_folderSortOrder) {
      case 'name_desc':
        nodes.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'items_desc':
        nodes.sort((a, b) => b.totalImageCount.compareTo(a.totalImageCount));
        break;
      case 'items_asc':
        nodes.sort((a, b) => a.totalImageCount.compareTo(b.totalImageCount));
        break;
      case 'date_desc':
        nodes.sort((a, b) {
          final da = a.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        break;
      case 'date_asc':
        nodes.sort((a, b) {
          final da = a.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.modifiedDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        });
        break;
      case 'name_asc':
      default:
        nodes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
  }

  static String getFolderSortLabel(String order) {
    switch (order) {
      case 'name_desc':
        return 'Name (Z to A)';
      case 'items_desc':
        return 'Items (Most first)';
      case 'items_asc':
        return 'Items (Fewest first)';
      case 'date_desc':
        return 'Date (Newest first)';
      case 'date_asc':
        return 'Date (Oldest first)';
      case 'name_asc':
      default:
        return 'Name (A to Z)';
    }
  }
}

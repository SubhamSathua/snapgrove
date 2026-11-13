import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
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

  // PC Bin password keys
  static const String keyBinPasswordHash = 'bin_password_hash';
  static const String keyBinPasswordHint = 'bin_password_hint';
  static const String keyBinFirstMoveDone = 'bin_first_move_done';

  ThemeMode _themeMode = ThemeMode.system;
  String _folderSortOrder = 'name_asc';
  bool _disableBlur = false;
  bool _disableBlurLowBattery = true;
  double _lowBatteryThreshold = 35.0; // 0 to 100; 0 means Off
  bool _binAuthEnabled = !kIsWeb &&
      (defaultTargetPlatform != TargetPlatform.windows &&
       defaultTargetPlatform != TargetPlatform.linux &&
       defaultTargetPlatform != TargetPlatform.macOS);

  // PC bin password state
  String? _binPasswordHash;
  String? _binPasswordHint;
  bool _binFirstMoveDone = false;

  bool _runtimeBlurDisabled = false;
  double? _batteryLevelPercent;

  ThemeMode get themeMode => _themeMode;
  String get folderSortOrder => _folderSortOrder;
  bool get disableBlur => _disableBlur;
  bool get disableBlurLowBattery => _disableBlurLowBattery;
  double get lowBatteryThreshold => _lowBatteryThreshold;
  bool get binAuthEnabled => _binAuthEnabled;
  bool get runtimeBlurDisabled => _runtimeBlurDisabled;
  double? get batteryLevelPercent => _batteryLevelPercent;

  /// Whether a PC bin password has been created.
  bool get isBinPasswordSet => _binPasswordHash != null && _binPasswordHash!.isNotEmpty;

  /// The optional hint for the PC bin password.
  String? get binPasswordHint => _binPasswordHint;

  /// Whether the user has moved a file to bin at least once on PC.
  bool get binFirstMoveDone => _binFirstMoveDone;

  /// Explicitly sets the runtime blur disabled state (e.g. from low battery detection).
  void setRuntimeBlurDisabled(bool value) {
    if (_runtimeBlurDisabled == value) return;
    _runtimeBlurDisabled = value;
    notifyListeners();
  }

  /// Updates detected battery level and updates runtime blur if applicable.
  void updateBatteryLevel(double? percent) {
    _batteryLevelPercent = percent;
    if (_disableBlurLowBattery &&
        _lowBatteryThreshold > 0 &&
        percent != null &&
        percent <= _lowBatteryThreshold) {
      _runtimeBlurDisabled = true;
    } else if (!_disableBlur) {
      _runtimeBlurDisabled = false;
    }
    notifyListeners();
  }

  /// Returns true if blur should currently be disabled based on settings, runtime state, and battery level.
  bool shouldDisableBlur({double? batteryLevelPercent}) {
    if (_disableBlur || _runtimeBlurDisabled) return true;
    final level = batteryLevelPercent ?? _batteryLevelPercent;
    if (_disableBlurLowBattery && _lowBatteryThreshold > 0 && level != null) {
      return level <= _lowBatteryThreshold;
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
      } else {
        final isPc = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
             defaultTargetPlatform == TargetPlatform.linux ||
             defaultTargetPlatform == TargetPlatform.macOS);
        _binAuthEnabled = !isPc;
      }
    } catch (_) {}

    try {
      final savedHash = await _storage.read(storeName, keyBinPasswordHash);
      if (savedHash is String && savedHash.isNotEmpty) {
        _binPasswordHash = savedHash;
      }
    } catch (_) {}

    try {
      final savedHint = await _storage.read(storeName, keyBinPasswordHint);
      if (savedHint is String) {
        _binPasswordHint = savedHint.isEmpty ? null : savedHint;
      }
    } catch (_) {}

    try {
      final savedFirst = await _storage.read(storeName, keyBinFirstMoveDone);
      if (savedFirst is bool) {
        _binFirstMoveDone = savedFirst;
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
    if (_batteryLevelPercent != null) {
      _runtimeBlurDisabled = _disableBlurLowBattery &&
          _lowBatteryThreshold > 0 &&
          _batteryLevelPercent! <= _lowBatteryThreshold;
    }
    notifyListeners();
    await _storage.write(storeName, keyDisableBlurLowBattery, value);
  }

  Future<void> setLowBatteryThreshold(double value) async {
    if (_lowBatteryThreshold == value) return;
    _lowBatteryThreshold = value;
    if (_batteryLevelPercent != null) {
      _runtimeBlurDisabled = _disableBlurLowBattery &&
          _lowBatteryThreshold > 0 &&
          _batteryLevelPercent! <= _lowBatteryThreshold;
    }
    notifyListeners();
    await _storage.write(storeName, keyLowBatteryThreshold, value);
  }

  Future<void> setBinAuthEnabled(bool value) async {
    if (_binAuthEnabled == value) return;
    _binAuthEnabled = value;
    notifyListeners();
    await _storage.write(storeName, keyBinAuthEnabled, value);
  }

  /// Sets or clears the PC bin password. Pass null/empty to remove it.
  Future<void> setBinPassword(String? plainPassword, {String? hint}) async {
    if (plainPassword == null || plainPassword.isEmpty) {
      _binPasswordHash = null;
      _binPasswordHint = null;
      await _storage.write(storeName, keyBinPasswordHash, '');
      await _storage.write(storeName, keyBinPasswordHint, '');
    } else {
      _binPasswordHash = _hashPassword(plainPassword);
      _binPasswordHint = hint?.isNotEmpty == true ? hint : null;
      await _storage.write(storeName, keyBinPasswordHash, _binPasswordHash!);
      await _storage.write(storeName, keyBinPasswordHint, _binPasswordHint ?? '');
    }
    notifyListeners();
  }

  /// Verifies a plain password against the stored hash.
  bool verifyBinPassword(String plainPassword) {
    if (_binPasswordHash == null || _binPasswordHash!.isEmpty) return false;
    return _hashPassword(plainPassword) == _binPasswordHash;
  }

  /// Marks that the user has moved a file to Bin for the first time (PC).
  Future<void> markBinFirstMoveDone() async {
    if (_binFirstMoveDone) return;
    _binFirstMoveDone = true;
    notifyListeners();
    await _storage.write(storeName, keyBinFirstMoveDone, true);
  }

  static String _hashPassword(String plain) {
    final bytes = utf8.encode(plain);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
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

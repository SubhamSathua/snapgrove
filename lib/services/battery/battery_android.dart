import 'package:flutter/services.dart';
import 'battery_info.dart';

/// Android implementation — queries battery level via [MethodChannel] / BatteryManager.
Future<BatteryInfo?> getPlatformBatteryInfo() async {
  try {
    const channel = MethodChannel('com.snapgrove.organizer/battery');
    final int? level = await channel.invokeMethod<int>('getBatteryLevel');
    if (level != null && level >= 0 && level <= 100) {
      return BatteryInfo(level: level, isCharging: false);
    }
  } catch (_) {}

  try {
    const legacyChannel = MethodChannel('plugins.flutter.io/battery');
    final int? level = await legacyChannel.invokeMethod<int>('getBatteryLevel');
    if (level != null && level >= 0 && level <= 100) {
      return BatteryInfo(level: level, isCharging: false);
    }
  } catch (_) {}

  return null;
}

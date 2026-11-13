import 'dart:io' show Platform;
import 'battery_info.dart';
import 'battery_windows.dart' as win;
import 'battery_android.dart' as android;
import 'battery_stub.dart' as stub;

/// Dispatches to the correct native implementation at runtime.
Future<BatteryInfo?> getPlatformBatteryInfo() async {
  if (Platform.isWindows) return win.getPlatformBatteryInfo();
  if (Platform.isAndroid) return android.getPlatformBatteryInfo();
  return stub.getPlatformBatteryInfo();
}

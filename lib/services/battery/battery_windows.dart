import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'battery_info.dart';

/// Windows implementation — queries [GetSystemPowerStatus] via win32 FFI.
/// Returns null only if the win32 call fails.
Future<BatteryInfo?> getPlatformBatteryInfo() async {
  final pStatus = calloc<SYSTEM_POWER_STATUS>();
  try {
    final result = GetSystemPowerStatus(pStatus);
    if (result == 0) return null; // call failed

    final status = pStatus.ref;
    // BatteryLifePercent == 255 means "unknown" (e.g. desktop with no battery).
    final levelRaw = status.BatteryLifePercent;
    final level = (levelRaw == 255) ? null : levelRaw.clamp(0, 100);

    // ACLineStatus: 0 = offline (battery), 1 = online (AC power)
    final isCharging = status.ACLineStatus == 1;

    return BatteryInfo(level: level, isCharging: isCharging);
  } catch (_) {
    return null;
  } finally {
    calloc.free(pStatus);
  }
}

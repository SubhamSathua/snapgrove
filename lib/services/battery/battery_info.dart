/// Battery level result from [BatteryService.getBatteryLevel].
///
/// [level] is 0–100 (percent) or null if unavailable / AC-only device with
/// no battery (e.g. a desktop PC with no UPS).
/// [isCharging] is true when the device is on external power.
class BatteryInfo {
  const BatteryInfo({this.level, this.isCharging = false});

  final int? level;
  final bool isCharging;
}

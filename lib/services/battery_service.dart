import 'battery/battery_info.dart';
import 'battery/battery_stub.dart'
    if (dart.library.io) 'battery/battery_io.dart';

export 'battery/battery_info.dart';

/// Platform-agnostic battery service.
///
/// Call [getBatteryInfo] once at app startup to decide whether blur should be
/// suppressed. The result is cached so subsequent calls are free.
class BatteryService {
  BatteryInfo? _cached;
  bool _fetched = false;

  /// Returns the battery info, fetching once and caching the result.
  /// Returns null if the platform is unsupported or the query fails.
  Future<BatteryInfo?> getBatteryInfo() async {
    if (_fetched) return _cached;
    _cached = await getPlatformBatteryInfo();
    _fetched = true;
    return _cached;
  }

  /// Invalidate the cache (useful for testing or manual refresh).
  void invalidate() {
    _fetched = false;
    _cached = null;
  }
}

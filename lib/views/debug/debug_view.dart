import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/locator.dart';
import '../../services/battery_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_blur.dart';
import '../../theme/app_theme.dart';
import '../../theme/snap_symbols.dart';
import 'icons_debug_view.dart';

class DebugView extends StatefulWidget {
  const DebugView({super.key});

  @override
  State<DebugView> createState() => _DebugViewState();
}

class _DebugViewState extends State<DebugView> {
  final SettingsService _settingsService = locator<SettingsService>();
  double? _batteryPercent;

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_onSettingsChanged);
    _batteryPercent = _settingsService.batteryLevelPercent;
    _loadBattery();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBattery() async {
    try {
      final info = await locator<BatteryService>().getBatteryInfo();
      if (mounted && info?.level != null) {
        setState(() {
          _batteryPercent = info!.level!.toDouble();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;
    final width = MediaQuery.of(context).size.width;
    final contentMax = width >= 900 ? 760.0 : (width >= 600 ? 640.0 : double.infinity);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF9F9FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, sc, isDark),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMax),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Section 1: Developer Settings
                      _buildSectionHeader('DEVELOPER SETTINGS', sc),
                      _buildCardContainer(
                        isDark: isDark,
                        sc: sc,
                        children: [
                          _buildSwitchTile(
                            sc: sc,
                            isDark: isDark,
                            title: 'Enable Debug Tools',
                            subtitle:
                                'Toggles debug features across the app. In release builds, kDebugMode is false and debug tools are completely stripped at compile time.',
                            value: _settingsService.debugModeEnabled,
                            onChanged: (val) => _settingsService.setDebugModeEnabled(val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 2: Debug Tools List
                      _buildSectionHeader('DEBUG TOOLS', sc),
                      _buildCardContainer(
                        isDark: isDark,
                        sc: sc,
                        children: [
                          _buildNavigationTile(
                            sc: sc,
                            isDark: isDark,
                            icon: SnapSymbols.palette,
                            title: 'Material 3 Symbols Tester (iconsDebug)',
                            subtitle:
                                'Interactive variable font axis tester, ligatures, JSON config & Flutter snippet generator',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const IconsDebugView(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 3: App Runtime Diagnostics
                      _buildSectionHeader('APP RUNTIME DIAGNOSTICS', sc),
                      _buildCardContainer(
                        isDark: isDark,
                        sc: sc,
                        children: [
                          _buildDiagnosticTile(
                            sc: sc,
                            isDark: isDark,
                            icon: SnapSymbols.display_settings,
                            label: 'Platform Target',
                            value: '${defaultTargetPlatform.name}${kIsWeb ? ' (Web)' : ''}',
                          ),
                          _buildDivider(isDark),
                          _buildDiagnosticTile(
                            sc: sc,
                            isDark: isDark,
                            icon: SnapSymbols.bug_report,
                            label: 'kDebugMode',
                            valueWidget: _buildActiveBadge(
                              label: kDebugMode ? 'true' : 'false',
                              isActive: kDebugMode,
                            ),
                          ),
                          _buildDivider(isDark),
                          _buildDiagnosticTile(
                            sc: sc,
                            isDark: isDark,
                            icon: SnapSymbols.blur_on,
                            label: 'AppBlur Shaders',
                            value: AppBlur.isBlurDisabled
                                ? 'Disabled (Solid fallback)'
                                : 'Active (BackdropFilter)',
                          ),
                          _buildDivider(isDark),
                          _buildDiagnosticTile(
                            sc: sc,
                            isDark: isDark,
                            icon: SnapSymbols.battery_charging_full,
                            label: 'Battery Level',
                            value: _batteryPercent != null
                                ? '${_batteryPercent!.toStringAsFixed(0)}%'
                                : (_settingsService.batteryLevelPercent != null
                                    ? '${_settingsService.batteryLevelPercent!.toStringAsFixed(0)}%'
                                    : 'N/A'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, SnapgroveColors sc, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppBlur.getBackgroundColor(
          (isDark ? const Color(0xFF141414) : Colors.white).withValues(alpha: 0.85),
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              SnapSymbols.arrow_back,
              color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF202020),
            ),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Text(
            'Debug Tools',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (kDebugMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'kDebugMode',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, SnapgroveColors sc) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: sc.muted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required SnapgroveColors sc,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppBlur.getBackgroundColor(
          (isDark ? const Color(0xFF181818) : Colors.white).withValues(alpha: 0.85),
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? const Color(0x12FFFFFF) : const Color(0x0A000000),
    );
  }

  Widget _buildSwitchTile({
    required SnapgroveColors sc,
    required bool isDark,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 12,
                      color: sc.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: value,
                activeThumbColor: sc.accent,
                activeTrackColor: sc.accent.withValues(alpha: 0.35),
                inactiveThumbColor: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
                inactiveTrackColor: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required SnapgroveColors sc,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sc.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: sc.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 12,
                      color: sc.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              SnapSymbols.chevron_right,
              size: 20,
              color: sc.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticTile({
    required SnapgroveColors sc,
    required bool isDark,
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: sc.muted,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (valueWidget != null)
            valueWidget
          else if (value != null)
            Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sc.muted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveBadge({required String label, required bool isActive}) {
    final color = isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

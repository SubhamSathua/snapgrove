import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/snap_symbols.dart';

/// Material 3 Switch with checkmark on active state matching M3 specifications.
///
/// In the off state: outlined neutral track, small neutral thumb, no icon.
/// In the on state: solid accent track, white thumb with accent checkmark icon.
class M3Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final double scale;

  const M3Switch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.scale = 0.88,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sc = context.snapgroveColors;
    final color = activeColor ?? sc.accent;

    return Transform.scale(
      scale: scale,
      child: Switch(
        value: value,
        mouseCursor: SystemMouseCursors.click,
        activeTrackColor: color,
        inactiveTrackColor: isDark ? const Color(0xFF2B2930) : const Color(0xFFE7E0EC),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? const Color(0xFF938F99) : const Color(0xFF79747E);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return color;
          }
          return isDark ? const Color(0xFF938F99) : const Color(0xFF79747E);
        }),
        trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return 0.0;
          }
          return 2.0;
        }),
        thumbIcon: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Icon(SnapSymbols.check, size: 14, color: color);
          }
          return null;
        }),
        onChanged: onChanged,
      ),
    );
  }
}

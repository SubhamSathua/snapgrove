import 'package:flutter/material.dart';

Color rippleColor(Color bg) {
  return bg.computeLuminance() > 0.5
      ? Colors.black.withValues(alpha: 0.35)
      : Colors.white.withValues(alpha: 0.45);
}

@immutable
class SnapgroveColors extends ThemeExtension<SnapgroveColors> {
  const SnapgroveColors({
    required this.muted,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.iconBg,
    required this.iconBorder,
    required this.border,
    required this.overlay,
    required this.accent,
    required this.accentDark,
    required this.primaryBtnBg,
    required this.primaryBtnText,
    required this.menuHover,
    required this.rippleColor,
    required this.browseRipple,
  });

  final Color muted;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color iconBg;
  final Color iconBorder;
  final Color border;
  final Color overlay;
  final Color accent;
  final Color accentDark;
  final Color primaryBtnBg;
  final Color primaryBtnText;
  final Color menuHover;
  final Color rippleColor;
  final Color browseRipple;

  static const light = SnapgroveColors(
    muted: Color(0xFF2e2e2e),
    surfaceMuted: Color(0xFFf3f3f3),
    surfaceElevated: Color(0xFFffffff),
    iconBg: Color(0xFFefefef),
    iconBorder: Color(0xFFe1e1e1),
    border: Color(0x14000000),
    overlay: Color(0x33000000),
    accent: Color(0xFFd6005b),
    accentDark: Color(0xFFb0004b),
    primaryBtnBg: Color(0xFF000000),
    primaryBtnText: Color(0xFFffffff),
    menuHover: Color(0x0a000000),
    rippleColor: Color(0x33000000),
    browseRipple: Color(0xFFffffff),
  );

  static const dark = SnapgroveColors(
    muted: Color(0xFFc7c7c7),
    surfaceMuted: Color(0xFF242424),
    surfaceElevated: Color(0xFF1f1f1f),
    iconBg: Color(0xFF222222),
    iconBorder: Color(0xFF2f2f2f),
    border: Color(0x1fffffff),
    overlay: Color(0x73000000),
    accent: Color(0xFFff2a7b),
    accentDark: Color(0xFFe01966),
    primaryBtnBg: Color(0xFFffffff),
    primaryBtnText: Color(0xFF000000),
    menuHover: Color(0x0fffffff),
    rippleColor: Color(0x33ffffff),
    browseRipple: Color(0xFF000000),
  );

  @override
  SnapgroveColors copyWith({
    Color? muted,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? iconBg,
    Color? iconBorder,
    Color? border,
    Color? overlay,
    Color? accent,
    Color? accentDark,
    Color? primaryBtnBg,
    Color? primaryBtnText,
    Color? menuHover,
    Color? rippleColor,
    Color? browseRipple,
  }) {
    return SnapgroveColors(
      muted: muted ?? this.muted,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      iconBg: iconBg ?? this.iconBg,
      iconBorder: iconBorder ?? this.iconBorder,
      border: border ?? this.border,
      overlay: overlay ?? this.overlay,
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      primaryBtnBg: primaryBtnBg ?? this.primaryBtnBg,
      primaryBtnText: primaryBtnText ?? this.primaryBtnText,
      menuHover: menuHover ?? this.menuHover,
      rippleColor: rippleColor ?? this.rippleColor,
      browseRipple: browseRipple ?? this.browseRipple,
    );
  }

  @override
  SnapgroveColors lerp(ThemeExtension<SnapgroveColors>? other, double t) {
    if (other is! SnapgroveColors) return this;
    return SnapgroveColors(
      muted: Color.lerp(muted, other.muted, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      iconBg: Color.lerp(iconBg, other.iconBg, t)!,
      iconBorder: Color.lerp(iconBorder, other.iconBorder, t)!,
      border: Color.lerp(border, other.border, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      primaryBtnBg: Color.lerp(primaryBtnBg, other.primaryBtnBg, t)!,
      primaryBtnText: Color.lerp(primaryBtnText, other.primaryBtnText, t)!,
      menuHover: Color.lerp(menuHover, other.menuHover, t)!,
      rippleColor: Color.lerp(rippleColor, other.rippleColor, t)!,
      browseRipple: Color.lerp(browseRipple, other.browseRipple, t)!,
    );
  }
}

extension SnapgroveContext on BuildContext {
  SnapgroveColors get snapgroveColors => Theme.of(this).extension<SnapgroveColors>()!;
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: false,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFffffff),
      fontFamily: 'Lora',
      extensions: const [SnapgroveColors.light],
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFd6005b),
        surface: Color(0xFFffffff),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: false,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      fontFamily: 'Lora',
      extensions: const [SnapgroveColors.dark],
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFff2a7b),
        surface: Color(0xFF000000),
      ),
    );
  }
}

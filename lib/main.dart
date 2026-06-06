import 'package:flutter/material.dart';

void main() {
  runApp(const SnapgroveApp());
}

Color _rippleColor(Color bg) {
  return bg.computeLuminance() > 0.5
      ? Colors.black.withValues(alpha: 0.25)
      : Colors.white.withValues(alpha: 0.35);
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

class SnapgroveApp extends StatefulWidget {
  const SnapgroveApp({super.key});

  @override
  State<SnapgroveApp> createState() => _SnapgroveAppState();
}

class _SnapgroveAppState extends State<SnapgroveApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snapgrove',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: LandingPage(onThemeChanged: _setThemeMode, currentTheme: _themeMode),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: false,
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

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: false,
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

class LandingPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentTheme;

  const LandingPage({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _menuOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggleMenu() {
    if (_menuOpen) {
      _removeMenu();
    } else {
      _showMenu();
    }
  }

  void _showMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _menuOpen = true);
  }

  void _removeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _menuOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final sc = context.snapgroveColors;
    final width = MediaQuery.of(context).size.width;

    double menuWidth;
    if (width >= 1100) {
      menuWidth = 240;
    } else if (width >= 720) {
      menuWidth = 220;
    } else {
      menuWidth = 200;
    }

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => _removeMenu(),
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 10),
              child: Container(
                width: menuWidth,
                decoration: BoxDecoration(
                  color: sc.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                  border: Border.all(color: sc.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MenuButton(
                          icon: Icons.palette,
                          label: 'Themes',
                          onTap: () {
                            _removeMenu();
                            _showThemeDialog();
                          },
                        ),
                        _MenuButton(
                          icon: Icons.shield,
                          label: 'Privacy Policy',
                          onTap: () => _removeMenu(),
                        ),
                        _MenuButton(
                          icon: Icons.info_outline,
                          label: 'About',
                          onTap: () => _removeMenu(),
                        ),
                        _MenuButton(
                          icon: Icons.code,
                          label: 'Source code',
                          onTap: () => _removeMenu(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showThemeDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
      builder: (ctx) {
        return ThemeDialog(
          currentTheme: widget.currentTheme,
          onThemeChanged: widget.onThemeChanged,
        );
      },
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final size = MediaQuery.of(context).size;
    final width = size.width;

    double contentMax;
    if (width >= 1100) {
      contentMax = 760;
    } else if (width >= 720) {
      contentMax = 640;
    } else {
      contentMax = 520;
    }

    final double hPadding = (width * 0.05).clamp(18.0, 36.0);
    final double vPaddingTop = (width * 0.05).clamp(20.0, width >= 1100 ? 48.0 : 40.0);
    final double vPaddingBottom = (width * 0.06).clamp(28.0, 56.0);

    final double iconBtnSize = (width * 0.07).clamp(36.0, 44.0);
    final double iconSize = (width * 0.038).clamp(18.0, 24.0);

    final double instructionFontSize = (width * 0.046).clamp(18.0, 26.0);
    final double actionFontSize = (width * 0.032).clamp(14.0, 18.0);
    final double buttonIconSize = (width * 0.048).clamp(22.0, 28.0);

    final double actionGap = (width * 0.03).clamp(14.0, width >= 1100 ? 20.0 : 18.0);

    final double browsePaddingH = (width * 0.06).clamp(22.0, 32.0);
    final double browsePaddingV = (width * 0.026).clamp(12.0, 16.0);
    final double ssPaddingH = (width * 0.04).clamp(18.0, 24.0);
    final double ssPaddingV = (width * 0.03).clamp(14.0, 18.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: contentMax),
            padding: EdgeInsets.fromLTRB(hPadding, vPaddingTop, hPadding, vPaddingBottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  iconBtnSize: iconBtnSize,
                  iconSize: iconSize,
                  layerLink: _layerLink,
                  onMoreTap: _toggleMenu,
                ),
                const SizedBox(height: 4),
                _Brand(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Tap to move screenshots into folders (tags) instantly.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: instructionFontSize,
                          height: 1.35,
                          color: sc.muted,
                          fontFamily: 'Lora',
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _BrowseButton(
                        actionFontSize: actionFontSize,
                        buttonIconSize: buttonIconSize,
                        browsePaddingH: browsePaddingH,
                        browsePaddingV: browsePaddingV,
                      ),
                      SizedBox(height: actionGap),
                      _ScreenshotButton(
                        actionFontSize: actionFontSize,
                        buttonIconSize: buttonIconSize,
                        ssPaddingH: ssPaddingH,
                        ssPaddingV: ssPaddingV,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final double iconBtnSize;
  final double iconSize;
  final LayerLink layerLink;
  final VoidCallback onMoreTap;

  const _TopBar({
    required this.iconBtnSize,
    required this.iconSize,
    required this.layerLink,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CompositedTransformTarget(
      link: layerLink,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: iconBtnSize,
            height: iconBtnSize,
            child: Ink(
              decoration: BoxDecoration(
                color: sc.iconBg,
                shape: BoxShape.circle,
                border: Border.all(color: sc.iconBorder),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onMoreTap,
                splashColor: sc.rippleColor,
                child: Center(
                  child: Icon(
                    Icons.more_horiz,
                    size: iconSize,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 180,
          maxWidth: 280,
        ),
        child: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo-black.png',
          width: 280,
        ),
      ),
    );
  }
}

class _BrowseButton extends StatelessWidget {
  final double actionFontSize;
  final double buttonIconSize;
  final double browsePaddingH;
  final double browsePaddingV;

  const _BrowseButton({
    required this.actionFontSize,
    required this.buttonIconSize,
    required this.browsePaddingH,
    required this.browsePaddingV,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    return Ink(
      decoration: BoxDecoration(
        color: sc.primaryBtnBg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {},
        splashColor: _rippleColor(sc.primaryBtnBg),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: browsePaddingH,
            vertical: browsePaddingV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.drive_folder_upload,
                size: buttonIconSize,
                color: sc.primaryBtnText,
              ),
              SizedBox(width: actionFontSize * 0.67),
              Text(
                'Browse',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: actionFontSize,
                  letterSpacing: 0.2,
                  color: sc.primaryBtnText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenshotButton extends StatelessWidget {
  final double actionFontSize;
  final double buttonIconSize;
  final double ssPaddingH;
  final double ssPaddingV;

  const _ScreenshotButton({
    required this.actionFontSize,
    required this.buttonIconSize,
    required this.ssPaddingH,
    required this.ssPaddingV,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    return Ink(
      decoration: BoxDecoration(
        color: sc.accent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () {},
        splashColor: _rippleColor(sc.accent),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: ssPaddingH,
            vertical: ssPaddingV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.grid_view,
                size: buttonIconSize,
                color: const Color(0xFF000000),
              ),
              SizedBox(width: actionFontSize * 0.67),
              Text(
                'Screenshot Folder',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: actionFontSize,
                  letterSpacing: 0.2,
                  color: const Color(0xFF000000),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = isDark ? Colors.white : Colors.black;
    final sc = context.snapgroveColors;
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: sc.menuHover,
        splashColor: sc.rippleColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeDialog extends StatefulWidget {
  final ThemeMode currentTheme;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ThemeDialog({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends State<ThemeDialog> {
  late ThemeMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentTheme;
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: screenWidth * 0.92 > 360 ? 360 : screenWidth * 0.92,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: sc.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Theme',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeOption(
                              icon: Icons.desktop_windows,
                              label: 'System',
                              isActive: _selected == ThemeMode.system,
                              onTap: () => _selectTheme(ThemeMode.system),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _ThemeOption(
                              icon: Icons.light_mode,
                              label: 'Light',
                              isActive: _selected == ThemeMode.light,
                              onTap: () => _selectTheme(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _ThemeOption(
                              icon: Icons.dark_mode,
                              label: 'Dark',
                              isActive: _selected == ThemeMode.dark,
                              onTap: () => _selectTheme(ThemeMode.dark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectTheme(ThemeMode mode) {
    setState(() => _selected = mode);
    widget.onThemeChanged(mode);
    Navigator.of(context).pop();
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final Color bgColor = isActive ? sc.primaryBtnBg : sc.surfaceMuted;
    final Color fgColor = isActive ? sc.primaryBtnText : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black);
    return Ink(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        splashColor: _rippleColor(bgColor),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fgColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  letterSpacing: 0.2,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension SnapgroveContext on BuildContext {
  SnapgroveColors get snapgroveColors => Theme.of(this).extension<SnapgroveColors>()!;
}

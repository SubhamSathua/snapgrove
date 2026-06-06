import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(const SnapgroveApp());
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
    return OverlayEntry(
      builder: (context) {
        return GestureDetector(
          onTap: () => _removeMenu(),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.transparent),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: const Offset(-18, 56),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
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
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 200),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MenuButton(
                            iconPath: 'assets/icons/palette.svg',
                            label: 'Themes',
                            onTap: () {
                              _removeMenu();
                              _showThemeDialog();
                            },
                          ),
                          _MenuButton(
                            iconPath: 'assets/icons/shield.svg',
                            label: 'Privacy Policy',
                            onTap: () => _removeMenu(),
                          ),
                          _MenuButton(
                            iconPath: 'assets/icons/info-circle.svg',
                            label: 'About',
                            onTap: () => _removeMenu(),
                          ),
                          _MenuButton(
                            iconPath: 'assets/icons/github.svg',
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
          ),
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
    _removeMenu();
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
          GestureDetector(
            onTap: onMoreTap,
            child: Container(
              width: iconBtnSize,
              height: iconBtnSize,
              decoration: BoxDecoration(
                color: sc.iconBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: sc.iconBorder,
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/more.svg',
                          width: iconSize,
                          height: iconSize,
                          colorFilter: ColorFilter.mode(
                            isDark ? Colors.white : Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onMoreTap,
                          splashColor: sc.rippleColor,
                        ),
                      ),
                    ),
                  ],
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
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: browsePaddingH,
          vertical: browsePaddingV,
        ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/browse.svg',
              width: buttonIconSize,
              height: buttonIconSize,
              colorFilter: ColorFilter.mode(
                sc.primaryBtnText,
                BlendMode.srcIn,
              ),
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
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: ssPaddingH,
          vertical: ssPaddingV,
        ),
        decoration: BoxDecoration(
          color: sc.accent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/screenshot.svg',
              width: buttonIconSize,
              height: buttonIconSize,
              colorFilter: const ColorFilter.mode(
                Color(0xFF000000),
                BlendMode.srcIn,
              ),
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
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String iconPath;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.iconPath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: sc.menuHover,
          splashColor: sc.rippleColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    isDark ? Colors.white : Colors.black,
                    BlendMode.srcIn,
                  ),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    return Center(
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
                      iconPath: 'assets/icons/desktop.svg',
                      label: 'System',
                      isActive: _selected == ThemeMode.system,
                      isDark: isDark,
                      onTap: () => _selectTheme(ThemeMode.system),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _ThemeOption(
                      iconPath: 'assets/icons/sun.svg',
                      label: 'Light',
                      isActive: _selected == ThemeMode.light,
                      isDark: isDark,
                      onTap: () => _selectTheme(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _ThemeOption(
                      iconPath: 'assets/icons/moon.svg',
                      label: 'Dark',
                      isActive: _selected == ThemeMode.dark,
                      isDark: isDark,
                      onTap: () => _selectTheme(ThemeMode.dark),
                    ),
                  ),
                ],
              ),
            ],
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
  final String iconPath;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.iconPath,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.transparent : sc.surfaceMuted,
          borderRadius: BorderRadius.circular(5),
        ),
        child: isActive
            ? Material(
                color: sc.primaryBtnBg,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: _buildContent(sc),
                ),
              )
            : _buildContent(sc),
      ),
    );
  }

  Widget _buildContent(SnapgroveColors sc) {
    final effectiveIsDark = isActive ? sc.primaryBtnBg == const Color(0xFF000000) : isDark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          iconPath,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            isActive
                ? sc.primaryBtnText
                : (effectiveIsDark ? Colors.white : Colors.black),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            letterSpacing: 0.2,
            color: isActive ? sc.primaryBtnText : null,
          ),
        ),
      ],
    );
  }
}

extension SnapgroveContext on BuildContext {
  SnapgroveColors get snapgroveColors => Theme.of(this).extension<SnapgroveColors>()!;
}

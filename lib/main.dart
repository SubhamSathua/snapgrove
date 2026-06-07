import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/storage_service.dart';
import 'services/picker_service.dart';

late StorageService storage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  storage = StorageService();
  await storage.init();

  runApp(const SnapgroveApp());
}

Color _rippleColor(Color bg) {
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

class SnapgroveApp extends StatefulWidget {
  const SnapgroveApp({super.key});

  @override
  State<SnapgroveApp> createState() => _SnapgroveAppState();
}

class _SnapgroveAppState extends State<SnapgroveApp> {
  ThemeMode _themeMode = ThemeMode.system;
  String? _screenshotDir;
  String? _permanentScreenshotDir;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final mode = await storage.getThemeMode();
    final dir = await storage.getScreenshotDir();
    final permDir = await storage.getPermanentScreenshotDir();
    if (mounted) {
      setState(() {
        _themeMode = mode;
        _screenshotDir = dir;
        _permanentScreenshotDir = permDir;
      });
    }
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    storage.saveThemeMode(mode);
  }

  void _setScreenshotDir(String path) {
    setState(() => _screenshotDir = path);
    storage.saveScreenshotDir(path);
  }

  void _setPermanentScreenshotDir(String path) {
    setState(() => _permanentScreenshotDir = path);
    storage.savePermanentScreenshotDir(path);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness platformBrightness =
        View.of(context).platformDispatcher.platformBrightness;
    final bool isDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && platformBrightness == Brightness.dark);
    final theme = isDark ? _buildDarkTheme() : _buildLightTheme();

    return MaterialApp(
      title: 'Snapgrove',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      builder: (context, child) {
        return AnimatedTheme(
          data: theme,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutQuart,
          child: child!,
        );
      },
      home: Stack(
        children: [
          BackgroundCurtain(themeMode: _themeMode),
          LandingPage(
            onThemeChanged: _setThemeMode,
            currentTheme: _themeMode,
            screenshotDir: _screenshotDir,
            onDirChanged: _setScreenshotDir,
            permanentScreenshotDir: _permanentScreenshotDir,
            onPermanentDirChanged: _setPermanentScreenshotDir,
          ),
        ],
      ),
    );
  }

  ThemeData _buildLightTheme() {
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

  ThemeData _buildDarkTheme() {
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

class LandingPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentTheme;
  final String? screenshotDir;
  final ValueChanged<String> onDirChanged;
  final String? permanentScreenshotDir;
  final ValueChanged<String> onPermanentDirChanged;

  const LandingPage({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
    this.screenshotDir,
    required this.onDirChanged,
    this.permanentScreenshotDir,
    required this.onPermanentDirChanged,
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

  Future<void> _openScreenshotFolder() async {
    // Check for null or empty path to trigger modal
    // Now uses permanentScreenshotDir which is independent of temporary Browse
    if (widget.permanentScreenshotDir == null || widget.permanentScreenshotDir!.isEmpty) {
      debugPrint('LOG: Permanent screenshot dir is unset, showing prompt...');
      _showFolderPromptDialog();
      return;
    }

    debugPrint('LOG: Opening saved permanent folder: ${widget.permanentScreenshotDir}');
    final Uri uri = Uri.directory(widget.permanentScreenshotDir!);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(Uri.parse('file://${widget.permanentScreenshotDir}'));
      }
    } catch (e) {
      debugPrint('Could not open folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open folder automatically.')),
        );
      }
    }
  }

  void _showFolderPromptDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.2),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => FolderPromptDialog(
        onChoose: () async {
          // Open picker first while modal is still the active window
          debugPrint('LOG: Triggering picker from modal...');
          final dir = await PickerService.pickDirectory();
          
          if (dir != null) {
            debugPrint('LOG: Permanent Folder selected: $dir');
            // Update the PERMANENT directory state
            widget.onPermanentDirChanged(dir);
            // Small delay so user sees feedback if any (though here we just close)
            await Future.delayed(const Duration(milliseconds: 200));
          }
          
          if (mounted) Navigator.of(context).pop();
        },
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  void _showMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _menuOpen = true);
  }

  void _removeMenuSync() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _menuOpen = false);
  }

  Future<void> _removeMenu() async {
    await Future.delayed(const Duration(milliseconds: 120));
    _removeMenuSync();
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
              onTap: () => _removeMenuSync(),
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
                          svgPath: 'assets/icons/palette.svg',
                          label: 'Themes',
                          onTap: () async {
                            await _removeMenu();
                            _showThemeDialog();
                          },
                        ),
                        _MenuButton(
                          svgPath: 'assets/icons/shield.svg',
                          label: 'Privacy Policy',
                          onTap: () => _removeMenu(),
                        ),
                        _MenuButton(
                          svgPath: 'assets/icons/info-circle.svg',
                          label: 'About',
                          onTap: () => _removeMenu(),
                        ),
                        _MenuButton(
                          svgPath: 'assets/icons/github.svg',
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.2),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => ThemeDialog(
        currentTheme: widget.currentTheme,
        onThemeChanged: widget.onThemeChanged,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + (0.1 * curve),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _removeMenuSync();
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
      backgroundColor: Colors.transparent,
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
                        currentDir: widget.screenshotDir,
                        onTap: () async {
                          final dir = await PickerService.pickDirectory();
                          if (dir != null) {
                            widget.onDirChanged(dir);
                          }
                        },
                      ),
                      SizedBox(height: actionGap),
                      if (kIsWeb)
                        _DownloadAppButton(
                          actionFontSize: actionFontSize,
                          buttonIconSize: buttonIconSize,
                          ssPaddingH: ssPaddingH,
                          ssPaddingV: ssPaddingV,
                        )
                      else
                        _ScreenshotButton(
                          actionFontSize: actionFontSize,
                          buttonIconSize: buttonIconSize,
                          ssPaddingH: ssPaddingH,
                          ssPaddingV: ssPaddingV,
                          onTap: _openScreenshotFolder,
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
                splashColor: _rippleColor(sc.iconBg),
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
    final width = MediaQuery.of(context).size.width;

    double percent;
    if (width >= 1100) {
      percent = 0.35;
    } else if (width >= 720) {
      percent = 0.50;
    } else {
      percent = 0.60;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SvgPicture.asset(
          isDark ? 'assets/icons/logo-white.svg' : 'assets/icons/logo-black.svg',
          width: width * percent,
          fit: BoxFit.contain,
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
  final VoidCallback onTap;
  final String? currentDir;

  const _BrowseButton({
    required this.actionFontSize,
    required this.buttonIconSize,
    required this.browsePaddingH,
    required this.browsePaddingV,
    required this.onTap,
    this.currentDir,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final hasDir = currentDir != null;
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
        onTap: onTap,
        splashColor: _rippleColor(sc.primaryBtnBg),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: browsePaddingH,
            vertical: browsePaddingV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                hasDir ? 'assets/icons/check.svg' : 'assets/icons/browse.svg',
                width: buttonIconSize,
                height: buttonIconSize,
                colorFilter: ColorFilter.mode(
                  sc.primaryBtnText,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: actionFontSize * 0.67),
              Text(
                hasDir ? 'Folder Selected' : 'Browse',
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
  final VoidCallback onTap;

  const _ScreenshotButton({
    required this.actionFontSize,
    required this.buttonIconSize,
    required this.ssPaddingH,
    required this.ssPaddingV,
    required this.onTap,
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
        onTap: onTap,
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
      ),
    );
  }
}

class _DownloadAppButton extends StatelessWidget {
  final double actionFontSize;
  final double buttonIconSize;
  final double ssPaddingH;
  final double ssPaddingV;

  const _DownloadAppButton({
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
        onTap: () {
          // Future: link to download page
        },
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
              SvgPicture.asset(
                'assets/icons/desktop.svg',
                width: buttonIconSize,
                height: buttonIconSize,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF000000),
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: actionFontSize * 0.67),
              Text(
                'Download App',
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

class FolderPromptDialog extends StatelessWidget {
  final VoidCallback onChoose;

  const FolderPromptDialog({super.key, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: screenWidth * 0.92 > 360 ? 360 : screenWidth * 0.92,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: sc.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
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
            children: [
              const Text(
                'Screenshot folder is not saved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please select the folder where your screenshots are saved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 14,
                  color: sc.muted,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'Cancel',
                      isPrimary: false,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DialogButton(
                      label: 'Choose',
                      isPrimary: true,
                      onTap: onChoose,
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
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;

    // Hardcoding colors for absolute perfection and visibility on Windows 11
    // Primary (Choose) is Solid Accent (Pink/Magenta) with Black text
    // Secondary (Cancel) is Transparent with reveal-on-hover
    final Color bgColor = isPrimary ? const Color(0xFFff2a7b) : Colors.transparent;
    final Color fgColor = isPrimary ? const Color(0xFF000000) : sc.muted;

    return Container(
      constraints: const BoxConstraints(minWidth: 100, minHeight: 40),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('UI: Dialog Button clicked: $label');
            onTap();
          },
          borderRadius: BorderRadius.circular(5),
          hoverColor: isPrimary 
              ? Colors.black.withValues(alpha: 0.1) 
              : sc.menuHover,
          splashColor: isPrimary 
              ? Colors.white.withValues(alpha: 0.2) 
              : sc.rippleColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String svgPath;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.svgPath,
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
        splashColor: _rippleColor(sc.surfaceElevated),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SvgPicture.asset(
                svgPath,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  iconColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Center(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Theme',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(999),
                              hoverColor: sc.menuHover,
                              splashColor: sc.rippleColor,
                              child: Center(
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: _selected == ThemeMode.system ? 16 : 10,
                            child: _ThemeOption(
                              svgPath: 'assets/icons/desktop.svg',
                              label: 'System',
                              isActive: _selected == ThemeMode.system,
                              onTap: () => _selectTheme(ThemeMode.system),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: _selected == ThemeMode.light ? 16 : 10,
                            child: _ThemeOption(
                              svgPath: 'assets/icons/sun.svg',
                              label: 'Light',
                              isActive: _selected == ThemeMode.light,
                              onTap: () => _selectTheme(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: _selected == ThemeMode.dark ? 16 : 10,
                            child: _ThemeOption(
                              svgPath: 'assets/icons/moon.svg',
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
          ],
        ),
      ),
    );
  }

  void _selectTheme(ThemeMode mode) {
    setState(() => _selected = mode);
    widget.onThemeChanged(mode);
  }
}

class _ThemeOption extends StatefulWidget {
  final String svgPath;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.svgPath,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ThemeOption> createState() => _ThemeOptionState();
}

class _ThemeOptionState extends State<_ThemeOption>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.96), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.02), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_ThemeOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = widget.isActive ? sc.primaryBtnBg : sc.surfaceMuted;
    final Color fgColor = widget.isActive
        ? sc.primaryBtnText
        : (isDark ? Colors.white : Colors.black);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: widget.onTap,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: sc.rippleColor,
            focusColor: sc.rippleColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    widget.svgPath,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      fgColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                        color: fgColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension SnapgroveContext on BuildContext {
  SnapgroveColors get snapgroveColors => Theme.of(this).extension<SnapgroveColors>()!;
}

class BackgroundCurtain extends StatefulWidget {
  final ThemeMode themeMode;

  const BackgroundCurtain({super.key, required this.themeMode});

  @override
  State<BackgroundCurtain> createState() => _BackgroundCurtainState();
}

class _BackgroundCurtainState extends State<BackgroundCurtain> {
  Color? _baseColor;
  Color? _curtainColor;
  bool _isAnimating = false;

  @override
  void didUpdateWidget(BackgroundCurtain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.themeMode != oldWidget.themeMode) {
      final Brightness platformBrightness =
          View.of(context).platformDispatcher.platformBrightness;

      final bool oldWasDark = oldWidget.themeMode == ThemeMode.dark ||
          (oldWidget.themeMode == ThemeMode.system &&
              platformBrightness == Brightness.dark);
      final bool newIsDark = widget.themeMode == ThemeMode.dark ||
          (widget.themeMode == ThemeMode.system &&
              platformBrightness == Brightness.dark);

      if (oldWasDark != newIsDark) {
        _baseColor = oldWasDark ? const Color(0xFF000000) : const Color(0xFFffffff);
        _curtainColor = newIsDark ? const Color(0xFF000000) : const Color(0xFFffffff);
        _isAnimating = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness platformBrightness =
        View.of(context).platformDispatcher.platformBrightness;
    final bool isDark = widget.themeMode == ThemeMode.dark ||
        (widget.themeMode == ThemeMode.system && platformBrightness == Brightness.dark);
    final Color currentColor =
        isDark ? const Color(0xFF000000) : const Color(0xFFffffff);

    if (!_isAnimating) {
      return Container(color: currentColor);
    }

    return Stack(
      children: [
        Container(color: _baseColor),
        TweenAnimationBuilder<double>(
          key: ValueKey(widget.themeMode),
          tween: Tween<double>(begin: -1.0, end: 0.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuart,
          onEnd: () => setState(() => _isAnimating = false),
          builder: (context, value, child) {
            return FractionalTranslation(
              translation: Offset(0, value),
              child: Container(color: _curtainColor),
            );
          },
        ),
      ],
    );
  }
}

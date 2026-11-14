import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:animations/animations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../viewmodels/app_view_model.dart';
import '../services/picker_service.dart';
import '../services/settings_service.dart';
import '../core/locator.dart';
import '../theme/app_theme.dart';
import '../theme/app_blur.dart';
import '../theme/snap_symbols.dart';
import 'gallery_view.dart';
import 'bin_view.dart';
import 'settings_view.dart';
import 'theme_dialog.dart';
import 'privacy_policy_view.dart';
import 'licenses_view.dart';
import 'source_code_view.dart';
import 'about_view.dart';

class LandingPage extends StatefulWidget {
  final AppViewModel viewModel;

  const LandingPage({
    super.key,
    required this.viewModel,
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

  void _showFolderPromptDialog({VoidCallback? onSuccess}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.2),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => FolderPromptDialog(
        onChoose: () async {
          debugPrint('LOG: Triggering picker from modal...');
          final dir = await PickerService.pickDirectory();
          
          if (dir != null) {
            debugPrint('LOG: Permanent Folder selected: $dir');
            widget.viewModel.setPermanentScreenshotDir(dir);
            
            if (mounted) Navigator.of(context).pop();
            
            if (onSuccess != null) {
              Future.delayed(const Duration(milliseconds: 300), onSuccess);
            }
          } else {
            if (mounted) Navigator.of(context).pop();
          }
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

  void _navigateTo(Widget page) async {
    await _removeMenu();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openWindowsRecycleBin() async {
    await _removeMenu();
    try {
      await Process.run('explorer.exe', ['shell:RecycleBinFolder']);
    } catch (e) {
      debugPrint('Error opening Windows Recycle Bin: $e');
    }
  }

  Future<void> _openBinWithAuth() async {
    await _removeMenu();
    if (!mounted) return;

    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (isWindows) {
      await _openWindowsRecycleBin();
      return;
    }

    final settings = locator<SettingsService>();
    final binAuthEnabled = settings.binAuthEnabled;
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    final isPc = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);

    // ── Android / iOS Auth Flow ──────────────────────────────────────────────
    if (binAuthEnabled && isMobile) {
      try {
        final auth = LocalAuthentication();
        final isDeviceSupported = await auth.isDeviceSupported();
        final canCheckBiometrics = await auth.canCheckBiometrics;

        if (!isDeviceSupported && !canCheckBiometrics) {
          // No device pass / screen lock exists
          if (!mounted) return;
          final proceed = await _showNoScreenLockDialog();
          if (!proceed) return;
        } else {
          try {
            final authenticated = await auth.authenticate(
              localizedReason: 'Authenticate to access Bin',
              options: const AuthenticationOptions(
                stickyAuth: true,
                biometricOnly: false,
              ),
            );
            if (!authenticated) {
              return; // Cancelled or failed -> stay on landing page
            }
          } on PlatformException catch (e) {
            debugPrint('LocalAuth PlatformException: ${e.code} ${e.message}');
            if (!mounted) return;
            final proceed = await _showNoScreenLockDialog();
            if (!proceed) return;
          }
        }
      } on PlatformException catch (e) {
        debugPrint('LocalAuth PlatformException: ${e.code} ${e.message}');
        if (!mounted) return;
        final proceed = await _showNoScreenLockDialog();
        if (!proceed) return;
      } catch (e) {
        debugPrint('Biometrics auth error: $e');
        return;
      }
    }

    // ── PC Password Auth Flow ────────────────────────────────────────────────
    if (binAuthEnabled && isPc) {
      if (settings.isBinPasswordSet) {
        if (!mounted) return;
        final authenticated = await _showPcBinPasswordPrompt();
        if (!authenticated) return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BinView(
          targetDirectory: widget.viewModel.screenshotDir ?? widget.viewModel.permanentScreenshotDir,
        ),
      ),
    );
  }

  Future<bool> _showNoScreenLockDialog() async {
    return await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'NoScreenLock',
      barrierColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.25,
      ),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) => const _NoScreenLockDialog(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + 0.1 * curve,
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    ) ?? false;
  }

  Future<bool> _showPcBinPasswordPrompt() async {
    return await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'BinPassword',
      barrierColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.25,
      ),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) => _PcBinPasswordPromptDialog(
        settings: locator<SettingsService>(),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.9 + 0.1 * curve,
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    ) ?? false;
  }

  OverlayEntry _createOverlayEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;

    double menuWidth;
    if (width >= 1100) {
      menuWidth = 250;
    } else if (width >= 720) {
      menuWidth = 245;
    } else {
      menuWidth = (width - 32.0).clamp(200.0, 240.0);
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
                  child: Container(
                    width: menuWidth,
                    decoration: BoxDecoration(
                      color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!kIsWeb)
                              if (defaultTargetPlatform == TargetPlatform.windows)
                                _MenuButton(
                                  svgPath: 'assets/icons/trash.svg',
                                  label: 'Windows Recycle Bin',
                                  onTap: _openWindowsRecycleBin,
                                )
                              else
                                _MenuButton(
                                  svgPath: 'assets/icons/trash.svg',
                                  label: 'Bin',
                                  onTap: _openBinWithAuth,
                                ),
                            _MenuButton(
                              icon: SnapSymbols.settings_outlined,
                              label: 'Settings',
                              onTap: () => _navigateTo(const SettingsView()),
                            ),
                            _MenuButton(
                              svgPath: 'assets/icons/palette.svg',
                              label: 'Theme',
                              onTap: () async {
                                await _removeMenu();
                                _showThemeDialog();
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                              ),
                            ),
                            _MenuButton(
                              svgPath: 'assets/icons/shield.svg',
                              label: 'Privacy Policy',
                              onTap: () => _navigateTo(const PrivacyPolicyView()),
                            ),
                            _MenuButton(
                              svgPath: 'assets/icons/github.svg',
                              label: 'Source code',
                              onTap: () => _navigateTo(const SourceCodeView()),
                            ),
                            _MenuButton(
                              svgPath: 'assets/icons/license.svg',
                              label: 'Open source license',
                              onTap: () => _navigateTo(const LicensesView()),
                            ),
                            _MenuButton(
                              svgPath: 'assets/icons/info-circle.svg',
                              label: 'About',
                              onTap: () => _navigateTo(const AboutView()),
                            ),
                          ],
                        ),
                      ),
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
        currentTheme: widget.viewModel.themeMode,
        onThemeChanged: widget.viewModel.setThemeMode,
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
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, vPaddingBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _TopBar(
                  iconBtnSize: iconBtnSize,
                  iconSize: iconSize,
                  layerLink: _layerLink,
                  onMoreTap: _toggleMenu,
                ),
              ),
              SizedBox(height: width > 720 ? 30 : 20),
              Align(
                alignment: Alignment.topLeft,
                child: const _Brand(),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: contentMax),
                    child: Text(
                      'Tap to move screenshots into folders (tags) instantly.',
                      textAlign: TextAlign.center,
                      maxLines: width > 720 ? 1 : null,
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
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OpenContainer(
                        closedElevation: 0,
                        openElevation: 0,
                        closedColor: Colors.transparent,
                        openColor: Theme.of(context).scaffoldBackgroundColor,
                        transitionType: ContainerTransitionType.fadeThrough,
                        transitionDuration: const Duration(milliseconds: 600),
                        openBuilder: (context, action) => OrganizerGallery(
                          path: widget.viewModel.screenshotDir ?? '',
                          title: 'Browse Gallery',
                        ),
                        closedBuilder: (context, action) => Center(
                          child: _BrowseButton(
                            actionFontSize: actionFontSize,
                            buttonIconSize: buttonIconSize,
                            browsePaddingH: browsePaddingH,
                            browsePaddingV: browsePaddingV,
                            onTap: () async {
                              final dir = await PickerService.pickDirectory();
                              if (dir != null) {
                                widget.viewModel.setScreenshotDir(dir);
                                Future.delayed(const Duration(milliseconds: 100), action);
                              }
                            },
                          ),
                        ),
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
                        OpenContainer(
                          closedElevation: 0,
                          openElevation: 0,
                          closedColor: Colors.transparent,
                          openColor: Theme.of(context).scaffoldBackgroundColor,
                          transitionType: ContainerTransitionType.fadeThrough,
                          transitionDuration: const Duration(milliseconds: 600),
                          openBuilder: (context, action) => OrganizerGallery(
                            path: widget.viewModel.permanentScreenshotDir ?? '',
                            title: 'Screenshot Folder',
                          ),
                          closedBuilder: (context, action) => _ScreenshotButton(
                            actionFontSize: actionFontSize,
                            buttonIconSize: buttonIconSize,
                            ssPaddingH: ssPaddingH,
                            ssPaddingV: ssPaddingV,
                            onTap: () {
                              if (widget.viewModel.permanentScreenshotDir == null ||
                                  widget.viewModel.permanentScreenshotDir!.isEmpty) {
                                _showFolderPromptDialog(onSuccess: action);
                              } else {
                                action();
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
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
      child: SizedBox(
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
            splashColor: rippleColor(sc.iconBg),
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
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    double logoWidth;
    if (isAndroid) {
      logoWidth = (width * 0.60).clamp(0.0, 360.0);
    } else {
      double percent;
      if (width >= 1100) {
        percent = 0.20;
      } else if (width >= 720) {
        percent = 0.35;
      } else {
        percent = 0.50;
      }
      logoWidth = (width * percent).clamp(0.0, 300.0) + 20.0;
    }

    return SvgPicture.asset(
      isDark ? 'assets/icons/logo-white.svg' : 'assets/icons/logo-black.svg',
      width: logoWidth,
      fit: BoxFit.contain,
    );
  }
}

class _BrowseButton extends StatelessWidget {
  final double actionFontSize;
  final double buttonIconSize;
  final double browsePaddingH;
  final double browsePaddingV;
  final VoidCallback onTap;

  const _BrowseButton({
    required this.actionFontSize,
    required this.buttonIconSize,
    required this.browsePaddingH,
    required this.browsePaddingV,
    required this.onTap,
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
        onTap: onTap,
        splashColor: rippleColor(sc.primaryBtnBg),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: browsePaddingH,
            vertical: browsePaddingV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
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
        splashColor: rippleColor(sc.accent),
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

class _DownloadAppButton extends StatefulWidget {
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
  State<_DownloadAppButton> createState() => _DownloadAppButtonState();
}

class _DownloadAppButtonState extends State<_DownloadAppButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final Color bgColor = _isHovered ? const Color(0xFF2fad5c) : sc.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () {
              // Future: link to download page
            },
            hoverColor: Colors.transparent,
            splashColor: rippleColor(bgColor),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: widget.ssPaddingH,
                vertical: widget.ssPaddingV,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/download.svg',
                    width: widget.buttonIconSize,
                    height: widget.buttonIconSize,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF000000),
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: widget.actionFontSize * 0.67),
                  Text(
                    'Download App',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: widget.actionFontSize,
                      letterSpacing: 0.2,
                      color: const Color(0xFF000000),
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

class FolderPromptDialog extends StatelessWidget {
  final VoidCallback onChoose;

  const FolderPromptDialog({super.key, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
            child: Container(
              width: screenWidth * 0.92 > 360 ? 360 : screenWidth * 0.92,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.80)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
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
    ),
  ),
);
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;
  final Color? colorOverride;
  final Color? textColorOverride;

  const _DialogButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
    this.colorOverride,
    this.textColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final Color bgColor = colorOverride ?? (isPrimary ? const Color(0xFFff2a7b) : Colors.transparent);
    final Color fgColor = textColorOverride ?? (isPrimary ? const Color(0xFF000000) : sc.muted);

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
  final String? svgPath;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    this.svgPath,
    this.icon,
    required this.label,
    required this.onTap,
  }) : assert(svgPath != null || icon != null);

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
        splashColor: rippleColor(sc.surfaceElevated),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (svgPath != null)
                SvgPicture.asset(
                  svgPath!,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    iconColor,
                    BlendMode.srcIn,
                  ),
                )
              else if (icon != null)
                Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Android: No Screen Lock Warning Dialog ───────────────────────────────────

class _NoScreenLockDialog extends StatelessWidget {
  const _NoScreenLockDialog();

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
            child: Container(
              width: screenWidth * 0.92 > 360 ? 360 : screenWidth * 0.92,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.85)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Yellow warning indicator
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        SnapSymbols.lock_open_rounded,
                        color: Color(0xFFF59E0B),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Screen Lock Set Up',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your device does not have a screen lock (PIN, pattern, or biometric) configured. Please set up a screen lock in Android Settings to secure your Bin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 13.5,
                      height: 1.45,
                      color: sc.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DialogButton(
                        label: 'Set Up in Settings',
                        isPrimary: true,
                        colorOverride: const Color(0xFFF59E0B),
                        textColorOverride: Colors.black,
                        onTap: () async {
                          Navigator.of(context).pop(false);
                          try {
                            final uri = Uri.parse('android.settings.SECURITY_SETTINGS');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              await launchUrl(Uri.parse('android.settings.SETTINGS'));
                            }
                          } catch (_) {}
                        },
                      ),
                      const SizedBox(height: 8),
                      _DialogButton(
                        label: 'Continue Anyway',
                        isPrimary: false,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ],
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

// ── PC: Bin Password Prompt Dialog ───────────────────────────────────────────

class _PcBinPasswordPromptDialog extends StatefulWidget {
  final SettingsService settings;

  const _PcBinPasswordPromptDialog({required this.settings});

  @override
  State<_PcBinPasswordPromptDialog> createState() => _PcBinPasswordPromptDialogState();
}

class _PcBinPasswordPromptDialogState extends State<_PcBinPasswordPromptDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _hasError = false;
  bool _showHint = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final entered = _passwordController.text;
    if (widget.settings.verifyBinPassword(entered)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.snapgroveColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final hint = widget.settings.binPasswordHint;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: AppBlur.filter(sigmaX: 20, sigmaY: 20)!,
            child: Container(
              width: screenWidth * 0.92 > 380 ? 380 : screenWidth * 0.92,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppBlur.getBackgroundColor((isDark ? const Color(0xFF1E1E1E) : Colors.white).withValues(alpha: 0.85)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(SnapSymbols.lock_rounded, size: 20, color: sc.accent),
                      const SizedBox(width: 10),
                      Text(
                        'Bin Authentication',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter your Bin password to access deleted screenshots.',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 13,
                      color: sc.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _hasError
                            ? const Color(0xFFE53935)
                            : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _passwordController,
                            autofocus: true,
                            obscureText: _obscureText,
                            onChanged: (_) {
                              if (_hasError) setState(() => _hasError = false);
                            },
                            onSubmitted: (_) => _submit(),
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter password',
                              hintStyle: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 13,
                                color: sc.muted.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _obscureText ? SnapSymbols.visibility_off_outlined : SnapSymbols.visibility_outlined,
                            size: 18,
                            color: sc.muted,
                          ),
                          onPressed: () => setState(() => _obscureText = !_obscureText),
                        ),
                      ],
                    ),
                  ),
                  if (_hasError) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Incorrect password. Please try again.',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (hint != null && hint.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _showHint = !_showHint),
                      child: Row(
                        children: [
                          Icon(
                            SnapSymbols.help_outline_rounded,
                            size: 14,
                            color: sc.muted.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showHint ? 'Hint: $hint' : 'Show Hint',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              color: _showHint ? sc.accent : sc.muted.withValues(alpha: 0.8),
                              fontWeight: _showHint ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogButton(
                          label: 'Cancel',
                          isPrimary: false,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DialogButton(
                          label: 'Unlock',
                          isPrimary: true,
                          onTap: _submit,
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
    );
  }
}




import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/locator.dart';
import '../theme/app_blur.dart';
import '../theme/app_theme.dart';
import '../viewmodels/app_view_model.dart';

class ThemeDialog extends StatelessWidget {
  final ThemeMode currentTheme;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ThemeDialog({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appVM = locator<AppViewModel>();
    final screenWidth = MediaQuery.of(context).size.width;

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
                child: ListenableBuilder(
                  listenable: appVM,
                  builder: (context, _) {
                    final sc = context.snapgroveColors;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final selected = appVM.themeMode;

                    return AppBlur(
                      borderRadius: BorderRadius.circular(14),
                      sigmaX: 20,
                      sigmaY: 20,
                      solidColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      blurOpacity: 0.80,
                      width: screenWidth * 0.92 > 360 ? 360 : screenWidth * 0.92,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
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
                                  fontWeight: FontWeight.w700,
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
                                  mouseCursor: SystemMouseCursors.click,
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
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: selected == ThemeMode.system ? 16 : 10,
                                child: _ThemeOption(
                                  svgPath: 'assets/icons/desktop.svg',
                                  label: 'System',
                                  isActive: selected == ThemeMode.system,
                                  onTap: () => onThemeChanged(ThemeMode.system),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: selected == ThemeMode.light ? 16 : 10,
                                child: _ThemeOption(
                                  svgPath: 'assets/icons/sun.svg',
                                  label: 'Light',
                                  isActive: selected == ThemeMode.light,
                                  onTap: () => onThemeChanged(ThemeMode.light),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: selected == ThemeMode.dark ? 16 : 10,
                                child: _ThemeOption(
                                  svgPath: 'assets/icons/moon.svg',
                                  label: 'Dark',
                                  isActive: selected == ThemeMode.dark,
                                  onTap: () => onThemeChanged(ThemeMode.dark),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            mouseCursor: SystemMouseCursors.click,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: sc.rippleColor,
            focusColor: sc.rippleColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    widget.svgPath,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(fgColor, BlendMode.srcIn),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
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

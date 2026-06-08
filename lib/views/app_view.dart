import 'package:flutter/material.dart';
import '../viewmodels/app_view_model.dart';
import '../theme/app_theme.dart';
import 'landing_page.dart';

class SnapgroveApp extends StatelessWidget {
  final AppViewModel viewModel;

  const SnapgroveApp({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        final Brightness platformBrightness =
            View.of(context).platformDispatcher.platformBrightness;
        final bool isDark = viewModel.themeMode == ThemeMode.dark ||
            (viewModel.themeMode == ThemeMode.system &&
                platformBrightness == Brightness.dark);
        final theme = isDark ? AppTheme.dark() : AppTheme.light();

        return MaterialApp(
          title: 'Snapgrove',
          debugShowCheckedModeBanner: false,
          themeMode: viewModel.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
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
              BackgroundCurtain(themeMode: viewModel.themeMode),
              LandingPage(viewModel: viewModel),
            ],
          ),
        );
      },
    );
  }
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

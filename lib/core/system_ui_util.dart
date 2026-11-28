import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'locator.dart';
import '../viewmodels/app_view_model.dart';

/// Utilities for managing system UI overlays (status bar and navigation bar).
class SystemUiUtil {
  /// Restores system UI overlays (status bar and navigation bar) on Android and other platforms.
  ///
  /// Calling [SystemUiMode.immersiveSticky] or [SystemUiMode.immersive] hides the
  /// system bars via native Android WindowInsets. In Flutter's Android embedding,
  /// calling only [SystemUiMode.edgeToEdge] does not explicitly re-show the bars.
  /// To reliably restore them, we first request [SystemUiMode.manual] with all
  /// [SystemUiOverlay.values], followed by [SystemUiMode.edgeToEdge].
  ///
  /// Re-applies [SystemUiOverlayStyle] so status bar icons adapt properly to the
  /// current theme (dark icons in light mode, light icons in dark mode).
  static Future<void> restoreSystemUI({bool? isDark}) async {
    try {
      final bool effectiveIsDark = isDark ?? (() {
        try {
          final appVM = locator<AppViewModel>();
          if (appVM.themeMode == ThemeMode.dark) return true;
          if (appVM.themeMode == ThemeMode.light) return false;
          return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
        } catch (_) {
          return false;
        }
      })();

      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: effectiveIsDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: effectiveIsDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: effectiveIsDark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } catch (_) {}
  }
}

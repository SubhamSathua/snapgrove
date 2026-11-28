import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/locator.dart';
import '../services/settings_service.dart';

/// A reusable frosted-glass surface widget and helper.
///
/// When blur is disabled (via [SettingsService.shouldDisableBlur]):
///  - [BackdropFilter] is completely omitted (or sigma is 0).
///  - Container background opacity is guaranteed to be 1.0 (fully solid, no translucency).
///
/// Can be used as a Widget:
/// ```dart
/// AppBlur(
///   borderRadius: BorderRadius.circular(14),
///   solidColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
///   blurOpacity: 0.80,
///   decoration: BoxDecoration(...),
///   child: ...,
/// )
/// ```
///
/// Or via static helpers:
/// ```dart
/// final disabled = AppBlur.isBlurDisabled;
/// final sigma = AppBlur.getSigma(20.0);
/// final color = AppBlur.getBackgroundColor(translucentColor);
/// ```
class AppBlur extends StatelessWidget {
  const AppBlur({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.sigmaX = 20.0,
    this.sigmaY = 20.0,
    this.color,
    this.solidColor,
    this.blurOpacity = 0.80,
    this.decoration,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double sigmaX;
  final double sigmaY;
  final Color? color;
  final Color? solidColor;
  final double blurOpacity;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final Clip clipBehavior;

  /// Returns true if blur is currently disabled.
  static bool get isBlurDisabled {
    try {
      return locator<SettingsService>().shouldDisableBlur();
    } catch (_) {
      return false;
    }
  }

  /// Returns 0.0 if blur is disabled, otherwise [sigma].
  static double getSigma(double sigma) => isBlurDisabled ? 0.0 : sigma;

  /// Returns an [ui.ImageFilter] with [sigmaX] and [sigmaY], or null (or sigma 0)
  /// if blur is disabled.
  static ui.ImageFilter? filter({double sigmaX = 20.0, double sigmaY = 20.0}) {
    if (isBlurDisabled) return ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0);
    return ui.ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY);
  }

  /// Returns fully opaque (alpha: 1.0) color if blur is disabled,
  /// otherwise returns [color].
  static Color getBackgroundColor(Color color, [Color? solidFallback]) {
    if (isBlurDisabled) {
      return (solidFallback ?? color).withValues(alpha: 1.0);
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    SettingsService? settings;
    try {
      settings = locator<SettingsService>();
    } catch (_) {}

    Widget buildSurface(bool blurDisabled) {
      Color effectiveColor;
      if (solidColor != null) {
        effectiveColor = blurDisabled
            ? solidColor!.withValues(alpha: 1.0)
            : solidColor!.withValues(alpha: blurOpacity);
      } else if (color != null) {
        effectiveColor = blurDisabled
            ? color!.withValues(alpha: 1.0)
            : color!;
      } else if (decoration?.color != null) {
        effectiveColor = blurDisabled
            ? decoration!.color!.withValues(alpha: 1.0)
            : decoration!.color!;
      } else {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final base = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        effectiveColor = blurDisabled ? base : base.withValues(alpha: blurOpacity);
      }

      final effectiveDecoration = (decoration ?? const BoxDecoration()).copyWith(
        color: effectiveColor,
        borderRadius: decoration?.borderRadius ?? borderRadius,
      );

      Widget container = Container(
        width: width,
        height: height,
        constraints: constraints,
        padding: padding,
        margin: margin,
        decoration: effectiveDecoration,
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );

      if (!blurDisabled && (sigmaX > 0 || sigmaY > 0)) {
        container = BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
          child: container,
        );
      }

      return ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: container,
      );
    }

    if (settings != null) {
      return ListenableBuilder(
        listenable: settings,
        builder: (context, _) => buildSurface(settings!.shouldDisableBlur()),
      );
    }

    return buildSurface(isBlurDisabled);
  }
}

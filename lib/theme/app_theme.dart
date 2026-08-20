import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Makes the token set (bg/surface/text/brass/ok/warn/danger) reachable as
/// `Theme.of(context).extension<AppColorsExtension>()!.colors` from any widget,
/// the same way the mockup's CSS scoped `--scr-*` custom properties per screen.
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension(this.colors);

  final AppColors colors;

  @override
  AppColorsExtension copyWith({AppColors? colors}) =>
      AppColorsExtension(colors ?? this.colors);

  @override
  AppColorsExtension lerp(
    ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColorsExtension>()!.colors;
}

class AppTheme {
  AppTheme._();

  static ThemeData _build(AppColors c, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      fontFamily: 'IBM Plex Sans',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.brass,
        onPrimary: c.bg,
        secondary: c.brass,
        onSecondary: c.bg,
        error: c.danger,
        onError: c.bg,
        surface: c.surface,
        onSurface: c.text,
      ),
      dividerColor: c.border,
      splashFactory: InkRipple.splashFactory,
      extensions: [AppColorsExtension(c)],
    );
  }

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);
}

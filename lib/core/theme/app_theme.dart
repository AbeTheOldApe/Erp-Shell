import 'package:flutter/material.dart';

/// Single source of [ThemeData] for the app.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF335CA8);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      fontFamily: 'Roboto',
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      extensions: const [AppSpacing()],
    );
  }
}

/// Spacing tokens, read with `Theme.of(context).extension<AppSpacing>()!`
/// or the [AppSpacingX] shortcut.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.menuWidth = 280,
    this.railWidth = 72,
    this.tabBarHeight = 48,
    this.tabMaxWidth = 220,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double menuWidth;
  final double railWidth;
  final double tabBarHeight;
  final double tabMaxWidth;

  @override
  AppSpacing copyWith() => this;

  @override
  AppSpacing lerp(AppSpacing? other, double t) => other ?? this;
}

extension AppSpacingX on BuildContext {
  AppSpacing get spacing =>
      Theme.of(this).extension<AppSpacing>() ?? const AppSpacing();
}

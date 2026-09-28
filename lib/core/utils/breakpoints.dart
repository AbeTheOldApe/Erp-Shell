import 'package:flutter/widgets.dart';

/// Material 3 window size classes.
enum WindowSizeClass { compact, medium, expanded }

/// Single source for responsive decisions. Widgets must not compare the
/// window width against literal numbers themselves.
abstract final class Breakpoints {
  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 1200;

  static WindowSizeClass classify(double width) {
    if (width >= expandedMinWidth) return WindowSizeClass.expanded;
    if (width >= mediumMinWidth) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  static WindowSizeClass of(BuildContext context) =>
      classify(MediaQuery.sizeOf(context).width);

  /// Maximum number of open tabs for a size class.
  static int tabLimit(WindowSizeClass sizeClass) => switch (sizeClass) {
    WindowSizeClass.compact => 5,
    WindowSizeClass.medium => 10,
    WindowSizeClass.expanded => 15,
  };
}

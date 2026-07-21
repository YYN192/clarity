import 'package:flutter/widgets.dart';

/// Single source of truth for responsive breakpoints across the app.
/// Branch layouts on WIDTH, never on platform — a desktop window can be
/// phone-narrow and a tablet can be desktop-wide.
enum ScreenType { phone, tablet, desktop }

class Breakpoints {
  Breakpoints._();

  /// >= this width is treated as a tablet.
  static const double tablet = 600;

  /// >= this width is treated as a desktop.
  static const double desktop = 1024;

  /// Cap single-column content width on large screens so it doesn't stretch
  /// edge-to-edge on web/desktop.
  static const double maxContentWidth = 720;
}

ScreenType screenTypeOf(double width) => width >= Breakpoints.desktop
    ? ScreenType.desktop
    : width >= Breakpoints.tablet
        ? ScreenType.tablet
        : ScreenType.phone;

/// Convenience for `screenTypeOf(MediaQuery.sizeOf(context).width)`.
ScreenType screenTypeContext(BuildContext context) =>
    screenTypeOf(MediaQuery.sizeOf(context).width);

/// Metric-grid column count for the current width.
int gridColumnsFor(double width) => switch (screenTypeOf(width)) {
      ScreenType.phone => 2,
      ScreenType.tablet => 3,
      ScreenType.desktop => 4,
    };

---
name: clarity-responsive
description: >-
  How to make Clarity UI adapt across every resolution and platform — phones,
  tablets, foldables, web, and desktop. Use whenever building or editing any
  layout, widget, or screen in this repo, and whenever you see fixed pixel sizes.
  Defines the breakpoint/sizing system to adopt, how to replace the app's current
  fixed-pixel debt (font sizes, height:600 blocks, magic `>600`), respect text
  scaling, constrain width on large screens, and add master-detail/desktop
  affordances without breaking the neumorphic look. Pair with clarity-design-system.
---

# Clarity — Adaptable to All Resolutions

Target range: **small phones → large phones → tablets/foldables (portrait &
landscape) → web → desktop**. All six platform folders are built, so a layout must
never assume a phone-width, portrait, touch-only screen.

## Where the app stands today (start here)

Already good (keep/extend these): `LayoutBuilder` + `.clamp()` for horizontal item
widths (`weather_page.dart`), one `MediaQuery` breakpoint for the metrics grid
(`forecast_page.dart:174`, `width > 600 ? 3 : 2` columns), `FittedBox` around hero
numbers, `Flexible`/`Expanded` + `overflow: ellipsis`.

Responsive debt to fix as you touch code (do **not** add more of it):
- **Fixed `height: 600`** in `weather_page.dart` (loading/error/initial placeholders,
  3 places) — overflows small screens, wastes space on large ones.
- **36 hardcoded `fontSize:` literals** — don't scale with screen or text settings.
- **Magic `600`** inline in `forecast_page.dart` — should be a named breakpoint.
- **Fixed shadow offsets** (`Offset(8,8)`, blur 16) in `ClayContainer` — fine on
  phones, heavy on dense desktop layouts.
- **No max content width** — on web/desktop the single column stretches edge-to-edge.
- Text ignores the OS **text-scale** accessibility setting.

## The system to adopt — one breakpoint source in `core/`

Create `lib/core/responsive/breakpoints.dart` (single source of truth; replace the
inline `600`s with it):

```dart
import 'package:flutter/widgets.dart';

enum ScreenType { phone, tablet, desktop }

class Breakpoints {
  static const double tablet = 600;   // >= tablet
  static const double desktop = 1024; // >= desktop
  static const double maxContentWidth = 720; // cap single-column width on big screens
}

ScreenType screenTypeOf(double width) => width >= Breakpoints.desktop
    ? ScreenType.desktop
    : width >= Breakpoints.tablet
        ? ScreenType.tablet
        : ScreenType.phone;

// Prefer local space (LayoutBuilder) over global (MediaQuery) when a widget only
// cares about the box it's in. Use MediaQuery.sizeOf(context) for whole-screen decisions.
```

Rules of thumb:
- **`LayoutBuilder`** when a widget adapts to the space it's *given* (cards, grids,
  lists). **`MediaQuery.sizeOf(context)`** (not `.of`) for screen-level choices
  (page layout, nav placement). `sizeOf` avoids rebuilds on unrelated MediaQuery changes.
- Decide layout by **width breakpoint**, never by platform (`Platform.isX`) — a desktop
  window can be phone-narrow and a tablet can be desktop-wide.

## Fixes, with the app's real code

**1. Kill fixed `height: 600` — size to available space, center content.**
```dart
// before: SizedBox(height: 600, child: Center(child: CircularProgressIndicator()))
// after:
LayoutBuilder(
  builder: (context, c) => SizedBox(
    height: c.maxHeight.isFinite ? c.maxHeight : MediaQuery.sizeOf(context).height * 0.7,
    child: const Center(child: CircularProgressIndicator()),
  ),
)
```
(These placeholders sit inside a scroll view, so also consider giving the scroll view a
`ConstrainedBox(minHeight: viewportHeight)` instead of a magic number.)

**2. Constrain width on large screens** — wrap page bodies so content doesn't stretch
across a desktop monitor while keeping the neumorphic cards centered:
```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
    child: yourScrollView,
  ),
)
```
Apply at the page level in `weather_page`, `forecast_page`, `settings_page`,
`menu_screen`.

**3. Scalable type instead of 36 literals.** Add a text scale helper and use the theme
ladder rather than raw numbers. Minimum viable step: clamp the OS text scaler so huge
accessibility settings don't break clay cards, and derive hero sizes from width:
```dart
// respect but bound accessibility scaling (put near MaterialApp or per-Text)
final scaler = MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
// width-aware hero number:
final heroSize = (MediaQuery.sizeOf(context).width * 0.24).clamp(56.0, 120.0);
```
Longer term, move the size ladder from `clarity-design-system` into named constants
(e.g. `AppText.hero`, `.title`, `.section`) so it's tunable in one place — but keep
`FittedBox(scaleDown)` on numbers/labels regardless.

**4. Grid columns by breakpoint helper** (replace the inline `600`):
```dart
final cols = switch (screenTypeOf(MediaQuery.sizeOf(context).width)) {
  ScreenType.phone => 2,
  ScreenType.tablet => 3,
  ScreenType.desktop => 4,
};
```

**5. Master-detail on wide screens.** The app uses a `PageView` (Today | Forecast) on
phones. On tablet/desktop, show them **side by side** instead of paged:
```dart
LayoutBuilder(builder: (context, c) {
  if (screenTypeOf(c.maxWidth) == ScreenType.phone) {
    return pagedView;                       // existing PageView + bottom nav
  }
  return Row(children: [
    const Expanded(flex: 2, child: WeatherPage()),
    const SizedBox(width: 24),
    const Expanded(flex: 3, child: ForecastPage()),
  ]);
});
```
Hide the sliding bottom nav when both panes are visible.

## Platform affordances beyond phone

- **Web/desktop pointer**: wrap tappable clay surfaces so the cursor changes
  (`MouseRegion(cursor: SystemMouseCursors.click)` or use `InkWell`/`GestureDetector`
  which the app already mixes). Keep tap targets ≥ 44px.
- **Scrollbars**: desktop/web expect a visible scrollbar — wrap long
  `SingleChildScrollView`s in `Scrollbar(controller: ...)`.
- **Keyboard**: the search dialog (`main_screen.dart:_showSearchDialog`) should submit
  on Enter — add `onSubmitted` to the `TextField`, and ensure focus traversal works.
- **Safe area & insets**: keep `SafeArea` (used in `menu_screen`) on every top-level
  page; account for notches, rounded corners, and desktop title bars.
- **Orientation**: don't lock layouts to portrait math; landscape phones are ~tablet
  width — the breakpoint system already handles this if you branch on width, not device.

## Keep the neumorphic look while scaling

- Optionally scale shadow offset/blur with a size factor for very large surfaces, but
  do it **inside `ClayContainer`** (single source), e.g. an optional `elevationScale`
  param — never per-widget. Default (8/16) stays for phones.
- `borderRadius` can grow slightly on large cards; expose it as the existing param
  rather than hardcoding new values.

## Definition of done (resolution)
- No fixed screen-sized pixel heights/widths; placeholders size to available space.
- Layout branches on **width breakpoints** from `core/responsive/`, not magic numbers
  or `Platform`.
- Content width capped on desktop/web; multi-pane where it helps.
- Text respects (bounded) OS scaling; overflow-safe via `FittedBox`/`ellipsis`.
- Pointer cursor + scrollbar + keyboard submit on web/desktop.
- Looks correct at 320px, ~768px, and ~1440px wide, portrait and landscape.

---
name: clarity-design-system
description: >-
  The visual/interaction language of Clarity — use whenever building or changing
  any UI in this repo (screens, widgets, cards, colors, text, motion). Codifies
  the "Tactile Neumorphic" claymorphism system: the ClayContainer widget, the
  AppColors palette, Bricolage Grotesque typography, and the "motion as language"
  patterns (AnimatedSwitcher, sliding pills, ShaderMask edge-fades) exactly as
  built. Goal: keep every new surface consistent with the existing look. Pair
  with clarity-architecture (where UI code lives) and clarity-responsive (sizing).
---

# Clarity — Design System ("Tactile Neumorphic")

Clarity's identity is soft-UI claymorphism: surfaces feel raised out of a warm
off-white background via paired light/dark shadows. Every new surface must use the
same building blocks. **Light mode only.**

## Colors — always from `AppColors` (`lib/core/theme/app_colors.dart`)

Never write raw `Color(0x…)` in a widget. Use the palette:

| Token | Value | Use for |
|---|---|---|
| `AppColors.surface` | `#FBF9F4` (warm off-white) | scaffold background, inset icon chips |
| `AppColors.textPrimary` | `#2D3142` | headings, values, primary text |
| `AppColors.textSecondary` | `#9BA8BB` | labels, captions, inactive |
| `AppColors.functionalBlue` | `#4A90E2` | primary accent, focus, active controls |
| `AppColors.warmAccent` | `#F5E6CC` | selected pill / highlight fill |
| `AppColors.atmosphericBlueGray` | `#7D8BA1` | icon tint, secondary detail |
| `AppColors.inactiveBlueGray` | `#9BA8BB` | inactive icons |
| `AppColors.shadowLight` (white) / `AppColors.shadowDark` (`#D1CDC7` @50%) | neumorphic shadow pair |
| `AppColors.getCardColor()` → white | default `ClayContainer` fill |

- **Never** pure black or pure white for surfaces (shadows need tinted grays to
  "breathe"). Text uses `textPrimary`/`textSecondary`, not `Colors.black`.
- Two legacy inline colors exist (`Color(0xFFE8E2D8)` selected fill, in
  `menu_screen.dart` / `settings_page.dart`). If you touch that code, prefer promoting
  it to an `AppColors` token (e.g. `selectedFill`) rather than copying the hex again.

## The neumorphic surface — `ClayContainer`

`lib/features/weather/presentation/widgets/clay_container.dart`. This is THE card.
Its raised look = two opposing shadows: dark `Offset(8,8)` bottom-right + white
`Offset(-8,-8)` top-left, blur 16, spread 1.

```dart
ClayContainer(
  borderRadius: 24,                 // default 32; cards use 24, pills 20-40, chips 12-16
  padding: const EdgeInsets.all(20),
  color: AppColors.getCardColor(),  // optional; defaults to white
  shape: BoxShape.rectangle,        // or BoxShape.circle for round buttons
  inset: false,                     // true = SUNKEN (pressed-into-clay) surface
  child: ...,
)
```

**Raised vs sunken (`inset`):** raised (default) = extruded card/button; `inset: true` =
sunken "molded" surface (inward shadows via `flutter_inset_shadow`). Use sunken for
grouped/molded containers, badges, inset icon chips, and input fields — pairing a raised
outer surface with sunken inner chips is the core clay contrast (see `profile_page.dart`).

Rules:
- Wrap **every** distinct content block (cards, metric tiles, nav bar, toggles, icon
  buttons) in a `ClayContainer` — separation is by elevation, **not** by borders or
  divider lines. Do not add `Border`/`Divider`/gray outlines.
- Nesting is intentional: a smaller inset `ClayContainer(color: AppColors.surface)`
  makes an "embossed" icon chip inside a raised card (see the metric cards in
  `forecast_page.dart:_buildMetricCard`).
- Round icon buttons: `ClayContainer(shape: BoxShape.circle, padding: EdgeInsets.all(12), child: Icon(...))` (see `menu_screen.dart` close button).
- **Shadows must not be clipped.** Give viewports/scroll areas enough padding so the
  8px shadows paint fully; don't wrap a `ClayContainer` edge-to-edge or under a tight
  `ClipRect`. (This is why list paddings are generous.)

> Note: `ClayContainer(inset: true)` now provides the sunken/pressed state (backed by
> `flutter_inset_shadow`). Use it rather than hand-rolling inner shadows per widget.

## Weather iconography — `ClayWeatherIcon`

`clay_weather_icon.dart` maps a condition string (`'Clear Sky'`, `'Partly Cloudy'`,
`'Cloudy'`, `'Rain'`, `'Storm'`, `'Snow'`) to a rounded Material icon + tinted circular
clay chip. Pass `condition` + `size`. Add new conditions by extending its `switch`
(and keep the tint from `AppColors`). Sizes in use: 140 (hero), 48/40/36 (list rows).

> Consistency gap to be aware of: `WeatherIconMapper.mapCodeToCondition`
> (`core/utils/weather_icon_mapper.dart`) also emits **night** conditions like
> `'Clear Night'` / `'Partly Cloudy Night'`, but `ClayWeatherIcon`'s switch has no cases
> for them, so they hit the `default` (sunny). If you add night visuals, add matching
> cases here so night states don't render as a sun.

## Typography — Bricolage Grotesque via `google_fonts`

Set globally in `app_theme.dart` (`GoogleFonts.bricolageGrotesqueTextTheme()`). Don't
introduce other fonts. Weight/size intent seen across pages:
- Hero numbers (temperature): `fontSize: 84–96, FontWeight.bold`, wrapped in `FittedBox`.
- Page titles: `32 bold`; section headers: `24 bold`; row titles: `18–20 bold`.
- Body/labels: `14–18`, `textSecondary` for secondary.
- Overline labels use `letterSpacing: 1.2` (see settings "PREFERENCES").

⚠️ Font sizes are currently hardcoded literals (36 of them). When adding text, follow
the size ladder above, and for anything that must not overflow (numbers, translated
labels) wrap in `FittedBox(fit: BoxFit.scaleDown)` + `maxLines`/`overflow: ellipsis`,
as the existing cards do. (See `clarity-responsive` for making the ladder scale.)

## Motion as language (animations are first-class)

Reuse these exact patterns — don't invent new transition styles:

- **State changes** (loading↔loaded↔error): wrap content in `AnimatedSwitcher(duration:
  Duration(milliseconds: 600), child: …)` with a `ValueKey` per state (see
  `weather_page.dart`, `forecast_page.dart`).
- **Tab switching**: a `PageView` with `NeverScrollableScrollPhysics` driven by a
  `PageController.animateToPage(..., 400ms, Curves.easeInOutCubic)` (see `main_screen.dart`).
- **Sliding selector pill** (bottom nav, unit toggles): a `Stack` with an
  `AnimatedPositioned(350ms, Curves.easeInOutCubic)` highlight sized to
  `constraints.maxWidth / count`, over a `Row` of `Expanded` tap targets. Reuse
  `_buildAnimatedToggle` in `settings_page.dart` as the template for any segmented control.
- **Tap feedback**: `AnimatedScale` to `0.95` on `onTapDown` (see `_HourlyForecastItem`).
- **Route transitions**: custom `PageRouteBuilder` with `SlideTransition`
  (`Offset(-1,0)→0`, `easeInOutCubic`) for the menu (see `main_screen.dart`).
- **List edge polish**: fade the leading/trailing edges of horizontal lists with a
  `ShaderMask` (`BlendMode.dstIn`, `LinearGradient` stops `[0, .05, .95, 1]`). Always
  wrap the `SizedBox` viewport with the `ShaderMask`; keep default clipping on the
  child `ListView` to avoid vertical artifacts.

## Localized text is part of design consistency

Every visible string goes through `Localizer.localize('key', settings.language)` — a
raw English string in a widget is a design bug as much as a wrong color. Add the key to
`lib/l10n/app_en.arb` first (see `clarity-add-feature`).

## Definition of done for any Clarity screen

- Background is `AppColors.surface`; content blocks are `ClayContainer`s (no borders).
- All colors from `AppColors`; all fonts Bricolage (theme default).
- Overflow-prone text wrapped in `FittedBox`/`ellipsis`.
- State transitions animated via `AnimatedSwitcher`; selectors use the sliding-pill.
- All strings via `Localizer`.
- Verified against `clarity-responsive` for sizing across screen sizes.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/core/theme/app_colors.dart';
import 'package:clarity/core/utils/weather_icon_mapper.dart';
import 'package:clarity/features/weather/presentation/widgets/clay_weather_icon.dart';

/// WCAG relative-contrast ratio, 1.0 (identical) … 21.0 (black on white).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A condition string that will never match a case, so `styleFor` returns the
/// `default` branch. Anything that compares equal to this fell through.
const _unhandled = '__not_a_real_condition__';

void main() {
  final fallback = ClayWeatherIcon.styleFor(_unhandled);

  group('ClayWeatherIcon.styleFor', () {
    test('handles every condition WeatherIconMapper can emit', () {
      // 'Clear Sky' is legitimately the fallback (sun), so it is the one
      // condition allowed to equal it.
      final fellThrough = WeatherIconMapper.conditions
          .where((c) => c != 'Clear Sky')
          .where((c) => ClayWeatherIcon.styleFor(c) == fallback)
          .toList();

      expect(
        fellThrough,
        isEmpty,
        reason: 'These conditions have no case in styleFor and silently '
            'render as a sun: $fellThrough',
      );
    });

    test('night conditions do not render as the sun', () {
      for (final condition in ['Clear Night', 'Partly Cloudy Night']) {
        expect(
          ClayWeatherIcon.styleFor(condition).icon,
          isNot(Icons.wb_sunny_rounded),
          reason: '$condition rendered the sunny icon',
        );
      }
    });

    test('day and night variants are visually distinct', () {
      expect(
        ClayWeatherIcon.styleFor('Clear Sky').icon,
        isNot(ClayWeatherIcon.styleFor('Clear Night').icon),
      );
      expect(
        ClayWeatherIcon.styleFor('Partly Cloudy').icon,
        isNot(ClayWeatherIcon.styleFor('Partly Cloudy Night').icon),
      );
    });

    test('fog has its own icon rather than the sun', () {
      expect(ClayWeatherIcon.styleFor('Fog'), isNot(fallback));
    });

    test('no condition tint disappears into the clay card', () {
      // Snow shipped as Colors.white on a white card with a white-at-10% chip
      // behind it — a contrast ratio of exactly 1.0. The floor is deliberately
      // low: warmAccent (the pale cream sun) sits just above it at ~1.23 and is
      // an accepted design choice, rescued by its halo and shadow.
      final card = AppColors.getCardColor();
      for (final condition in WeatherIconMapper.conditions) {
        final color = ClayWeatherIcon.styleFor(condition).color;
        expect(color, isNot(card), reason: '$condition is tinted the card colour');
        expect(
          _contrast(color, card),
          greaterThan(1.2),
          reason: '$condition is invisible against the card it sits on',
        );
      }
    });
  });

  group('OpenWeather night codes', () {
    // Every '...n' code OpenWeather can return. None may resolve to the sun —
    // this is the regression that shipped.
    const nightCodes = [
      '01n',
      '02n',
      '03n',
      '04n',
      '09n',
      '10n',
      '11n',
      '13n',
      '50n',
    ];

    test('never resolve to the sunny icon', () {
      for (final code in nightCodes) {
        final condition = WeatherIconMapper.mapCodeToCondition(code);
        expect(
          ClayWeatherIcon.styleFor(condition).icon,
          isNot(Icons.wb_sunny_rounded),
          reason: 'code $code -> "$condition" rendered the sunny icon',
        );
      }
    });

    test('map to conditions styleFor actually handles', () {
      for (final code in nightCodes) {
        final condition = WeatherIconMapper.mapCodeToCondition(code);
        expect(
          WeatherIconMapper.conditions,
          contains(condition),
          reason: 'code $code produced "$condition", which is not in '
              'WeatherIconMapper.conditions',
        );
      }
    });
  });

  group('ClayWeatherIcon widget', () {
    Future<void> pump(WidgetTester tester, String condition) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClayWeatherIcon(condition: condition, size: 100),
          ),
        ),
      );
    }

    testWidgets('renders a moon for a clear night', (tester) async {
      await pump(tester, 'Clear Night');

      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_rounded), findsNothing);
    });

    testWidgets('renders a moon behind cloud for a cloudy night',
        (tester) async {
      await pump(tester, 'Partly Cloudy Night');

      expect(find.byIcon(Icons.nights_stay_rounded), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_rounded), findsNothing);
    });

    testWidgets('still renders the sun for a clear day', (tester) async {
      await pump(tester, 'Clear Sky');

      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    });

    testWidgets('sizes the icon relative to the chip', (tester) async {
      await pump(tester, 'Fog');

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 60); // size * 0.6
    });
  });
}

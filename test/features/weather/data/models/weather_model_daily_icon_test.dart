import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/features/weather/data/models/weather_model.dart';

/// Local-time epoch seconds for [hour] on an arbitrary fixed date.
int _at(int day, int hour) =>
    DateTime(2026, 7, day, hour).millisecondsSinceEpoch ~/ 1000;

Map<String, dynamic> _slot(int day, int hour, String icon) => {
      'dt': _at(day, hour),
      'main': {'temp': 20, 'temp_max': 22, 'temp_min': 18},
      'weather': [
        {'icon': icon}
      ],
    };

Map<String, dynamic> get _current => {
      'name': 'Testville',
      'coord': {'lat': 42.0, 'lon': 23.0},
      'main': {
        'temp': 20,
        'temp_max': 22,
        'temp_min': 18,
        'pressure': 1012,
        'humidity': 40
      },
      'wind': {'speed': 3},
      'weather': [
        {'icon': '01d'}
      ],
    };

void main() {
  group('daily forecast icon aggregation', () {
    test('a full day is represented by its midday slot, not its last slot', () {
      // The regression: the icon was overwritten every slot, so every day
      // rendered its ~21:00 entry — a moon on every daily row.
      final model = WeatherModel.fromApiResponse(
        currentJson: _current,
        forecastJson: {
          'list': [
            _slot(10, 9, '02d'),
            _slot(10, 12, '01d'), // midday: clear day
            _slot(10, 21, '01n'), // evening: clear night — must NOT win
          ],
        },
        locale: 'en',
      );

      expect(model.dailyForecast.first.condition, 'Clear Sky');
    });

    test('a trailing evening-only day still shows the day variant', () {
      final model = WeatherModel.fromApiResponse(
        currentJson: _current,
        forecastJson: {
          'list': [
            _slot(11, 18, '02n'),
            _slot(11, 21, '02n'),
          ],
        },
        locale: 'en',
      );

      // '02n' → 'Partly Cloudy Night' if taken raw; a daily row must render
      // the day family instead.
      expect(model.dailyForecast.first.condition, 'Partly Cloudy');
    });

    test('high/low still aggregate across all slots', () {
      final model = WeatherModel.fromApiResponse(
        currentJson: _current,
        forecastJson: {
          'list': [
            {
              'dt': _at(12, 9),
              'main': {'temp': 15, 'temp_max': 16, 'temp_min': 11},
              'weather': [
                {'icon': '01d'}
              ],
            },
            {
              'dt': _at(12, 15),
              'main': {'temp': 24, 'temp_max': 27, 'temp_min': 21},
              'weather': [
                {'icon': '01d'}
              ],
            },
          ],
        },
        locale: 'en',
      );

      expect(model.dailyForecast.first.highTemp, 27);
      expect(model.dailyForecast.first.lowTemp, 11);
    });
  });
}

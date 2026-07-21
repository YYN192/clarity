import 'package:equatable/equatable.dart';

class Weather extends Equatable {
  final String cityName;

  /// Coordinates of the resolved location. Stored alongside the device's FCM
  /// token so the alert backend knows where to check the weather.
  final double lat;
  final double lon;

  final double temperature;
  final String condition;
  final double highTemp;
  final double lowTemp;
  final double windSpeed;
  final int pressure;
  final int humidity;
  final double uvIndex;
  final double visibility;
  final double dewPoint;
  final List<HourlyForecast> hourlyForecast;
  final List<DailyForecast> dailyForecast;

  const Weather({
    required this.cityName,
    required this.lat,
    required this.lon,
    required this.temperature,
    required this.condition,
    required this.highTemp,
    required this.lowTemp,
    required this.windSpeed,
    required this.pressure,
    required this.humidity,
    required this.uvIndex,
    required this.visibility,
    required this.dewPoint,
    required this.hourlyForecast,
    required this.dailyForecast,
  });

  @override
  List<Object?> get props => [
        cityName,
        lat,
        lon,
        temperature,
        condition,
        highTemp,
        lowTemp,
        windSpeed,
        pressure,
        humidity,
        uvIndex,
        visibility,
        dewPoint,
        hourlyForecast,
        dailyForecast,
      ];
}

class HourlyForecast extends Equatable {
  /// The moment this forecast is for. Formatted for display at render time with
  /// the current locale (see the presentation layer) — never pre-format here, or
  /// the string is frozen to whatever locale was active at fetch time.
  final DateTime dateTime;
  final double temperature;
  final String condition;

  const HourlyForecast({
    required this.dateTime,
    required this.temperature,
    required this.condition,
  });

  @override
  List<Object?> get props => [dateTime, temperature, condition];
}

class DailyForecast extends Equatable {
  /// The calendar day this forecast is for. Formatted (e.g. `EEE`) at display
  /// time with the current locale so weekday names localize correctly.
  final DateTime date;
  final double highTemp;
  final double lowTemp;
  final String condition;

  const DailyForecast({
    required this.date,
    required this.highTemp,
    required this.lowTemp,
    required this.condition,
  });

  @override
  List<Object?> get props => [date, highTemp, lowTemp, condition];
}

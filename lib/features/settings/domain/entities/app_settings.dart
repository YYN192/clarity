import 'package:equatable/equatable.dart';

enum TemperatureUnit { celsius, fahrenheit }
enum WindSpeedUnit { kmh, mph, ms }
enum PressureUnit { hPa, inHg, mmHg }

class AppSettings extends Equatable {
  final String language;
  final TemperatureUnit temperatureUnit;
  final WindSpeedUnit windSpeedUnit;
  final PressureUnit pressureUnit;
  final bool severeWeatherAlerts;
  final bool isDarkMode;

  const AppSettings({
    this.language = 'English',
    this.temperatureUnit = TemperatureUnit.celsius,
    this.windSpeedUnit = WindSpeedUnit.kmh,
    this.pressureUnit = PressureUnit.hPa,
    this.severeWeatherAlerts = false,
    this.isDarkMode = false,
  });

  AppSettings copyWith({
    String? language,
    TemperatureUnit? temperatureUnit,
    WindSpeedUnit? windSpeedUnit,
    PressureUnit? pressureUnit,
    bool? severeWeatherAlerts,
    bool? isDarkMode,
  }) {
    return AppSettings(
      language: language ?? this.language,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      windSpeedUnit: windSpeedUnit ?? this.windSpeedUnit,
      pressureUnit: pressureUnit ?? this.pressureUnit,
      severeWeatherAlerts: severeWeatherAlerts ?? this.severeWeatherAlerts,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  @override
  List<Object?> get props => [
        language,
        temperatureUnit,
        windSpeedUnit,
        pressureUnit,
        severeWeatherAlerts,
        isDarkMode,
      ];
}

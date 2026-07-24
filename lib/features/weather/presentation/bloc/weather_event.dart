import 'package:equatable/equatable.dart';

abstract class WeatherEvent extends Equatable {
  const WeatherEvent();

  @override
  List<Object?> get props => [];
}

class LoadInitialWeather extends WeatherEvent {
  final String units;
  final String locale;
  const LoadInitialWeather({this.units = 'metric', this.locale = 'en'});

  @override
  List<Object?> get props => [units, locale];
}

class GetWeatherEvent extends WeatherEvent {
  final String cityName;
  final String units;
  final String locale;

  const GetWeatherEvent(this.cityName, {this.units = 'metric', this.locale = 'en'});

  @override
  List<Object?> get props => [cityName, units, locale];
}

/// Re-reads GPS and updates the coordinates the alert backend targets.
///
/// Deliberately does not change [WeatherState]: where severe-weather alerts are
/// sent is independent of whichever city the user happens to be browsing.
/// Dispatched on app resume so a phone that sits unopened doesn't keep
/// week-old coordinates.
class RefreshAlertLocation extends WeatherEvent {
  const RefreshAlertLocation();
}

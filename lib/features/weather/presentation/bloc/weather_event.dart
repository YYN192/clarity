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

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/weather.dart';
import '../repositories/weather_repository.dart';

class GetWeather extends UseCase<Weather, WeatherParams> {
  final WeatherRepository repository;

  GetWeather(this.repository);

  @override
  Future<Either<Failure, Weather>> call(WeatherParams params) async {
    if (params.cityName != null) {
      return await repository.getWeatherByCity(params.cityName!, units: params.units, locale: params.locale);
    } else if (params.lat != null && params.lon != null) {
      return await repository.getWeatherByCoords(params.lat!, params.lon!, units: params.units, locale: params.locale);
    } else {
      return const Left(ServerFailure('Invalid parameters'));
    }
  }
}

class WeatherParams extends Equatable {
  final String? cityName;
  final double? lat;
  final double? lon;
  final String units;
  final String locale;

  const WeatherParams({
    this.cityName,
    this.lat,
    this.lon,
    this.units = 'metric',
    this.locale = 'en',
  });

  @override
  List<Object?> get props => [cityName, lat, lon, units, locale];
}

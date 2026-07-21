import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/weather.dart';

abstract class WeatherRepository {
  Future<Either<Failure, Weather>> getWeatherByCity(String cityName, {String units = 'metric', String locale = 'en'});
  Future<Either<Failure, Weather>> getWeatherByCoords(double lat, double lon, {String units = 'metric', String locale = 'en'});
}

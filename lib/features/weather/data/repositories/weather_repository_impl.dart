import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/city_location.dart';
import '../../domain/entities/weather.dart';
import '../../domain/repositories/weather_repository.dart';
import '../datasources/weather_remote_data_source.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherRemoteDataSource remoteDataSource;

  WeatherRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Weather>> getWeatherByCity(String cityName, {String units = 'metric', String locale = 'en'}) async {
    try {
      final remoteWeather = await remoteDataSource.getWeatherByCity(cityName, units: units, locale: locale);
      return Right(remoteWeather);
    } on ApiKeyException {
      return const Left(ApiKeyFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure());
    } on RateLimitException {
      return const Left(RateLimitFailure());
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Weather>> getWeatherByCoords(double lat, double lon, {String units = 'metric', String locale = 'en'}) async {
    try {
      final remoteWeather = await remoteDataSource.getWeatherByCoords(lat, lon, units: units, locale: locale);
      return Right(remoteWeather);
    } on ApiKeyException {
      return const Left(ApiKeyFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure());
    } on RateLimitException {
      return const Left(RateLimitFailure());
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CityLocation>>> searchCities(String query, {String locale = 'en'}) async {
    try {
      final results = await remoteDataSource.searchCities(query, locale: locale);
      return Right(results);
    } on ApiKeyException {
      return const Left(ApiKeyFailure());
    } on NotFoundException {
      return const Left(NotFoundFailure());
    } on RateLimitException {
      return const Left(RateLimitFailure());
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

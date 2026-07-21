import 'package:dio/dio.dart';
import '../models/weather_model.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/config/env_config.dart';

abstract class WeatherRemoteDataSource {
  Future<WeatherModel> getWeatherByCity(String cityName, {String units = 'metric', String locale = 'en'});
  Future<WeatherModel> getWeatherByCoords(double lat, double lon, {String units = 'metric', String locale = 'en'});
}

class WeatherRemoteDataSourceImpl implements WeatherRemoteDataSource {
  final Dio dio;
  final EnvConfig envConfig;

  WeatherRemoteDataSourceImpl({
    required this.dio,
    required this.envConfig,
  });

  @override
  Future<WeatherModel> getWeatherByCity(String cityName, {String units = 'metric', String locale = 'en'}) async {
    final apiKey = envConfig.openWeatherApiKey;
    
    try {
      // 1. Geocoding API: City to Lat/Lon
      final geoResponse = await dio.get(
        'https://api.openweathermap.org/geo/1.0/direct',
        queryParameters: {
          'q': cityName,
          'limit': 1,
          'appid': apiKey,
        },
      );

      if (geoResponse.statusCode != 200) {
        _handleError(geoResponse.statusCode);
      }

      final List data = geoResponse.data;
      if (data.isEmpty) {
        throw NotFoundException();
      }

      final lat = data[0]['lat'];
      final lon = data[0]['lon'];

      return getWeatherByCoords(lat, lon, units: units, locale: locale);
    } on DioException catch (e) {
      if (e.response != null) {
        _handleError(e.response!.statusCode);
      }
      throw NetworkException();
    } catch (e) {
      if (e is NotFoundException) rethrow;
      throw ServerException();
    }
  }

  @override
  Future<WeatherModel> getWeatherByCoords(double lat, double lon, {String units = 'metric', String locale = 'en'}) async {
    final apiKey = envConfig.openWeatherApiKey;
    
    try {
      // 1. Get Current Weather
      final currentResponse = await dio.get(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'appid': apiKey,
          'units': units,
        },
      );

      if (currentResponse.statusCode != 200) {
        _handleError(currentResponse.statusCode);
      }

      // 2. Get Forecast (5 day / 3 hour)
      final forecastResponse = await dio.get(
        'https://api.openweathermap.org/data/2.5/forecast',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'appid': apiKey,
          'units': units,
        },
      );

      if (forecastResponse.statusCode != 200) {
        _handleError(forecastResponse.statusCode);
      }

      return WeatherModel.fromApiResponse(
        currentJson: currentResponse.data,
        forecastJson: forecastResponse.data,
        locale: locale,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        _handleError(e.response!.statusCode);
      }
      throw NetworkException();
    } catch (e) {
      throw ServerException();
    }
  }

  void _handleError(int? statusCode) {
    if (statusCode == 401) throw ApiKeyException();
    if (statusCode == 404) throw NotFoundException();
    if (statusCode == 429) throw RateLimitException();
    throw ServerException();
  }
}

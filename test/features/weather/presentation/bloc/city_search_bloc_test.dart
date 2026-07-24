import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/core/error/failures.dart';
import 'package:clarity/features/weather/data/models/city_location_model.dart';
import 'package:clarity/features/weather/domain/entities/city_location.dart';
import 'package:clarity/features/weather/domain/repositories/weather_repository.dart';
import 'package:clarity/features/weather/domain/entities/weather.dart';
import 'package:clarity/features/weather/domain/usecases/search_cities.dart';
import 'package:clarity/features/weather/presentation/bloc/city_search_bloc.dart';

class _FakeRepo implements WeatherRepository {
  int searchCalls = 0;
  Either<Failure, List<CityLocation>> next = const Right([]);

  @override
  Future<Either<Failure, List<CityLocation>>> searchCities(String query,
      {String locale = 'en'}) async {
    searchCalls++;
    return next;
  }

  @override
  Future<Either<Failure, Weather>> getWeatherByCity(String cityName,
          {String units = 'metric', String locale = 'en'}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Weather>> getWeatherByCoords(double lat, double lon,
          {String units = 'metric', String locale = 'en'}) =>
      throw UnimplementedError();
}

const _sofia =
    CityLocation(name: 'Sofia', country: 'BG', lat: 42.7, lon: 23.3);

void main() {
  late _FakeRepo repo;
  late CitySearchBloc bloc;

  setUp(() {
    repo = _FakeRepo();
    bloc = CitySearchBloc(searchCities: SearchCities(repo));
  });

  tearDown(() => bloc.close());

  test('short queries reset to idle without calling the API', () async {
    bloc.add(const CitySearchQueryChanged('s'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.status, CitySearchStatus.idle);
    expect(repo.searchCalls, 0);
  });

  test('a query loads results', () async {
    repo.next = const Right([_sofia]);
    bloc.add(const CitySearchQueryChanged('sofia'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.status, CitySearchStatus.loaded);
    expect(bloc.state.results, const [_sofia]);
  });

  test('repeating a query is served from cache', () async {
    repo.next = const Right([_sofia]);
    bloc.add(const CitySearchQueryChanged('sofia'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const CitySearchQueryChanged('Sofia')); // case-insensitive hit
    await Future<void>.delayed(Duration.zero);

    expect(repo.searchCalls, 1);
    expect(bloc.state.results, const [_sofia]);
  });

  test('failures surface as the error status', () async {
    repo.next = const Left(NetworkFailure());
    bloc.add(const CitySearchQueryChanged('sofia'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.status, CitySearchStatus.error);
  });

  group('CityLocationModel.fromJson', () {
    test('parses a geocoder entry with state and localized name', () {
      final model = CityLocationModel.fromJson({
        'name': 'Sofia',
        'local_names': {'bg': 'София'},
        'lat': 42.6977,
        'lon': 23.3219,
        'country': 'BG',
      }, locale: 'bg');

      expect(model.name, 'София');
      expect(model.country, 'BG');
      expect(model.label, 'София, BG');
    });

    test('falls back to the plain name when no localization exists', () {
      final model = CityLocationModel.fromJson({
        'name': 'Springfield',
        'state': 'Illinois',
        'lat': 39.8,
        'lon': -89.6,
        'country': 'US',
      }, locale: 'bg');

      expect(model.name, 'Springfield');
      expect(model.label, 'Springfield, Illinois, US');
    });

    test('integer coordinates parse as doubles', () {
      final model = CityLocationModel.fromJson({
        'name': 'Test',
        'lat': 42,
        'lon': 23,
        'country': 'BG',
      });

      expect(model.lat, 42.0);
      expect(model.lon, 23.0);
    });
  });
}

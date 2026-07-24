import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clarity/core/error/failures.dart';
import 'package:clarity/core/services/location_service.dart';
import 'package:clarity/core/services/notification_service.dart';
import 'package:clarity/features/weather/domain/entities/city_location.dart';
import 'package:clarity/features/weather/domain/entities/weather.dart';
import 'package:clarity/features/weather/domain/repositories/weather_repository.dart';
import 'package:clarity/features/weather/domain/usecases/get_weather.dart';
import 'package:clarity/features/weather/presentation/bloc/weather_bloc.dart';
import 'package:clarity/features/weather/presentation/bloc/weather_event.dart';

/// Where the device physically is.
const _deviceLat = 42.7;
const _deviceLon = 23.3;

/// Somewhere else entirely, which the user merely searched for.
const _searchedLat = 35.68;
const _searchedLon = 139.69;

Weather _weather(String city, double lat, double lon) => Weather(
      cityName: city,
      lat: lat,
      lon: lon,
      temperature: 20,
      condition: 'Clear Sky',
      highTemp: 22,
      lowTemp: 18,
      windSpeed: 3,
      pressure: 1012,
      humidity: 40,
      uvIndex: 1,
      visibility: 10,
      dewPoint: 8,
      hourlyForecast: const [],
      dailyForecast: const [],
    );

class _FakeWeatherRepository implements WeatherRepository {
  @override
  Future<Either<Failure, Weather>> getWeatherByCity(String cityName,
          {String units = 'metric', String locale = 'en'}) async =>
      Right(_weather(cityName, _searchedLat, _searchedLon));

  @override
  Future<Either<Failure, Weather>> getWeatherByCoords(double lat, double lon,
          {String units = 'metric', String locale = 'en'}) async =>
      Right(_weather('Device City', lat, lon));

  @override
  Future<Either<Failure, List<CityLocation>>> searchCities(String query,
          {String locale = 'en'}) async =>
      const Right([]);
}

class _FakeLocationService implements LocationService {
  _FakeLocationService({this.available = true});

  final bool available;
  int calls = 0;

  @override
  Future<Position?> getCurrentPosition() async {
    calls++;
    if (!available) throw 'Location services are disabled.';
    return Position(
      latitude: _deviceLat,
      longitude: _deviceLon,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
  }
}

typedef _AlertWrite = ({double lat, double lon, String? city});

class _RecordingNotificationService implements NotificationService {
  final List<_AlertWrite> alertWrites = [];
  final List<({String units, String language})> prefWrites = [];

  @override
  Future<void> updateAlertLocation({
    required double lat,
    required double lon,
    String? city,
  }) async {
    alertWrites.add((lat: lat, lon: lon, city: city));
  }

  @override
  Future<void> updateDisplayPreferences({
    required String units,
    required String language,
  }) async {
    prefWrites.add((units: units, language: language));
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> enable() async => true;

  @override
  Future<void> disable() async {}

  @override
  GlobalKey<ScaffoldMessengerState> get messengerKey =>
      GlobalKey<ScaffoldMessengerState>();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingNotificationService notifications;
  late _FakeLocationService location;

  Future<WeatherBloc> buildBloc({
    String? lastCity,
    bool gpsAvailable = true,
  }) async {
    SharedPreferences.setMockInitialValues(
      lastCity == null ? {} : {'last_selected_city': lastCity},
    );
    notifications = _RecordingNotificationService();
    location = _FakeLocationService(available: gpsAvailable);
    return WeatherBloc(
      getWeather: GetWeather(_FakeWeatherRepository()),
      locationService: location,
      sharedPreferences: await SharedPreferences.getInstance(),
      notificationService: notifications,
    );
  }

  group('alert location follows the device, not the browsed city', () {
    test('searching a city never moves the alert location', () async {
      final bloc = await buildBloc();

      bloc.add(const GetWeatherEvent('Tokyo'));
      await Future<void>.delayed(Duration.zero);

      expect(
        notifications.alertWrites,
        isEmpty,
        reason: 'Searching for a city redirected this device\'s severe-weather '
            'alerts to that city.',
      );
      await bloc.close();
    });

    test('selecting a search suggestion never moves the alert location',
        () async {
      final bloc = await buildBloc();

      bloc.add(const SelectCityEvent(
          cityName: 'Tokyo', lat: _searchedLat, lon: _searchedLon));
      await Future<void>.delayed(Duration.zero);

      expect(
        notifications.alertWrites,
        isEmpty,
        reason: 'Picking a city from search suggestions redirected this '
            'device\'s severe-weather alerts to that city.',
      );
      expect(notifications.prefWrites, isNotEmpty,
          reason: 'display prefs should still sync on selection');
      await bloc.close();
    });

    test('searching a city still syncs display preferences', () async {
      final bloc = await buildBloc();

      bloc.add(const GetWeatherEvent('Tokyo', units: 'imperial', locale: 'bg'));
      await Future<void>.delayed(Duration.zero);

      expect(notifications.prefWrites, isNotEmpty);
      expect(notifications.prefWrites.last.units, 'imperial');
      expect(notifications.prefWrites.last.language, 'bg');
      await bloc.close();
    });

    test('opening on a saved city still refreshes the alert location from GPS',
        () async {
      // The regression: last_selected_city short-circuited the GPS branch, so
      // the alert location was never updated again.
      final bloc = await buildBloc(lastCity: 'Tokyo');

      bloc.add(const LoadInitialWeather());
      await Future<void>.delayed(Duration.zero);

      expect(notifications.alertWrites, hasLength(1));
      expect(notifications.alertWrites.single.lat, _deviceLat);
      expect(notifications.alertWrites.single.lon, _deviceLon);
      await bloc.close();
    });

    test('a GPS-sourced load stores the matching city name', () async {
      final bloc = await buildBloc();

      bloc.add(const LoadInitialWeather());
      await Future<void>.delayed(Duration.zero);

      expect(notifications.alertWrites, hasLength(1));
      expect(notifications.alertWrites.single.lat, _deviceLat);
      expect(notifications.alertWrites.single.city, 'Device City');
      await bloc.close();
    });
  });

  group('RefreshAlertLocation', () {
    test('writes the device position and clears any stale city name', () async {
      final bloc = await buildBloc();

      bloc.add(const RefreshAlertLocation());
      await Future<void>.delayed(Duration.zero);

      expect(notifications.alertWrites, hasLength(1));
      final write = notifications.alertWrites.single;
      expect(write.lat, _deviceLat);
      expect(write.lon, _deviceLon);
      expect(
        write.city,
        isNull,
        reason: 'A city name written without matching coordinates is how the '
            'original bug produced alerts for the wrong place.',
      );
      await bloc.close();
    });

    test('keeps the last known location when GPS is unavailable', () async {
      final bloc = await buildBloc(gpsAvailable: false);

      bloc.add(const RefreshAlertLocation());
      await Future<void>.delayed(Duration.zero);

      expect(notifications.alertWrites, isEmpty);
      expect(location.calls, 1);
      await bloc.close();
    });

    test('does not emit a new weather state', () async {
      final bloc = await buildBloc();
      final states = <Object>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const RefreshAlertLocation());
      await Future<void>.delayed(Duration.zero);

      expect(states, isEmpty, reason: 'Alert targeting must not disturb the UI.');
      await sub.cancel();
      await bloc.close();
    });
  });
}

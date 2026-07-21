import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/weather.dart';
import '../../domain/usecases/get_weather.dart';
import 'weather_event.dart';
import 'weather_state.dart';

class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final GetWeather getWeather;
  final LocationService locationService;
  final SharedPreferences sharedPreferences;
  final NotificationService notificationService;

  static const String _lastCityKey = 'last_selected_city';

  /// Used when GPS is unavailable so the app still shows weather.
  static const String _fallbackCity = 'Brooklyn';

  WeatherBloc({
    required this.getWeather,
    required this.locationService,
    required this.sharedPreferences,
    required this.notificationService,
  }) : super(WeatherInitial()) {
    on<LoadInitialWeather>(_onLoadInitialWeather);
    on<GetWeatherEvent>(_onGetWeather);
  }

  Future<void> _onLoadInitialWeather(
    LoadInitialWeather event,
    Emitter<WeatherState> emit,
  ) async {
    emit(WeatherLoading());

    // 1. Check if there's a last selected city
    final lastCity = sharedPreferences.getString(_lastCityKey);
    if (lastCity != null) {
      await _fetchWeatherByCity(lastCity, event.units, event.locale, emit);
      return;
    }

    // 2. Otherwise try GPS
    try {
      final position = await locationService.getCurrentPosition();
      if (position != null) {
        final result = await getWeather(WeatherParams(
          lat: position.latitude,
          lon: position.longitude,
          units: event.units,
          locale: event.locale,
        ));
        result.fold(
          (failure) => emit(WeatherError(failure.message)),
          (weather) => _emitLoaded(weather, event.units, event.locale, emit),
        );
      } else {
        // Fallback to a default if GPS failed silently
        await _fetchWeatherByCity(_fallbackCity, event.units, event.locale, emit);
      }
    } catch (e) {
      // Location unavailable (permission denied, services off, no GPS fix) —
      // fall back to a default city instead of dead-ending on an error screen.
      await _fetchWeatherByCity(_fallbackCity, event.units, event.locale, emit);
    }
  }

  Future<void> _onGetWeather(GetWeatherEvent event, Emitter<WeatherState> emit) async {
    emit(WeatherLoading());
    // Save selection to priority
    await sharedPreferences.setString(_lastCityKey, event.cityName);
    await _fetchWeatherByCity(event.cityName, event.units, event.locale, emit);
  }

  Future<void> _fetchWeatherByCity(String cityName, String units, String locale, Emitter<WeatherState> emit) async {
    final result = await getWeather(WeatherParams(
      cityName: cityName,
      units: units,
      locale: locale,
    ));
    result.fold(
      (failure) => emit(WeatherError(failure.message)),
      (weather) => _emitLoaded(weather, units, locale, emit),
    );
  }

  /// Emits the loaded state and tells the notification service where this
  /// device is, so the alert backend knows which coordinates to monitor.
  void _emitLoaded(Weather weather, String units, String locale, Emitter<WeatherState> emit) {
    emit(WeatherLoaded(weather, units: units));
    notificationService.updateLocation(
      lat: weather.lat,
      lon: weather.lon,
      city: weather.cityName,
      units: units,
      language: locale,
    );
  }
}

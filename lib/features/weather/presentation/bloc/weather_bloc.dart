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
    on<SelectCityEvent>(_onSelectCity);
    on<RefreshAlertLocation>(_onRefreshAlertLocation);
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
      // The displayed city is a browsing choice; alerts must still track the
      // device, so refresh the alert position separately.
      await _refreshAlertLocationFromGps();
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
          // These coordinates came from GPS, so the resolved city name matches
          // the device's real position and is safe to store for alerts.
          (weather) => _emitLoaded(weather, event.units, event.locale, emit,
              fromGps: true),
        );
      } else {
        // Fallback to a default if GPS failed silently
        await _fetchWeatherByCity(_fallbackCity, event.units, event.locale, emit);
      }
    } catch (e) {
      // Location unavailable (permission denied, services off, no GPS fix) —
      // fall back to a default city instead of dead-ending on an error screen.
      // No alert-location refresh here: GPS has already failed.
      await _fetchWeatherByCity(_fallbackCity, event.units, event.locale, emit);
    }
  }

  Future<void> _onRefreshAlertLocation(
    RefreshAlertLocation event,
    Emitter<WeatherState> emit,
  ) async {
    // Intentionally emits nothing — this only moves where alerts are sent.
    await _refreshAlertLocationFromGps();
  }

  /// Points the alert backend at the device's current position.
  ///
  /// Passes `city: null` because no city name is known for these coordinates
  /// here; the dispatcher resolves one from OpenWeather. Storing a name from
  /// elsewhere is how alerts ended up following the searched city.
  Future<void> _refreshAlertLocationFromGps() async {
    try {
      final position = await locationService.getCurrentPosition();
      if (position == null) return;
      await notificationService.updateAlertLocation(
        lat: position.latitude,
        lon: position.longitude,
        city: null,
      );
    } catch (_) {
      // Location unavailable — keep the last known alert location rather than
      // clearing it, so the device still gets alerts for where it last was.
    }
  }

  Future<void> _onGetWeather(GetWeatherEvent event, Emitter<WeatherState> emit) async {
    emit(WeatherLoading());
    // Save selection to priority
    await sharedPreferences.setString(_lastCityKey, event.cityName);
    await _fetchWeatherByCity(event.cityName, event.units, event.locale, emit);
  }

  /// Search selection: fetch by the picked suggestion's exact coordinates.
  /// Still a browsing action, not a device position — `fromGps` stays false so
  /// the alert location is untouched.
  Future<void> _onSelectCity(SelectCityEvent event, Emitter<WeatherState> emit) async {
    emit(WeatherLoading());
    await sharedPreferences.setString(_lastCityKey, event.cityName);
    final result = await getWeather(WeatherParams(
      lat: event.lat,
      lon: event.lon,
      units: event.units,
      locale: event.locale,
    ));
    result.fold(
      (failure) => emit(WeatherError(failure.message)),
      (weather) => _emitLoaded(weather, event.units, event.locale, emit, fromGps: false),
    );
  }

  Future<void> _fetchWeatherByCity(String cityName, String units, String locale, Emitter<WeatherState> emit) async {
    final result = await getWeather(WeatherParams(
      cityName: cityName,
      units: units,
      locale: locale,
    ));
    result.fold(
      (failure) => emit(WeatherError(failure.message)),
      // A city lookup says nothing about where the device is, so this must not
      // move the alert location.
      (weather) => _emitLoaded(weather, units, locale, emit, fromGps: false),
    );
  }

  /// Emits the loaded state and syncs display preferences.
  ///
  /// [fromGps] must be true only when [weather] was fetched from the device's
  /// own coordinates — that is the sole case where the displayed location is
  /// also the correct target for severe-weather alerts.
  void _emitLoaded(
    Weather weather,
    String units,
    String locale,
    Emitter<WeatherState> emit, {
    required bool fromGps,
  }) {
    emit(WeatherLoaded(weather, units: units));
    notificationService.updateDisplayPreferences(units: units, language: locale);
    if (fromGps) {
      notificationService.updateAlertLocation(
        lat: weather.lat,
        lon: weather.lon,
        city: weather.cityName,
      );
    }
  }
}

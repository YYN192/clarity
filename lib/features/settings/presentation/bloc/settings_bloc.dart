import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/app_settings.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SharedPreferences sharedPreferences;
  final NotificationService notificationService;

  /// True until the settings loaded from disk have been applied once, so the
  /// startup re-registration below runs exactly once per launch.
  bool _isInitialLoad = true;

  SettingsBloc({
    required this.sharedPreferences,
    required this.notificationService,
  }) : super(const SettingsState(settings: AppSettings())) {
    on<UpdateSettings>(_onUpdateSettings);
    _loadSettings();
  }

  void _loadSettings() {
    final language = sharedPreferences.getString('setting_language') ?? 'English';
    final tempUnit = TemperatureUnit.values[sharedPreferences.getInt('setting_temp_unit') ?? 0];
    final windUnit = WindSpeedUnit.values[sharedPreferences.getInt('setting_wind_unit') ?? 0];
    final pressureUnit = PressureUnit.values[sharedPreferences.getInt('setting_pressure_unit') ?? 0];
    final alerts = sharedPreferences.getBool('setting_alerts') ?? false;

    add(UpdateSettings(AppSettings(
      language: language,
      temperatureUnit: tempUnit,
      windSpeedUnit: windUnit,
      pressureUnit: pressureUnit,
      severeWeatherAlerts: alerts,
      isDarkMode: false, // Locked to false
    )));
  }

  Future<void> _onUpdateSettings(UpdateSettings event, Emitter<SettingsState> emit) async {
    final wasAlertsEnabled = state.settings.severeWeatherAlerts;
    var s = event.settings;

    // Register/unregister FCM when the severe-weather-alerts toggle changes.
    if (s.severeWeatherAlerts != wasAlertsEnabled) {
      if (s.severeWeatherAlerts) {
        final granted = await notificationService.enable();
        // Permission denied — keep the toggle off so it reflects reality.
        if (!granted) s = s.copyWith(severeWeatherAlerts: false);
      } else {
        await notificationService.disable();
      }
    } else if (s.severeWeatherAlerts && _isInitialLoad) {
      // Startup with alerts already on: re-register so the token document
      // carries the current uid (the Firestore rules require ownership) and a
      // fresh timestamp for the dispatcher's staleness filter. Permission is
      // already granted here, so this shows no dialog.
      final granted = await notificationService.enable();
      if (!granted) s = s.copyWith(severeWeatherAlerts: false);
    }
    _isInitialLoad = false;

    await sharedPreferences.setString('setting_language', s.language);
    await sharedPreferences.setInt('setting_temp_unit', s.temperatureUnit.index);
    await sharedPreferences.setInt('setting_wind_unit', s.windSpeedUnit.index);
    await sharedPreferences.setInt('setting_pressure_unit', s.pressureUnit.index);
    await sharedPreferences.setBool('setting_alerts', s.severeWeatherAlerts);

    emit(SettingsState(settings: s.copyWith(isDarkMode: false)));
  }
}

class WeatherIconMapper {
  /// Every condition [mapCodeToCondition] can return.
  ///
  /// `ClayWeatherIcon.styleFor` must handle all of these; a missing case
  /// renders as a sun with no error. Keep the two in sync — the widget test
  /// asserts it.
  static const List<String> conditions = [
    'Clear Sky',
    'Clear Night',
    'Partly Cloudy',
    'Partly Cloudy Night',
    'Cloudy',
    'Rain',
    'Storm',
    'Snow',
    'Fog',
  ];

  static String mapCodeToCondition(String code) {
    // OpenWeather icon codes: https://openweathermap.org/weather-conditions
    switch (code) {
      case '01d':
        return 'Clear Sky';
      case '01n':
        return 'Clear Night';
      case '02d':
      case '03d':
        return 'Partly Cloudy';
      case '02n':
      case '03n':
        return 'Partly Cloudy Night';
      case '04d':
      case '04n':
        return 'Cloudy';
      case '09d':
      case '09n':
      case '10d':
      case '10n':
        return 'Rain';
      case '11d':
      case '11n':
        return 'Storm';
      case '13d':
      case '13n':
        return 'Snow';
      case '50d':
      case '50n':
        return 'Fog';
      default:
        return 'Clear Sky';
    }
  }
}

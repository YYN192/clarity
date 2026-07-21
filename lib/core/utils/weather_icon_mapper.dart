class WeatherIconMapper {
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

  static String getLottieAsset(String condition) {
    switch (condition) {
      case 'Clear Sky':
        return 'assets/lottie/sunny.json';
      case 'Clear Night':
        return 'assets/lottie/clear_night.json';
      case 'Partly Cloudy':
        return 'assets/lottie/partly_cloudy.json';
      case 'Partly Cloudy Night':
        return 'assets/lottie/partly_cloudy_night.json';
      case 'Cloudy':
        return 'assets/lottie/cloudy.json';
      case 'Rain':
        return 'assets/lottie/rainy.json';
      case 'Storm':
        return 'assets/lottie/storm.json';
      case 'Snow':
        return 'assets/lottie/snowy.json';
      case 'Fog':
        return 'assets/lottie/fog.json';
      default:
        return 'assets/lottie/sunny.json';
    }
  }
}

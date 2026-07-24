import '../../domain/entities/weather.dart';
import '../../../../core/utils/weather_icon_mapper.dart';

class WeatherModel extends Weather {
  const WeatherModel({
    required super.cityName,
    required super.lat,
    required super.lon,
    required super.temperature,
    required super.condition,
    required super.highTemp,
    required super.lowTemp,
    required super.windSpeed,
    required super.pressure,
    required super.humidity,
    required super.uvIndex,
    required super.visibility,
    required super.dewPoint,
    required super.hourlyForecast,
    required super.dailyForecast,
  });

  factory WeatherModel.fromApiResponse({
    required Map<String, dynamic> currentJson,
    required Map<String, dynamic> forecastJson,
    String locale = 'en',
  }) {
    final cityName = currentJson['name'] ?? '';
    // OpenWeather returns the resolved coordinates on the current-weather call.
    final coord = currentJson['coord'] ?? {};
    final lat = (coord['lat'] as num?)?.toDouble() ?? 0.0;
    final lon = (coord['lon'] as num?)?.toDouble() ?? 0.0;
    final main = currentJson['main'] ?? {};
    final temp = (main['temp'] as num).toDouble();
    final tempMax = (main['temp_max'] as num).toDouble();
    final tempMin = (main['temp_min'] as num).toDouble();
    final pressure = (main['pressure'] as num).toInt();
    final humidity = (main['humidity'] as num).toInt();
    
    final wind = currentJson['wind'] ?? {};
    final windSpeed = (wind['speed'] as num).toDouble();
    
    final visibility = ((currentJson['visibility'] as num? ?? 10000) / 1000).toDouble(); // convert m to km
    
    // OpenWeather basic API doesn't always provide UV Index and Dew Point in /weather or /forecast
    // One Call API does, but here we might need to mock or use placeholders if not present.
    final uvIndex = 3.0; // Placeholder as it's not in standard 2.5 API
    final dewPoint = 14.0; // Placeholder
    
    final weatherList = currentJson['weather'] as List? ?? [];
    final weatherItem = weatherList.isNotEmpty ? weatherList[0] : {};
    final iconCode = weatherItem['icon'] ?? '';
    final condition = WeatherIconMapper.mapCodeToCondition(iconCode);

    final forecastList = forecastJson['list'] as List? ?? [];
    
    // Process hourly (next 24 hours - 8 items of 3 hours).
    // Store the raw DateTime; the UI formats it with the current locale so the
    // hour label localizes even if the language changes without a refetch.
    final hourly = forecastList.take(8).map((item) {
      final dt = item['dt'] as int;
      final itemMain = item['main'] ?? {};
      final itemWeather = (item['weather'] as List? ?? []).firstOrNull ?? {};

      return HourlyForecast(
        dateTime: DateTime.fromMillisecondsSinceEpoch(dt * 1000),
        temperature: (itemMain['temp'] as num).toDouble(),
        condition: WeatherIconMapper.mapCodeToCondition(itemWeather['icon'] ?? ''),
      );
    }).toList();

    // Process daily (group by calendar day using a locale-independent key, so
    // grouping never depends on the display language).
    final Map<String, List<dynamic>> dailyGroups = {};
    final Map<String, DateTime> dayDates = {};
    for (var item in forecastList) {
      final dt = item['dt'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(dt * 1000);
      final key = '${date.year}-${date.month}-${date.day}';
      dailyGroups.putIfAbsent(key, () => []).add(item);
      dayDates.putIfAbsent(key, () => date);
    }

    final daily = dailyGroups.entries.take(7).map((entry) {
      final items = entry.value;
      double high = -double.infinity;
      double low = double.infinity;
      String icon = '';
      var bestDistance = 999;

      for (var item in items) {
        final m = item['main'] ?? {};
        final h = (m['temp_max'] as num).toDouble();
        final l = (m['temp_min'] as num).toDouble();
        if (h > high) high = h;
        if (l < low) low = l;

        // Represent the day by the slot nearest midday. (The old code
        // overwrote the icon on every slot, so each day rendered its ~21:00
        // entry — a night icon on every daily row.)
        final hour = DateTime.fromMillisecondsSinceEpoch((item['dt'] as int) * 1000).hour;
        final distance = (hour - 12).abs();
        final slotIcon = (item['weather'] as List? ?? []).firstOrNull?['icon'] as String?;
        if (slotIcon != null && distance < bestDistance) {
          bestDistance = distance;
          icon = slotIcon;
        }
      }

      // A trailing partial day may only have evening slots; a daily row should
      // still show the day variant of its condition, never a moon.
      if (icon.endsWith('n')) {
        icon = '${icon.substring(0, icon.length - 1)}d';
      }

      return DailyForecast(
        date: dayDates[entry.key]!,
        highTemp: high,
        lowTemp: low,
        condition: WeatherIconMapper.mapCodeToCondition(icon),
      );
    }).toList();

    // Pull today's high/low from the daily forecast if available,
    // otherwise fallback to current API values.
    final todayForecast = daily.firstOrNull;
    final displayHigh = todayForecast?.highTemp ?? tempMax;
    final displayLow = todayForecast?.lowTemp ?? tempMin;

    return WeatherModel(
      cityName: cityName,
      lat: lat,
      lon: lon,
      temperature: temp,
      condition: condition,
      highTemp: displayHigh,
      lowTemp: displayLow,
      windSpeed: windSpeed,
      pressure: pressure,
      humidity: humidity,
      uvIndex: uvIndex,
      visibility: visibility,
      dewPoint: dewPoint,
      hourlyForecast: hourly,
      dailyForecast: daily,
    );
  }
}

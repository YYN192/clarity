import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localizer.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../bloc/weather_bloc.dart';
import '../bloc/weather_state.dart';
import '../widgets/clay_container.dart';
import '../widgets/clay_weather_icon.dart';
import '../../domain/entities/weather.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/domain/entities/app_settings.dart';
import 'package:intl/intl.dart';

class ForecastPage extends StatelessWidget {
  final ScrollController? scrollController;
  const ForecastPage({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return BlocBuilder<WeatherBloc, WeatherState>(
          builder: (context, weatherState) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: _buildContent(context, weatherState, settingsState.settings),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, WeatherState weatherState, AppSettings settings) {
    if (weatherState is WeatherLoaded) {
      final weather = weatherState.weather;
      final localeCode = Localizer.getLocaleCode(settings.language);
      final tempUnit = settings.temperatureUnit == TemperatureUnit.celsius ? 'C' : 'F';
      final windUnit = _getWindUnitString(settings.windSpeedUnit);
      final pressureUnit = _getPressureUnitString(settings.pressureUnit);

      // Perform conversions
      final displayedWind = _convertWindSpeed(weather.windSpeed, weatherState.units, settings.windSpeedUnit);
      final displayedPressure = _convertPressure(weather.pressure.toDouble(), settings.pressureUnit);

      return SingleChildScrollView(
        key: const ValueKey('loaded'),
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 140),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(Localizer.localize('7_day_forecast', settings.language),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildMainCard(context, weather, tempUnit, localeCode),
                const SizedBox(height: 40),
                _buildMetricsGrid(context, weather, displayedWind, windUnit, displayedPressure, pressureUnit, settings),
                const SizedBox(height: 48),
                Text(Localizer.localize('upcoming', settings.language),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                _buildUpcomingList(context, weather, localeCode),
              ],
            ),
          ),
        ),
      );
    }
    return const Center(
      key: ValueKey('loading'),
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildMainCard(BuildContext context, Weather weather, String tempUnit, String localeCode) {
    return ClayContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(DateFormat('EEEE', localeCode).format(DateTime.now()),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${weather.condition}, ${weather.temperature.round()}°',
                style: const TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 24),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('${weather.temperature.round()}°',
                    style: const TextStyle(fontSize: 84, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Text(tempUnit, style: const TextStyle(fontSize: 32, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ClayWeatherIcon(condition: weather.condition, size: 140),
          const SizedBox(height: 32),
          _buildHourlyMiniList(context, weather, localeCode),
        ],
      ),
    );
  }

  /// Mini hourly row: fills the card width with flex when items fit, otherwise
  /// scrolls with a soft edge fade.
  Widget _buildHourlyMiniList(BuildContext context, Weather weather, String localeCode) {
    final items = weather.hourlyForecast;
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const minItemWidth = 56.0;
        final needed = minItemWidth * items.length + gap * (items.length - 1);
        final fits = constraints.maxWidth >= needed;

        if (fits) {
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: _miniHourItem(items[i], localeCode)),
              ],
            ],
          );
        }

        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white,
              Colors.white,
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              separatorBuilder: (context, index) => const SizedBox(width: gap * 2),
              itemBuilder: (context, index) =>
                  SizedBox(width: 72, child: _miniHourItem(items[index], localeCode)),
            ),
          ),
        );
      },
    );
  }

  Widget _miniHourItem(HourlyForecast hourly, String localeCode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(DateFormat('h a', localeCode).format(hourly.dateTime),
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 8),
        ClayWeatherIcon(condition: hourly.condition, size: 36),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('${hourly.temperature.round()}°',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context, Weather weather, String displayedWind, String windUnit, String displayedPressure, String pressureUnit, AppSettings settings) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = gridColumnsFor(width); // 2 phone / 3 tablet / 4 desktop
    final aspect = switch (screenTypeOf(width)) {
      ScreenType.phone => 1.1,
      ScreenType.tablet => 1.3,
      ScreenType.desktop => 1.4,
    };

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: aspect,
      children: [
        _buildMetricCard(context, Localizer.localize('wind_speed', settings.language), displayedWind, windUnit, Icons.air),
        _buildMetricCard(context, Localizer.localize('pressure', settings.language), displayedPressure, pressureUnit, Icons.speed),
        _buildMetricCard(context, Localizer.localize('humidity', settings.language), '${weather.humidity}', '%', Icons.water_drop),
        _buildMetricCard(context, Localizer.localize('uv_index', settings.language), '${weather.uvIndex.round()}', 'Moderate', Icons.wb_sunny),
        _buildMetricCard(context, Localizer.localize('visibility', settings.language), '${weather.visibility.round()}', 'km', Icons.visibility),
        _buildMetricCard(context, Localizer.localize('dew_point', settings.language), '${weather.dewPoint.round()}°', '', Icons.thermostat),
      ],
    );
  }

  Widget _buildUpcomingList(BuildContext context, Weather weather, String localeCode) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: weather.dailyForecast.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final daily = weather.dailyForecast[index];
        return _buildDailyForecastCard(context, daily, localeCode);
      },
    );
  }

  Widget _buildDailyForecastCard(BuildContext context, DailyForecast daily, String localeCode) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(24),
      child: ClayContainer(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(DateFormat('EEE', localeCode).format(daily.date),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
            ),
            const Spacer(),
            ClayWeatherIcon(condition: daily.condition, size: 40),
            const Spacer(),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text('${daily.highTemp.round()}°',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text('${daily.lowTemp.round()}°',
                        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWindUnitString(WindSpeedUnit unit) {
    switch (unit) {
      case WindSpeedUnit.kmh: return 'km/h';
      case WindSpeedUnit.mph: return 'mph';
      case WindSpeedUnit.ms: return 'm/s';
    }
  }

  String _getPressureUnitString(PressureUnit unit) {
    switch (unit) {
      case PressureUnit.hPa: return 'hPa';
      case PressureUnit.inHg: return 'inHg';
      case PressureUnit.mmHg: return 'mmHg';
    }
  }

  String _convertWindSpeed(double value, String apiUnits, WindSpeedUnit targetUnit) {
    double speedInMs;
    if (apiUnits == 'imperial') {
      speedInMs = value / 2.23694;
    } else {
      speedInMs = value;
    }

    switch (targetUnit) {
      case WindSpeedUnit.ms:
        return speedInMs.toStringAsFixed(1);
      case WindSpeedUnit.kmh:
        return (speedInMs * 3.6).toStringAsFixed(1);
      case WindSpeedUnit.mph:
        return (speedInMs * 2.23694).toStringAsFixed(1);
    }
  }

  String _convertPressure(double value, PressureUnit targetUnit) {
    switch (targetUnit) {
      case PressureUnit.hPa:
        return value.round().toString();
      case PressureUnit.inHg:
        return (value * 0.02953).toStringAsFixed(2);
      case PressureUnit.mmHg:
        return (value * 0.75006).toStringAsFixed(1);
    }
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, String unit, IconData icon) {
    return ClayContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClayContainer(
                borderRadius: 12,
                padding: const EdgeInsets.all(8),
                color: AppColors.surface,
                child: Icon(icon, size: 22, color: AppColors.atmosphericBlueGray),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
